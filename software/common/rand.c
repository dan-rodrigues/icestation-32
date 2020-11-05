// rand.c: generate random bits
//
// Copyright (C) 2020 Mara "vmedea" <vmedea@protonmail.com>
//
// SPDX-License-Identifier: MIT
#include "rand.h"

static uint32_t random_state = 0x12345678;

void srand(uint32_t s) {
    random_state = s;
}

uint32_t randbits(uint8_t nbits) {
    uint32_t val = 0;
    for (uint8_t i = 0; i < nbits; ++i) {
        uint32_t lsb = random_state & 1;
        random_state >>= 1;
        if (lsb)
            random_state ^= 0xf00f00f0;

        val = (val << 1) | lsb;
    }
    return val;
}
