f = open('Application.pic', 'rb')
data = f.read()
f.close()

print(f'File size: {len(data)} bytes')
print('\nAll bytes (hex):')
for i in range(0, len(data), 16):
    hex_str = ' '.join(f'{b:02x}' for b in data[i:i+16])
    ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
    print(f'{i:04x}: {hex_str:<48} {ascii_str}')
