#!/usr/bin/env python3

import os, sys, re

prg_alloc = 32*1024
chr_alloc = 32*1024

prg_dat = bytearray()
chr_dat = bytearray()
header = None
with open(sys.argv[1], 'rb') as f:
    header = f.read(16)
    prg_size = header[4] * 16384
    chr_size = header[5] * 8192
    assert prg_size <= 2 * prg_alloc #PRG can spill into CHR sometimes
    prg_dat = f.read(prg_size)
    if prg_size > prg_alloc:
        assert chr_size == 0
    else:
        assert chr_size <= chr_alloc
        chr_dat = f.read(chr_size)

prg_dat = bytearray(prg_dat)
chr_dat = bytearray(chr_dat)

for i in range(prg_size, prg_alloc):
    prg_dat.append(prg_dat[i % prg_size])
if prg_size > prg_alloc:
    for i in range(prg_size, 2*prg_alloc):
        prg_dat.append(prg_dat[i % prg_size])
else:
    for i in range(chr_size, chr_alloc):
        if chr_size == 0:
            chr_dat.append(0)
        else:
            chr_dat.append(chr_dat[i % chr_size])

out_flags = 0x0
mapper = (header[6] >> 4) & 0x0F
mapper |= header[7] & 0xF0
out_flags |= mapper

mirroring  = header[6] & 0x01
fourscreen = (header[6] >> 3) & 0x01

prg_mask = 0
if prg_size <= 16*1024:
    prg_mask = 0
elif prg_size <= 32*1024:
    prg_mask = 1
elif prg_size <= 64*1024:
    prg_mask = 2
elif prg_size <= 128*1024:
    prg_mask = 3
elif prg_size <= 256*1024:
    prg_mask = 4
elif prg_size <= 512*1024:
    prg_mask = 5
elif prg_size <= 1024*1024:
    prg_mask = 6
else:
    prg_mask = 7
    
chr_mask = 0
if chr_size <= 8*1024:
    chr_mask = 0
elif chr_size <= 16*1024:
    chr_mask = 1
elif chr_size <= 32*1024:
    chr_mask = 2
elif chr_size <= 64*1024:
    chr_mask = 3
elif chr_size <= 128*1024:
    chr_mask = 4
elif chr_size <= 256*1024:
    chr_mask = 5
elif chr_size <= 512*1024:
    chr_mask = 6
else:
    chr_mask = 7

if chr_size == 0:
    has_chr_ram = 1
else:
    has_chr_ram = 0

out_flags |= (prg_mask << 8)
out_flags |= (chr_mask << 11)
out_flags |= (mirroring << 14)
out_flags |= (has_chr_ram << 15)
out_flags |= (fourscreen << 16)

with open(sys.argv[2], 'wb') as f:
    f.write(prg_dat)
    print(len(prg_dat));
    f.write(chr_dat)
    print(len(chr_dat));
    # Append mapper, size and other flags to end of data
    f.write(bytes([(out_flags) & 0xFF, (out_flags >> 8) & 0xFF, (out_flags >> 16) & 0xFF, (out_flags >> 24) & 0xFF]))
    #f.write(bytearray(256*1024 - (prg_alloc + chr_alloc + 4))) # pad to 256kB total
