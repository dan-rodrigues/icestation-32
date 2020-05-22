// math_util.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "math_util.h"

#include "sin_table.h"

// MMIO for multiplier (DSP)

static volatile uint32_t *const SYS_MUL_BASE = (uint32_t *)0x030000;

#define SYS_MUL_A (*((volatile int16_t *)SYS_MUL_BASE + 0))
#define SYS_MUL_B (*((volatile int16_t *)SYS_MUL_BASE + 2))

#define SYS_MUL_RESULT (*((volatile int32_t *)SYS_MUL_BASE + 0))

int32_t sys_multiply(int16_t a, int16_t b) {
    SYS_MUL_A = a;
    SYS_MUL_B = b;

    return SYS_MUL_RESULT;
}

// sin and cos

static const int16_t SIN_MAX = 0x4000;

static const uint16_t SIN_PERIOD = 0x400;
static const uint16_t SIN_HALF_PERIOD = SIN_PERIOD / 2;
static const uint16_t SIN_QUARTER_PERIOD = SIN_PERIOD / 4;

int16_t cos(uint16_t angle) {
    return sin(angle + SIN_QUARTER_PERIOD);
}

int16_t sin(uint16_t angle) {
    angle &= (SIN_PERIOD - 1);

    // special cases to avoid "flat spots" in the sin wave
    if (angle == SIN_QUARTER_PERIOD) {
        return SIN_MAX;
    } else if (angle == (3 * SIN_QUARTER_PERIOD)) {
        return -SIN_MAX;
    }

    uint16_t index = angle;
    index = (angle & SIN_QUARTER_PERIOD ? -index : index);
    index &= (SIN_QUARTER_PERIOD - 1);

    int16_t sin = sin_table[index];

    return (angle & SIN_HALF_PERIOD ? -sin : sin);
}
