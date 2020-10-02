// gamepad.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stddef.h>

#include "gamepad.h"

#include "assert.h"

static volatile uint32_t * const PAD_BASE = (uint32_t *)0x40000;

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

    // Latch the current state of pad inputs
    PAD_IO = PAD_LATCH;
    PAD_IO = 0;

    uint16_t p1_new = 0;
    uint16_t p2_new = 0;
    for (uint8_t i = 0; i < button_count; i++) {
        p1_new >>= 1;
        p2_new >>= 1;

        // Read current bit..
        uint8_t input_bits = PAD_IO;
        // ..and clock in the next bit
        PAD_IO = PAD_CLK;
        PAD_IO = 0;

        p1_new |= (input_bits & 1) << 15;
        p2_new |= ((input_bits >> 1) & 1) << 15;
    }

    // Edge inputs
    if (p1_edge) {
        *p1_edge = (p1_new ^ *p1_current) & p1_new;
    }
    if (p2_current && p2_edge) {
        *p2_edge = (p2_new ^ *p2_current) & p2_new;
    }

    // Level inputs
    *p1_current = p1_new;

    if (p2_current) {
        *p2_current = p2_new;
    }
}

void pad_decode_input(uint16_t encoded_input, PadInputDecoded *decoded_input) {
    assert(decoded_input);

    for (uint32_t i = 0; i < 12; i++) {
        decoded_input->indexed[i] = encoded_input & 1;
        encoded_input >>= 1;
    }
}

const PadInputDecoded PAD_INPUT_DECODED_NO_INPUT = {
    .b = 0, .y = 0, .select = 0, .start = 0,
    .up = 0, .down = 0, .left = 0, .right = 0,
    .a = 0, .x = 0, .l = 0, .r = 0,
    
    .raw = 0
};
