from pathlib import Path
import plistlib
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
control = dict(line.split(': ', 1) for line in (root/'control').read_text().splitlines() if ': ' in line)
info = plistlib.loads((root/'preferences/Resources/Info.plist').read_bytes())
assert control['Version'] == info['CFBundleVersion'] == info['CFBundleShortVersionString'] == '1.0.0'
assert control['Package'] == 'com.rshad.notifyglow'
assert control['Architecture'] == 'iphoneos-arm64'
for file in (root/'preferences/Resources').glob('*.plist'):
    plistlib.loads(file.read_bytes())
plistlib.loads((root/'layout/Library/PreferenceLoader/Preferences/NotifyGlow.plist').read_bytes())
if '--package' in sys.argv:
    packages = list((root/'packages').glob('*.deb'))
    assert len(packages) == 1, packages
    for key in ('Package', 'Version', 'Architecture', 'Needs'):
        actual = subprocess.check_output(['dpkg-deb','-f',str(packages[0]),key],text=True).strip()
        assert actual == control[key], (key, actual)
    listing = subprocess.check_output(['dpkg-deb','-c',str(packages[0])],text=True)
    assert './var/jb/Library/MobileSubstrate/DynamicLibraries/NotifyGlow.dylib' in listing
    assert './var/jb/Library/PreferenceBundles/NotifyGlowPrefs.bundle/NotifyGlowPrefs' in listing
    assert './var/jb/Library/PreferenceLoader/Preferences/NotifyGlow.plist' in listing
print('Metadata and package checks passed' if '--package' in sys.argv else 'Metadata checks passed')
