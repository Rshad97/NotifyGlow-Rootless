"""Generate standalone APT metadata from the actual DEB (no network writes)."""
from pathlib import Path
import bz2
import gzip
import hashlib
import json
import io
import subprocess
import sys
import tarfile

deb = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
raw = deb.read_bytes()
control_tar = subprocess.check_output(['dpkg-deb', '--ctrl-tarfile', str(deb)])
with tarfile.open(fileobj=io.BytesIO(control_tar), mode='r:') as archive:
    fields = archive.extractfile('./control').read().decode().strip()
assert 'Package: com.rshad.notifyglow\n' in fields
assert 'Version: 1.0.2\n' in fields
assert 'Architecture: iphoneos-arm64\n' in fields
assert 'Needs: respring' in fields
packages = fields + '\nFilename: ./debs/' + deb.name + '\nSize: ' + str(len(raw)) + '\n'
for field, algorithm in [('MD5sum', 'md5'), ('SHA1', 'sha1'), ('SHA256', 'sha256'), ('SHA512', 'sha512')]:
    packages += field + ': ' + hashlib.new(algorithm, raw).hexdigest() + '\n'
packages += '\n'
data = {'Packages': packages.encode()}
data['Packages.gz'] = gzip.compress(data['Packages'], compresslevel=9, mtime=0)
data['Packages.bz2'] = bz2.compress(data['Packages'], compresslevel=9)
release = 'Origin: Rashad Repo\nLabel: Rashad Repo\nSuite: stable\nVersion: 1.0\nCodename: ios\nArchitectures: iphoneos-arm64\nComponents: main\nDescription: Rashad NotifyGlow packages\n'
for label, algorithm in [('MD5Sum', 'md5'), ('SHA256', 'sha256')]:
    release += label + ':\n'
    for name, value in data.items():
        release += ' ' + hashlib.new(algorithm, value).hexdigest() + f' {len(value):16d} ' + name + '\n'
data['Release'] = release.encode()
for name, value in data.items():
    (out/name).write_bytes(value)
assert gzip.decompress(data['Packages.gz']) == bz2.decompress(data['Packages.bz2']) == data['Packages']
print(json.dumps({'version': '1.0.2', 'size': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'metadata': str(out)}))
