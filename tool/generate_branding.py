"""Render the source vector icon. Requires ImageMagick; no network access."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
source = root / 'assets/branding/bibledoor.svg'
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    target = root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    subprocess.run(['convert', '-background', '#294d3a', str(source), '-resize', f'{size}x{size}', 'PNG32:' + str(target)], check=True)
subprocess.run(['convert', '-background', '#294d3a', str(source), '-resize', '512x512', 'PNG32:' + str(root / 'assets/branding/play-icon.png')], check=True)

subprocess.run(['convert', '-background', '#294d3a', str(root / 'assets/branding/feature-graphic.svg'), '-alpha', 'off', 'PNG24:' + str(root / 'assets/branding/feature-graphic.png')], check=True)

subprocess.run(['convert', str(root / 'assets/branding/play-icon.png'),
                '-define', 'icon:auto-resize=256,128,64,48,32,16',
                str(root / 'windows/runner/resources/app_icon.ico')], check=True)
