// gamepad.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stddef.h>

#include "gamepad.h"

#include "assert.h"

static const volatile uint32_t *PAD_BASE = (uint32_t *)0x40000;

static const uint32_t PAD_LATCH = 1 << 0;
static const uint32_t PAD_CLK = 1 << 1;

#define PAD_IO (*((volatile uint32_t *) PAD_BASE + 0))

// The parts of this function that access PAD_IO will eventually be rewritten in assembly
// The (S)NES pads may work properly if the latch/clk/input is accessed too quickly by the CPU
// Complicating things are the 2 possible clocks for the CPU and third party clones of the gamepads
//
// The assembly function can order and time accesses appropriately

void pad_read(uint16_t *p1_current, uint16_t *p2_current, uint16_t *p1_edge, uint16_t *p2_edge) {
    assert(p1_current);

    const uint8_t button_count = 16;

    // latch current pad inputs
    PAD_IO = PAD_LATCH;
    PAD_IO = 0;

    uint16_t p1_new = 0;
    uint16_t p2_new = 0;
    for (uint8_t i = 0; i < button_count; i++) {
        // read p1/p2 inputs simulatenously
        p1_new >>= 1;
        p2_new >>= 1;

        // read and clock in next bit
        uint8_t input_bits = PAD_IO;
        PAD_IO = PAD_CLK;
        PAD_IO = 0;

        p1_new |= (input_bits & 1) << 15;
        p2_new |= ((input_bits >> 1) & 1) << 15;
    }

    // edge inputs
    if (p1_edge) {
        *p1_edge = (p1_new ^ *p1_current) & p1_new;
    }
    if (p2_current && p2_edge) {
        *p2_edge = (p2_new ^ *p2_current) & p2_new;
    }

    // level inputs
    *p1_current = p1_new;

    if (p2_current) {
        *p2_current = p2_new;
    }
}
