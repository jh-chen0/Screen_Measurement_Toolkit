#!/usr/bin/env python3
"""Export a clean, editable project without checkout state or signing material."""
from pathlib import Path
import argparse
import fnmatch
import plistlib
import re
import zipfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--version')
args = parser.parse_args()
with (root / 'Resources/Info.plist').open('rb') as file:
    version = args.version or plistlib.load(file)['CFBundleShortVersionString']
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    parser.error('version must be numeric major.minor.patch')

entries = ['.github', '.gitignore', 'Checks', 'CONTRIBUTING.md', 'docs', 'LICENSE', 'NOTICE',
           'Package.swift', 'README.md', 'README.zh-CN.md', 'Resources', 'SCREEN_ANGLE.zh-CN.md',
           'Sources', 'Tools', 'build.sh', 'package.sh', 'run.sh']
excluded = ['.DS_Store', '__pycache__', '*.pyc', '*.p12', '*.p8', '*.key', '*.provisionprofile', '.env', '.env.*']
files = []
for entry in entries:
    path = root / entry
    candidates = path.rglob('*') if path.is_dir() else [path]
    for candidate in candidates:
        if not candidate.is_file() or candidate.is_symlink():
            continue
        relative = candidate.relative_to(root)
        if any(fnmatch.fnmatch(part, pattern) for part in relative.parts for pattern in excluded):
            continue
        files.append(candidate)

destination = root / 'build/dist' / f'Screen-Measurement-Toolkit-{version}-Source.zip'
destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(files):
        archive.write(file, 'ScreenMeasurementToolkit/' + file.relative_to(root).as_posix())
print(f'Exported {len(files)} source files: {destination.relative_to(root)}')
