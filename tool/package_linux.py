#!/usr/bin/env python3
"""Package the complete Linux release bundle with its notices and instructions."""
import hashlib
from pathlib import Path
import shutil
import tarfile
import tempfile

root = Path(__file__).resolve().parents[1]
version = next(line.split(':', 1)[1].strip().split('+')[0]
               for line in (root / 'pubspec.yaml').read_text().splitlines()
               if line.startswith('version:'))
bundle = root / 'build/linux/x64/release/bundle'
if not (bundle / 'bibledoor').is_file():
    raise SystemExit('Run flutter build linux --release first.')
output = root / 'build/releases'
output.mkdir(parents=True, exist_ok=True)
archive = output / f'Bible-Door-{version}-linux-x64.tar.gz'
with tempfile.TemporaryDirectory(prefix='bible-door-package-') as temporary:
    stage = Path(temporary) / 'BibleDoor'
    shutil.copytree(bundle, stage)
    for name in ('LICENSE', 'NOTICE'):
        shutil.copy2(root / name, stage / name)
    shutil.copy2(root / 'docs/INSTALL_LINUX.txt', stage / 'READ-ME.txt')
    shutil.copy2(root / 'assets/branding/play-icon.png', stage / 'bibledoor.png')
    with tarfile.open(archive, 'w:gz') as package:
        package.add(stage, arcname='BibleDoor')
print(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}')
