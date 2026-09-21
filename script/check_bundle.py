"""Validate the built bundle's update contract, including Sparkle prerequisites."""
import plistlib
import sys
from pathlib import Path
root = Path(sys.argv[1])
with (root / 'Contents/Info.plist').open('rb') as file:
    info = plistlib.load(file)
assert info['CFBundleIdentifier'] == 'studio.glim.mac'
assert info['CFBundleDevelopmentRegion'] == 'en'
assert info['SURequireSignedFeed'] is True
assert info['SUVerifyUpdateBeforeExtraction'] is True, 'Signed feeds require verification before extraction'
assert info['SUFeedURL'].startswith('https://github.com/sthamann/glim-studio/')
assert len(info['SUPublicEDKey']) == 44
assert (root / 'Contents/Frameworks/Sparkle.framework').exists()
assert (root / 'Contents/Resources/backend/setup.py').exists()
print('PASS: bundle identity, English default, signed-feed prerequisites, packaged engine and updater')
