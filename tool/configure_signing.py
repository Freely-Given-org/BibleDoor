#!/usr/bin/env python3
"""Configure ignored local Android signing without passwords in shell arguments."""
import argparse
import getpass
import os
from pathlib import Path
import subprocess
import tempfile


def property_value(value):
    return (value.replace('\\', '\\\\').replace('\n', '\\n')
            .replace('\r', '\\r').replace(':', '\\:').replace('=', '\\='))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('keystore', type=Path)
    parser.add_argument('--alias', required=True)
    parser.add_argument('--different-key-password', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    destination = project / 'android/key.properties'
    store = args.keystore.expanduser().resolve(strict=True)
    subprocess.run(['git', 'check-ignore', '--quiet', str(destination)],
                   cwd=project, check=True)
    password = getpass.getpass('Keystore password (hidden): ')
    key_password = (getpass.getpass('Key password (hidden): ')
                    if args.different_key_password else password)
    # keytool reads a mode-0600 temporary file, never a command-line password.
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8') as secret:
        secret.write(password)
        secret.flush()
        result = subprocess.run([
            'keytool', '-list', '-keystore', str(store), '-alias', args.alias,
            '-storepass:file', secret.name,
        ], capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('Could not open that keystore and alias. Signing settings were not changed.')
    values = {'storeFile': str(store), 'storePassword': password,
              'keyAlias': args.alias, 'keyPassword': key_password}
    fd = os.open(destination, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as output:
        output.write('\n'.join(f'{key}={property_value(value)}' for key, value in values.items()) + '\n')
    print('Local Android signing configured. Credentials are ignored by Git and readable only by your user.')


if __name__ == '__main__':
    main()
