"""Encrypted, verified archives and content-addressed incremental receipt objects.

There is no restore operation here. Opening a ZIP and pg_restore --list are integrity
checks; usable recovery must be rehearsed separately in T17.
"""
import base64,hashlib,io,json,os,secrets,tempfile,uuid,zipfile
from datetime import datetime,timezone,timedelta
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

MAGIC=b'CRB1';UTC=timezone.utc
class BackupError(Exception):
    def __init__(self,code):self.code=code;super().__init__(code)
def digest(data):return hashlib.sha256(data).hexdigest()
def utcnow():return datetime.now(UTC)
def atomic_json(path,value):
    path=Path(path);tmp=path.with_suffix(path.suffix+'.partial')
    with tmp.open('w',encoding='utf-8') as f:json.dump(value,f);f.flush();os.fsync(f.fileno())
    os.replace(tmp,path)
def due(last_success,now,daily_time):
    hour,minute=map(int,daily_time.split(':'));boundary=now.replace(hour=hour,minute=minute,second=0,microsecond=0)
    if now<boundary:boundary-=timedelta(days=1)
    return last_success is None or datetime.fromisoformat(last_success)<boundary
def key_id(key):
    if len(key)!=32:raise BackupError('CREDENTIAL_UNAVAILABLE')
    return digest(key)[:24]
def aad(key,kind):return ('CarrierRecordsBackup/v1/'+key_id(key)+'/'+kind).encode()
def export_recovery(key,path,passphrase):
    if len(passphrase)<12:raise BackupError('CONFIGURATION_INVALID')
    salt=secrets.token_bytes(16);nonce=secrets.token_bytes(12)
    wrapping=Scrypt(salt=salt,length=32,n=32768,r=8,p=1).derive(passphrase.encode())
    value={'format_version':1,'key_id':key_id(key),'method':'SCRYPT_AES256_GCM','salt':base64.b64encode(salt).decode(),'nonce':base64.b64encode(nonce).decode(),'wrapped_key':base64.b64encode(AESGCM(wrapping).encrypt(nonce,key,b'CarrierRecordsRecovery/v1')).decode()}
    with Path(path).open('x',encoding='utf-8') as f:json.dump(value,f);f.flush();os.fsync(f.fileno())
def recover_key(path,passphrase):
    try:
        if Path(path).stat().st_size>4096:raise ValueError()
        r=json.loads(Path(path).read_text(encoding='utf-8'))
        if r['format_version']!=1 or r['method']!='SCRYPT_AES256_GCM':raise ValueError()
        salt=base64.b64decode(r['salt'],validate=True);nonce=base64.b64decode(r['nonce'],validate=True)
        if len(salt)!=16 or len(nonce)!=12:raise ValueError()
        wrapping=Scrypt(salt=salt,length=32,n=32768,r=8,p=1).derive(passphrase.encode())
        key=AESGCM(wrapping).decrypt(nonce,base64.b64decode(r['wrapped_key'],validate=True),b'CarrierRecordsRecovery/v1')
        if key_id(key)!=r['key_id']:raise ValueError()
        return key
    except Exception:raise BackupError('CREDENTIAL_UNAVAILABLE') from None
def seal(source,target,key,kind):
    nonce=secrets.token_bytes(12);enc=Cipher(algorithms.AES(key),modes.GCM(nonce)).encryptor();enc.authenticate_additional_data(aad(key,kind))
    with Path(target).open('xb') as f:
        f.write(MAGIC+nonce+b'\0'*16)
        while b:=source.read(1048576):f.write(enc.update(b))
        f.write(enc.finalize());f.seek(16);f.write(enc.tag);f.flush();os.fsync(f.fileno())
def unseal(path,key,kind,maximum=2147483648):
    out=tempfile.TemporaryFile()
    try:
        if Path(path).stat().st_size>maximum:raise BackupError('ARCHIVE_VERIFY_FAILED')
        with Path(path).open('rb') as f:
            h=f.read(32)
            if len(h)!=32 or h[:4]!=MAGIC:raise BackupError('ARCHIVE_VERIFY_FAILED')
            dec=Cipher(algorithms.AES(key),modes.GCM(h[4:16],h[16:32])).decryptor();dec.authenticate_additional_data(aad(key,kind))
            while b:=f.read(1048576):out.write(dec.update(b))
            out.write(dec.finalize())
        out.seek(0);return out
    except Exception:
        out.close();raise BackupError('ARCHIVE_VERIFY_FAILED') from None
def read_manifest(path,key):
    with unseal(path,key,'archive') as plain,zipfile.ZipFile(plain) as z:
        if set(z.namelist())!={'manifest.json','database.dump','roles.json'}:raise BackupError('ARCHIVE_VERIFY_FAILED')
        m=json.loads(z.read('manifest.json'))
        if m.get('format_version')!=1 or m.get('key_id')!=key_id(key):raise BackupError('ARCHIVE_VERIFY_FAILED')
        if digest(z.read('database.dump'))!=m['database_sha256'] or digest(z.read('roles.json'))!=m['roles_sha256']:raise BackupError('ARCHIVE_VERIFY_FAILED')
        return m
def verify_archive(path,key,root,transport):
    manifest=read_manifest(path,key)
    with unseal(path,key,'archive') as plain,zipfile.ZipFile(plain) as z:transport.verify_dump(z.read('database.dump'))
    for r in manifest['receipts']:
        if r['sha256']!=r['blob'] or len(r['sha256'])!=64 or any(c not in '0123456789abcdef' for c in r['sha256']):raise BackupError('ARCHIVE_VERIFY_FAILED')
        with unseal(Path(root)/'objects'/(r['blob']+'.crb'),key,'receipt/'+r['sha256'],6000000) as f:data=f.read()
        if len(data)!=r['byte_size'] or digest(data)!=r['sha256']:raise BackupError('ARCHIVE_VERIFY_FAILED')
    return manifest
def retention(root,key,keep_days):
    if not 1<=keep_days<=365:raise BackupError('CONFIGURATION_INVALID')
    root=Path(root).resolve();files=sorted((root/'archives').glob('*.crb'),reverse=True);keep=[];days=set()
    # Verify all before deleting anything. Never prune a source record or receipt in Storage.
    manifests={f:read_manifest(f,key) for f in files}
    for f in files:
        day=manifests[f]['local_day']
        if day not in days and len(days)<keep_days:keep.append(f);days.add(day)
    references={r['blob'] for f in keep for r in manifests[f]['receipts']}
    for f in files:
        if f not in keep:
            if f.resolve().parent!=root/'archives':raise BackupError('RETENTION_FAILED')
            f.unlink()
    for f in (root/'objects').glob('*.crb'):
        if f.stem not in references:
            if f.resolve().parent!=root/'objects':raise BackupError('RETENTION_FAILED')
            f.unlink()
def run_backup(config,key,transport,scheduled=False,clock=utcnow):
    root=Path(config['backup_root']).resolve();root.mkdir(parents=True,exist_ok=True)
    for d in ['archives','objects']:
        (root/d).mkdir(exist_ok=True)
        if (root/d).resolve()!=root/d:raise BackupError('CONFIGURATION_INVALID')
    status_path=Path(config['status_path']);status_path.parent.mkdir(parents=True,exist_ok=True)
    old=json.loads(status_path.read_text(encoding='utf-8')) if status_path.exists() else {}
    now=clock();local=now.astimezone()
    if scheduled and not due(old.get('last_verified_success_at'),local,config['daily_time']):return {'outcome':'NOT_DUE'}
    run_id=str(uuid.uuid4());last=old.get('last_verified_success_at');metrics={'dump_bytes':0,'receipt_bytes':0,'http_bytes':0,'downloaded_receipts':0,'reused_receipts':0,'egress_budget_bytes':config.get('egress_budget_bytes',5000000000),'other_egress_bytes':config.get('other_egress_bytes')};pending=0;archive=None
    local_status={'business_id':config['business_id'],'outcome':'RUNNING','run_id':run_id,'last_attempt_at':now.isoformat(),'last_verified_success_at':last,'safe_error_code':None}
    atomic_json(status_path,local_status)
    try:
        transport.authorize()
        transport.report(run_id,'RUNNING',metrics,0,None,None)
        with tempfile.TemporaryFile() as dump:
            transport.dump(dump);dump.seek(0);h=hashlib.sha256()
            while b:=dump.read(1048576):h.update(b);metrics['dump_bytes']+=len(b)
            dump.seek(0);db_hash=h.hexdigest();roles=transport.metadata();roles_bytes=json.dumps(roles,sort_keys=True).encode()
            receipt_list=transport.receipts();pending=len(receipt_list);manifest_receipts=[]
            metrics.update(transport.usage())
            for r in receipt_list:
                sha=r['sha256'];size=r['byte_size']
                if len(sha)!=64 or any(c not in '0123456789abcdef' for c in sha) or not 1<=size<=5242880:raise BackupError('RECEIPT_COPY_FAILED')
                blob=root/'objects'/(sha+'.crb')
                if blob.exists():
                    with unseal(blob,key,'receipt/'+sha,6000000) as f:data=f.read()
                    if digest(data)!=sha or len(data)!=size:raise BackupError('ARCHIVE_VERIFY_FAILED')
                    metrics['reused_receipts']+=1
                else:
                    data=transport.download(r['object_path']);metrics['receipt_bytes']+=len(data)
                    if digest(data)!=sha or len(data)!=size:raise BackupError('RECEIPT_COPY_FAILED')
                    partial=blob.with_suffix('.partial')
                    if partial.exists():partial.unlink()
                    seal(io.BytesIO(data),partial,key,'receipt/'+sha)
                    with unseal(partial,key,'receipt/'+sha,6000000) as f:
                        if digest(f.read())!=sha:raise BackupError('ARCHIVE_VERIFY_FAILED')
                    os.replace(partial,blob);metrics['downloaded_receipts']+=1
                manifest_receipts.append(dict(r,blob=sha));pending-=1
            manifest={'format_version':1,'run_id':run_id,'business_id':config['business_id'],'created_at':now.isoformat(),'local_day':local.date().isoformat(),'key_id':key_id(key),'database_sha256':db_hash,'roles_sha256':digest(roles_bytes),'excluded_active_identity_tables':transport.excluded_sessions,'receipts':manifest_receipts,'restoration_verified':False}
            with tempfile.TemporaryFile() as plain:
                with zipfile.ZipFile(plain,'w',zipfile.ZIP_DEFLATED) as z:
                    z.writestr('manifest.json',json.dumps(manifest,sort_keys=True));z.writestr('roles.json',roles_bytes)
                    with z.open('database.dump','w',force_zip64=True) as dest:
                        while b:=dump.read(1048576):dest.write(b)
                plain.seek(0);archive=root/'archives'/(now.strftime('%Y%m%dT%H%M%S%fZ')+'-'+run_id+'.crb');partial=archive.with_suffix('.partial')
                seal(plain,partial,key,'archive');verify_archive(partial,key,root,transport);os.replace(partial,archive)
        metrics['http_bytes']=transport.http_bytes
        with archive.open('rb') as f:archive_hash=hashlib.file_digest(f,'sha256').hexdigest()
        transport.report(run_id,'SUCCESS',metrics,0,None,archive_hash)
        local_status.update(outcome='SUCCESS',last_verified_success_at=clock().isoformat(),safe_error_code=None,archive_digest=archive_hash)
        # Prune only after a verified, reported success. Failed runs retain prior backups.
        try:retention(root,key,config.get('retention_days',30))
        except (BackupError,OSError):local_status['retention_warning']='RETENTION_FAILED'
        atomic_json(status_path,local_status)
        return dict(local_status,metrics=metrics)
    except BaseException as e:
        metrics['http_bytes']=getattr(transport,'http_bytes',0)
        code=e.code if isinstance(e,BackupError) else 'INTERRUPTED' if isinstance(e,(KeyboardInterrupt,SystemExit)) else 'LOCAL_IO_FAILED'
        local_status.update(outcome='FAILED',safe_error_code=code,pending_receipt_count=pending)
        try:atomic_json(status_path,local_status)
        except OSError:pass
        try:transport.report(run_id,'FAILED',metrics,pending,code,None)
        except Exception:pass
        if isinstance(e,(KeyboardInterrupt,SystemExit)):raise
        return dict(local_status,metrics=metrics)
    finally:transport.close()
