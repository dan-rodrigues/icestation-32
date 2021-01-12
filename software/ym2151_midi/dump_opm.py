#!/usr/bin/env python3

# dump_opm.py
#
# Copyright (C) 2021 Dan Rodrigues <danrr.gh.oss@gmail.com>
#
# SPDX-License-Identifier: MIT

import struct
import sys
from pathlib import Path

class YMOperator:
    def __init__(self):
        self.dt1 = 0
        self.mul = 0
        self.tl = 0
        self.ks = 0
        self.ar = 0
        self.ame = 0
        self.dir = 0
        self.dt2 = 0
        self.d2r = 0
        self.d1l = 0
        self.rr = 0

    def bytes(self):
        return [
            self.ar, self.d1r, self.d2r, self.rr, self.d1l, self. tl, self.ks, self.mul,
            self.dt1, self.dt2, self.ame
        ]

class YMChannel:
    def __init__(self):
        self.pan = 0
        self.con = 0
        self.fl = 0
        self.ams = 0
        self.pms = 0

        self.operators = [YMOperator() for _ in range(4)]

    def bytes(self, slot_mask, ne):
        channel_state = [self.pan, self.fl, self.con, self.ams, self.pms, slot_mask, ne]

        for op in self.operators:
            channel_state += op.bytes()

        return channel_state

class YMState:
    def __init__(self):
        self.lfrq = 0
        self.nfrq = 0
        self.amd = 0
        self.pmd = 0
        self.wf = 0
        self.ne = 0

        self.channels = [YMChannel() for _ in range(8)]
        self.logged_voices = []

    def write(self, reg, data):
        # Key on/off:

        if reg == 0x08:
            slot_mask = data & (0x0f << 3)
            channel = data & 0x07

            if slot_mask != 0:
                voice_bytes = self.bytes(channel, slot_mask)
                self.logged_voices.append(voice_bytes)

        # LFO:

        elif reg == 0x0f:
            self.ne = data >> 7 & 0x01
            self.nfrq = data & 0x7f
        elif reg == 0x18:
            self.lfrq = data
        elif reg == 0x19:
            if data & 0x80:
                self.pmd = data & 0x7f
            else:
                self.amd = data
        elif reg == 0x1b:
            self.wf = data & 0x03

        # Per channel state:

        group = reg & 0xe0
        i = reg & 0x07
        channel = self.channels[i]

        if group == 0x20:
            subgroup = reg & 0x18

            if subgroup == 0x00:
                channel.pan = data & 0xc0
                channel.fl = data >> 3 & 0x07
                channel.con = data & 0x07
            elif subgroup == 0x08 or subgroup == 0x10:
                # (octave/note/fraction, not needed here)
                pass
            elif subgroup == 0x18:
                channel.pms = data >> 4 & 0x07
                channel.ams = data & 0x03
        else:
            # Per operator:
            op_index = (reg // 8) & 0x03
            op = channel.operators[op_index]

            if group == 0x40:
                op.dt1 = data >> 4 & 0x0f
                op.mul = data & 0x0f
            elif group == 0x60:
                op.tl = data
            elif group == 0x80:
                op.ar = data & 0x1f
                op.ks = data >> 6 & 0x03
            elif group == 0xa0:
                op.ame = data & 0x80
                op.d1r = data & 0x7f
            elif group == 0xc0:
                op.d2r = data & 0x1f
                op.dt2 = data >> 6 & 0x03
            elif group == 0xe0:
                op.rr = data & 0x0f
                op.d1l = data >> 4 & 0x0f

    def bytes(self, channel, slot_mask):
        return [
            self.lfrq, self.amd, self.pmd, self.wf, self.nfrq
        ] + self.channels[channel].bytes(slot_mask, self.ne)

vgm_file = open("track.vgm", "rb")

vgm = vgm_file.read()
vgm_file.close()

relative_offset_index = 0x34
relative_offset = int.from_bytes(vgm[relative_offset_index:relative_offset_index + 4], byteorder='little')
start_index = relative_offset_index + relative_offset if relative_offset else 0x40
print("start: {:X}".format(start_index))

loop_offset_index = 0x1c
loop_offset = int.from_bytes(vgm[loop_offset_index:loop_offset_index + 4], byteorder='little')
loop_index = loop_offset + loop_offset_index if loop_offset else 0
print("loop: {:X}".format(loop_index))

index = start_index

# Log all YM reg writes which will give us all voice params

state = YMState()

# Note this won't handle PCM data blocks etc., those need to be skipped if so

while index < len(vgm):
    cmd = vgm[index]
    index += 1

    if cmd == 0x54:
        reg = vgm[index]
        data = vgm[index + 1]
        index += 2

        state.write(reg, data)
    elif (cmd & 0xf0) == 0x70:
        pass
    elif cmd == 0x61:
        index += 2
    elif cmd == 0x62 or cmd == 0x63:
        pass
    elif cmd == 0x66:
        break

# Filter duplicate voices

unique_voices = []

for voice in state.logged_voices:
    already_logged = False
    for dumped_voice in unique_voices:
        already_logged = (dumped_voice == voice)
        if already_logged:
            break

    if already_logged:
        continue

    unique_voices.append(voice)

# Dump unique voices to individual .opm files

Path("opm/").mkdir(exist_ok=True)

for i in range(len(unique_voices)):
    with open("opm/{}.opm".format(i), "wb") as opm_file:
        opm_bin = unique_voices[i]
        opm_file.write(bytes(opm_bin))

print("Total voices: ", len(state.logged_voices))
print("Unique voices: ", len(unique_voices))
