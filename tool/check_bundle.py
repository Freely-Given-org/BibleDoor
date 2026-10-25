"""Inspect native ELF segment alignment in an Android App Bundle.

Usage: python3 tool/check_bundle.py build/app/outputs/bundle/release/app-release.aab
This checks ELF alignment, not Android's runtime behaviour or signing.
"""
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as bundle:
    count = 0
    for name in bundle.namelist():
        if not name.endswith('.so') or not any(abi in name for abi in ('arm64-v8a', 'x86_64')):
            continue
        data = bundle.read(name)
        if data[:5] != b'\x7fELF\x02':
            raise SystemExit(f'Expected a 64-bit ELF: {name}')
        endian = '<' if data[5] == 1 else '>'
        offset = struct.unpack_from(endian + 'Q', data, 32)[0]
        entry_size, entries = struct.unpack_from(endian + 'HH', data, 54)
        alignments = []
        for i in range(entries):
            start = offset + i * entry_size
            if struct.unpack_from(endian + 'I', data, start)[0] == 1:
                alignment = struct.unpack_from(endian + 'Q', data, start + 48)[0]
                alignments.append(alignment)
                if alignment < 16384:
                    raise SystemExit(f'FAIL: {name} has LOAD alignment {alignment}')
        if not alignments:
            raise SystemExit(f'No LOAD segments: {name}')
        print(f'{name}: minimum LOAD alignment {min(alignments)}')
        count += 1
    if count == 0:
        raise SystemExit('No 64-bit native libraries found')
    signed = any(name.startswith('META-INF/') and name.endswith(('.RSA', '.DSA', '.EC')) for name in bundle.namelist())
    print(f'PASS: {count} libraries support 16 KB ELF alignment. Bundle signed: {signed}.')
