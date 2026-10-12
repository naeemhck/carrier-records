"""Windows per-user Credential Manager. Never serialize privileged values to config/logs."""
import ctypes,os
from ctypes import wintypes

class WindowsVault:
    def __init__(self):
        if os.name!='nt':raise RuntimeError('WINDOWS_REQUIRED')
        class FileTime(ctypes.Structure):_fields_=[('low',wintypes.DWORD),('high',wintypes.DWORD)]
        class Credential(ctypes.Structure):
            _fields_=[('Flags',wintypes.DWORD),('Type',wintypes.DWORD),('TargetName',wintypes.LPWSTR),('Comment',wintypes.LPWSTR),('LastWritten',FileTime),('CredentialBlobSize',wintypes.DWORD),('CredentialBlob',ctypes.POINTER(ctypes.c_ubyte)),('Persist',wintypes.DWORD),('AttributeCount',wintypes.DWORD),('Attributes',ctypes.c_void_p),('TargetAlias',wintypes.LPWSTR),('UserName',wintypes.LPWSTR)]
        self.Credential=Credential;self.api=ctypes.WinDLL('advapi32',use_last_error=True)
        self.api.CredWriteW.argtypes=[ctypes.POINTER(Credential),wintypes.DWORD];self.api.CredWriteW.restype=wintypes.BOOL
        self.api.CredReadW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,ctypes.POINTER(ctypes.POINTER(Credential))];self.api.CredReadW.restype=wintypes.BOOL
        self.api.CredDeleteW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD];self.api.CredDeleteW.restype=wintypes.BOOL
        self.api.CredFree.argtypes=[ctypes.c_void_p]
    def write(self,target,value):
        if not 0<len(value)<=2560:raise RuntimeError('CREDENTIAL_SIZE_INVALID')
        blob=(ctypes.c_ubyte*len(value)).from_buffer_copy(value)
        c=self.Credential(Type=1,TargetName=target,CredentialBlobSize=len(value),CredentialBlob=blob,Persist=2,UserName='CarrierRecordsBackup')
        try:
            if not self.api.CredWriteW(ctypes.byref(c),0):raise RuntimeError('CREDENTIAL_STORE_FAILED')
        finally:ctypes.memset(blob,0,len(value))
    def read(self,target):
        p=ctypes.POINTER(self.Credential)()
        if not self.api.CredReadW(target,1,0,ctypes.byref(p)):raise RuntimeError('CREDENTIAL_UNAVAILABLE')
        try:return ctypes.string_at(p.contents.CredentialBlob,p.contents.CredentialBlobSize)
        finally:self.api.CredFree(p)
    def delete(self,target):
        if not self.api.CredDeleteW(target,1,0) and ctypes.get_last_error()!=1168:raise RuntimeError('CREDENTIAL_DELETE_FAILED')
