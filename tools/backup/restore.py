"""Recovery primitives for a newly created, isolated loopback rehearsal only.

No production destination is accepted. Credentials and decrypted data stay in
memory/auto-deleted temporary files; ordinary staff clients never load this.
"""
import io,json,re,socket,subprocess,zipfile
from pathlib import Path
from core import BackupError,digest,recover_key,unseal,verify_archive

def isolated_port_block(candidates=(57320,58320,59320)):
    """Probe every isolated port; Windows excluded ranges need not have listeners."""
    for base in candidates:
        if base not in (57320,58320,59320):raise BackupError('CONFIGURATION_INVALID')
        sockets=[]
        try:
            for port in range(base,base+10):
                probe=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
                sockets.append(probe)
                probe.bind(('0.0.0.0',port))
            return base
        except OSError:
            continue
        finally:
            for probe in sockets:probe.close()
    raise BackupError('RESTORE_PORTS_UNAVAILABLE')

class ArchiveInspector:
    """Read-only compatible utilities, without the lost PC's credential vault."""
    def __init__(self,image='supabase/postgres:17.11.0.004'):
        if not re.fullmatch(r'(?:supabase/postgres|public.ecr.aws/supabase/postgres|ghcr.io/supabase/postgres):[0-9A-Za-z_.-]+',image):raise BackupError('CONFIGURATION_INVALID')
        self.image=image
    def verify_dump(self,data):
        r=subprocess.run(['docker','run','--rm','-i','--network','none','--entrypoint','pg_restore',self.image,'--list'],input=data,capture_output=True)
        if r.returncode or b'TABLE DATA auth users' not in r.stdout or b'TABLE DATA auth identities' not in r.stdout:raise BackupError('ARCHIVE_VERIFY_FAILED')

def target_guard(container):
    if not re.fullmatch(r'supabase_db_carrier_restore_[0-9a-f]{12}',container):
        raise BackupError('CONFIGURATION_INVALID')

def query(container,sql):
    target_guard(container)
    r=subprocess.run(['docker','exec','-i','-e','PGOPTIONS=-csearch_path=',container,'psql','-U','supabase_admin','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=sql.encode(),capture_output=True)
    if r.returncode:
        # Only classify known provider/schema errors, never emit utility output,
        # SQL statements, COPY rows or credentials.
        text=r.stderr.decode(errors='replace')
        reason='UNKNOWN'
        for pattern,label in [('cannot drop','DEPENDENCY_DROP'),('must be owner','OWNERSHIP'),('permission denied','PERMISSION'),('does not exist','MISSING_OBJECT'),('already exists','EXISTING_OBJECT')]:
            if pattern in text:reason=label;break
        raise BackupError('RESTORE_DATABASE_FAILED_'+reason)
    return r.stdout.decode().strip()

def recover_archive(archive,root,recovery,passphrase,transport):
    key=recover_key(recovery,passphrase)
    manifest=verify_archive(archive,key,root,transport)
    # Return only after every object and database archive hash has been verified.
    with unseal(archive,key,'archive') as plain,zipfile.ZipFile(plain) as z:
        return key,manifest,z.read('database.dump'),json.loads(z.read('roles.json'))

def restore_database(container,database,metadata):
    target_guard(container)
    # A new provider baseline has Auth tables but no identities/app schema.
    clean=query(container,"select (not exists(select 1 from pg_tables where schemaname in('public','private')) and not exists(select 1 from auth.users) and not exists(select 1 from storage.objects))::text")
    if clean!='true':raise BackupError('RESTORE_TARGET_NOT_EMPTY')
    statements=[]
    for role in metadata['roles']:
        name=role['name']
        if not name.startswith('carrier_'):continue
        if not re.fullmatch(r'carrier_[a-z_]+',name) or role['login'] or role['bypass_rls']:
            raise BackupError('RESTORE_ROLE_INVALID')
        statements.append('create role '+name+' nologin nosuperuser nobypassrls '+('inherit' if role['inherit'] else 'noinherit')+';')
    query(container,'begin;'+''.join(statements)+'commit;')
    # A full logical dump must enter a pristine database, rather than --clean
    # a provider baseline with inherited realtime partition constraints.
    # Only this named, verified empty, disposable target is ever accepted.
    for statement in ['drop database postgres with(force);','create database postgres owner postgres template template0;']:
        r=subprocess.run(['docker','exec','-i','-e','PGOPTIONS=-csearch_path=',container,'psql','-U','supabase_admin','-d','template1','-v','ON_ERROR_STOP=1'],input=statement.encode(),capture_output=True)
        if r.returncode:raise BackupError('RESTORE_DATABASE_FAILED')
    # Custom-format restores may seek data blocks after dependency ordering.
    # A stdin pipe is non-seekable. Keep decrypted data only in a mode-600 file
    # inside this isolated target and remove it even after a failed restore.
    temporary='/tmp/carrier-restore.dump'
    r=subprocess.run(['docker','exec','-i',container,'sh','-c','umask 077; cat > '+temporary],input=database,capture_output=True)
    if r.returncode:raise BackupError('RESTORE_DATABASE_FAILED')
    try:
        copied=subprocess.run(['docker','exec',container,'sha256sum',temporary],capture_output=True,check=True)
        if copied.stdout.split()[0].decode()!=digest(database):raise BackupError('ARCHIVE_VERIFY_FAILED')
        r=subprocess.run(['docker','exec',container,'pg_restore','-U','supabase_admin','-d','postgres','--verbose','--single-transaction','--exit-on-error',temporary],capture_output=True)
    finally:
        subprocess.run(['docker','exec',container,'rm','-f','--',temporary],capture_output=True,check=True)
    if r.returncode:
        raw=r.stderr.decode(errors='replace')
        match=re.search(r'(?:ERROR|FATAL):\s+([^\r\n]+)',raw)
        text=match.group(1) if match else next((line for line in raw.splitlines() if 'pg_restore: error:' in line),'UNKNOWN')
        reason='UNKNOWN'
        for pattern,label in [('cannot drop inherited constraint','PARTITION_CONSTRAINT'),('schema "public" does not exist','PUBLIC_SCHEMA_MISSING'),('permission denied','PERMISSION'),('non-seekable','NON_SEEKABLE_INPUT'),('end of file','UNEXPECTED_EOF'),('connection','CONNECTION'),('out of memory','MEMORY')]:
            if pattern in text:reason=label;break
        error=BackupError('RESTORE_DATABASE_FAILED_'+reason)
        # One error header only, without SQL/COPY rows or quoted literals.
        # Long token/hash-shaped strings and URLs are removed as well.
        diagnostic=re.sub(r'\"[^\"]*\"|\x27[^\x27]*\x27','<quoted>',text)
        diagnostic=re.sub(r'https?://\S+|[A-Za-z0-9_+/=$.-]{24,}','<value>',diagnostic)
        error.diagnostic=diagnostic[:240]
        stages=re.findall(r'^pg_restore: (?:creating|processing data for|restoring) ([A-Z ]+) ',raw,re.M)
        error.restore_stage=stages[-1] if stages else 'UNKNOWN'
        raise error
    for membership in metadata['memberships']:
        role,member=membership['role'],membership['member']
        if not(role.startswith('carrier_') or member.startswith('carrier_')):continue
        if not re.fullmatch(r'[a-z_]+',role) or not re.fullmatch(r'[a-z_]+',member):raise BackupError('RESTORE_ROLE_INVALID')
        query(container,'grant '+role+' to '+member+' with admin '+str(membership['admin_option']).lower()+', inherit '+str(membership['inherit_option']).lower()+', set '+str(membership['set_option']).lower()+';')
    # Session data is excluded at backup; revoke anything created by target services.
    query(container,'begin;delete from auth.refresh_tokens;delete from auth.sessions;commit;')

def restore_receipts(root,key,manifest,upload):
    copied=0
    for item in manifest['receipts']:
        sha=item['sha256']
        if not re.fullmatch(r'[0-9a-f]{64}',sha):raise BackupError('ARCHIVE_VERIFY_FAILED')
        with unseal(Path(root)/'objects'/(sha+'.crb'),key,'receipt/'+sha,6000000) as plain:
            upload(item,plain.read())
        copied+=1
    return copied
