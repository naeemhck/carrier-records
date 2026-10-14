"""Distinguish SDK PEM parser headers from actual armored private material."""
import re

PRIVATE_KEY_HEADER=re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----')
PRIVATE_KEY_MATERIAL=re.compile(
    rb'-----BEGIN ((?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY)-----\s+'
    rb'(?:Proc-Type:[^\r\n]+\r?\nDEK-Info:[^\r\n]+\r?\n\s*)?'
    rb'[A-Za-z0-9+/=\r\n \t]{64,}-----END \1-----'
)

def has_private_key_material(data):
    return PRIVATE_KEY_MATERIAL.search(data) is not None
