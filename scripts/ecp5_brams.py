#!/usr/bin/env python3
'''
Find and replace the Icestation-32's initial RAM in the FPGA configuration file
with an arbitary program.

This can then be directly converted to a bitstream and uploaded to the FPGA.
This allows uploading a game together with otherwise unchanged hardware without having to
re-run yosys and nextpnr every time.

It only works for games that do not rely on flash resources, or that have
flash resources already still in place from a previous run.

Usage:
    ecp5_brams.py ulx3s_pnr.json ulx3s.config boot_multi_noipl.bin prog.bin out.config
    ecppack --input out.config --bit out.bit
    fujprog -j sram out.bit # or through FTP
'''
# (C) Mara "vmedea" 2020
# SPDX-License-Identifier: MIT
import sys
import json
import re
import struct

BOOTLOADER_SIZE = 512
RAM_SIZE = 16384

# regexp for BRAM init statements
# these are followed by 256 lines of 8 12-bit hexadecimal values
BRAM_RE = re.compile("\.bram_init (\d+)$")

class ConfigFile:
    def __init__(self, inconfig):
        '''
        Load a FPGA configuration file.
        '''
        with open(inconfig, 'r') as f:
            self.config = list(f)

        # Remember starting line number in configuration for every BRAM
        self.brams = {}
        for line_nr, line in enumerate(self.config):
            match = BRAM_RE.match(line)
            if match:
                # it must be followed by 256 lines of data, then an empty line
                assert(self.config[line_nr + 257] == '\n')
                self.brams[int(match.group(1))] = {'line_nr': line_nr}

    def write(self, outconfig):
        '''
        Write updated FPGA configuration to disk.
        '''
        with open(outconfig, 'w') as f:
            f.write(''.join(self.config))

    def parse_bram_data(self, num):
        '''
        Parse BRAM data from config file.
        '''
        base = self.brams[num]['line_nr'] + 1
        result = []
        for line in range(256):
            items = self.config[base + line].rstrip().split(' ')
            items = [int(x, 16) for x in items]
            assert(len(items) == 8)
            result += items
        return result

    def set_bram_data(self, num, data):
        '''
        Fill a BRAM in config file with new data.
        '''
        base = self.brams[num]['line_nr'] + 1
        assert(len(data) == 2048)
        for line in range(256):
            items = []
            for val in data[line * 8:line * 8 + 8]:
                assert(val >= 0 and val < 4096)
                items.append('%03x' % val)
            self.config[base + line] = (' '.join(items)) + '\n'

class DesignFile:
    def __init__(self, injson):
        '''Load nextpnr-augmented JSON design file.'''
        # load nextpnr-augmented JSON design file
        with open(injson, 'r') as f:
            self.design = json.load(f)

        # Create a table of BRAM WID by name
        self.wid_by_name = {}
        for name, cell in self.design['modules']['top']['cells'].items():
            if cell['type'] == 'DP16KD':
                wid = int(cell['attributes']['WID'], 2)
                self.wid_by_name[name] = wid

COLUMN_MASK = 0x8080808080808080
MAGIC       = 0x0002040810204081
ALL_MASK    = 0xffffffffffffffff

def transpose8x8(byte):
    '''8×8 bit matrix transpose.'''
    block8x8 = next(byte) | (next(byte) << 8) | (next(byte) << 16) | (next(byte) << 24) | (next(byte) << 32) | (next(byte) << 40) | (next(byte) << 48) | (next(byte) << 56)
    return (((((block8x8 << (7 - col)) & COLUMN_MASK) * MAGIC) & ALL_MASK) >> 56 for col in range(8))

def interleave_rams32(ram):
    '''
    Interleave 32 * 8 1-bit RAMs into a single 32-bit RAM.
    '''
    result = [0] * 16384
    assert(len(ram) == 32)

    for addrh in range(16384 // 8):
        p = [transpose8x8(ram[ofs + bit][addrh] for bit in range(0, 8)) for ofs in [0, 8, 16, 24]]
        result[addrh * 8: addrh * 8 + 8] = [(a | (b << 8) | (c << 16) | (d << 24)) for (a, b, c, d) in zip(*p)]

    return result

def deinterleave_ram32(ram):
    '''
    Deinterleave a 32-bit RAM into 32 * 8 1-bit RAMs.
    '''
    assert(len(ram) == 16384)
    result = [[0] * 2048 for bit in range(32)]

    for addrh in range(16384 // 8):
        s = ram[addrh * 8:addrh * 8 + 8]
        for ofs in [0, 8, 16, 24]:
            for bit, v in enumerate(transpose8x8((x >> ofs) & 0xff for x in s)):
                result[bit + ofs][addrh] = v

    return result

def bootrom_to_bram(rom):
    '''
    Encode bootrom contents to a single BRAM as used in the ICS32 design.
    '''
    bram = [0] * 2048
    for idx, val in enumerate(rom):
        bram[idx * 4 + 0] = (val >> 0) & 0x1ff
        bram[idx * 4 + 1] = (val >> 9) & 0x1ff
        bram[idx * 4 + 2] = (val >> 18) & 0x1ff
        bram[idx * 4 + 3] = (val >> 27) & 0x1ff

    return bram

def load_binary(inprog, size):
    '''Load binary data as an array of little endian 32-bit words.'''
    with open(inprog, 'rb') as f:
        progdata = bytearray(size * 4)
        f.readinto(progdata)
        return list(struct.unpack(f'<{size}I', progdata))

# --------------------------------------------------- Tests --------------------------------------------
def ram_interleave_test():
    testdata = [(((65535 - x) << 16) | x) for x in range(16384)]

    rams = deinterleave_ram32(testdata)
    assert(rams[0] == [170] * 2048)
    assert(rams[1] == [204] * 2048)
    assert(rams[2] == [240] * 2048)
    assert(rams[3] == [0, 255] * 1024)
    assert(rams[4] == [0, 0, 255, 255] * 512)
    # ...
    assert(rams[16] == [85] * 2048)
    assert(interleave_rams32(rams) == testdata)

def bootrom_test(config, design, firmware='../../firmware/boot_multi.bin'):
    # check that contents of the specified bram match the bootrom as expected
    wid = design.wid_by_name['ics32.bootloader.0.0']
    bootrom = config.parse_bram_data(wid)
    data_check = open(firmware, 'rb').read()
    import struct

    for idx in range(len(data_check) // 4):
        a = bootrom[idx * 4 + 0] & 0x1ff
        b = bootrom[idx * 4 + 1] & 0x1ff
        c = bootrom[idx * 4 + 2] & 0x1ff
        d = bootrom[idx * 4 + 3] & 0x1f
        val = a | (b << 9) | (c << 18) | (d << 27)

        assert(struct.pack('<I', val) == data_check[idx*4:idx*4+4])
# ------------------------------------------------------------------------------------------------------

if __name__ == '__main__':
    injson = sys.argv[1]
    inconfig = sys.argv[2]
    inbootrom = sys.argv[3]
    inprog = sys.argv[4]
    outconfig = sys.argv[5]
    # perform internal sanity checks. to perform all checks, it needs RAM pre-loaded with test pattern:
    # - cpu_ram_0 should have increasing values 0x0000 .. 0x3fff
    # - cpu_ram_1 should have decreasing values 0xffff .. 0xc000
    perform_checks = False

    config = ConfigFile(inconfig)
    design = DesignFile(injson)

    if perform_checks:
        ram_interleave_test()

    # BRAM per bit
    # cpu_ram_0 has bits [15:0]
    # cpu_ram_1 has bits [31:16]
    # two RAMs (upper, lower 16 bit) each consisting of 16 BELs
    # seems the individual RAMs are sliced per bit 0..15, each item contains 8 bits (8 consecutive addresses)
    cpu_ram = [design.wid_by_name['ics32.cpu_ram.cpu_ram_%d.mem.0.%d' % (bit // 16, bit % 16)] for bit in range(32)]
    bootrom_wid = design.wid_by_name['ics32.bootloader.0.0']

    if perform_checks: # check for an initial RAM test pattern provided in verilog
        ram_data = [config.parse_bram_data(cpu_ram[bit]) for bit in range(32)]
        testdata = [(((65535 - x) << 16) | x) for x in range(16384)]
        assert(interleave_rams32(ram_data) == testdata)

    # load the bootrom
    if perform_checks:
        bootrom_test(config, design)
    bootromdata = load_binary(inbootrom, BOOTLOADER_SIZE)

    # write it into the bram
    config.set_bram_data(bootrom_wid, bootrom_to_bram(bootromdata))
    if perform_checks:
        bootrom_test(config, design, inbootrom)

    # load the binary
    progdata = load_binary(inprog, RAM_SIZE)

    # write it into brams
    for bit, data in enumerate(deinterleave_ram32(progdata)):
        config.set_bram_data(cpu_ram[bit], data)
    if perform_checks:
        ram_data = [config.parse_bram_data(cpu_ram[bit]) for bit in range(32)]
        assert(interleave_rams32(ram_data) == progdata)

    # write new config file
    config.write(outconfig)
