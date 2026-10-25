#!/usr/bin/env python3
"""Install the built Linux app for the current user, without sudo.

Usage: python3 tool/install_linux.py [--prefix /path/to/local]
The default prefix is ~/.local. Run again after rebuilding to update the app.
Bible downloads and preferences are stored separately and are never removed.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', type=Path, default=Path.home() / '.local')
    args = parser.parse_args()
    prefix = args.prefix.expanduser().resolve()
    # Desktop Entry Exec parsing is not shell parsing. Keep its quoted absolute
    # path unambiguous; ordinary paths, including spaces, work as written below.
    if any(char in str(prefix) for char in '\\"`$%\n\r'):
        parser.error('Use an installation path without quotes, backslashes, $, %, or newlines.')
    project = Path(__file__).resolve().parents[1]
    bundle = project / 'build/linux/x64/release/bundle'
    if not (bundle / 'bibledoor').is_file():
        parser.error('Build the desktop app first: flutter build linux --release')
    destination = prefix / 'opt/bibledoor'
    marker = destination / '.bibledoor-install'
    if destination.exists() and not marker.is_file():
        parser.error(f'Refusing to replace an unrelated directory: {destination}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Stage the complete bundle before replacing an existing installation.
    stage = Path(tempfile.mkdtemp(prefix='.bibledoor-', dir=destination.parent))
    backup = None
    try:
        shutil.copytree(bundle, stage, dirs_exist_ok=True)
        (stage / '.bibledoor-install').write_text('BibleDoor user installation\n')
        shutil.copy2(project / 'assets/branding/play-icon.png', stage / 'bibledoor.png')
        for name in ('LICENSE', 'NOTICE'):
            shutil.copy2(project / name, stage / name)
        if destination.exists():
            backup = stage.with_name(stage.name + '-previous')
            destination.rename(backup)
        try:
            stage.rename(destination)
        except OSError:
            if backup is not None:
                backup.rename(destination)
                backup = None
            raise
        applications = prefix / 'share/applications'
        applications.mkdir(parents=True, exist_ok=True)
        launcher = applications / 'org.freelygiven.bibledoor.desktop'
        launcher.write_text(
            '[Desktop Entry]\n'
            'Version=1.0\n'
            'Type=Application\n'
            'Name=Bible Door\n'
            'Comment=Read and compare Bible translations offline\n'
            f'Exec="{destination / "bibledoor"}"\n'
            f'Icon={destination / "bibledoor.png"}\n'
            'Terminal=false\n'
            'Categories=Education;Literature;\n'
            'Keywords=Bible;Scripture;Reader;\n'
            'StartupNotify=true\n'
            'StartupWMClass=org.freelygiven.bibledoor\n'
        )
        if shutil.which('update-desktop-database'):
            subprocess.run(['update-desktop-database', str(applications)], check=False)
        print(f'Installed Bible Door in {destination}')
        print('Open your application menu and search for Bible Door.')
        print(f'Or run: {destination / "bibledoor"}')
    finally:
        if stage.exists():
            shutil.rmtree(stage)
        if backup is not None and backup.exists():
            shutil.rmtree(backup)


if __name__ == '__main__':
    main()
