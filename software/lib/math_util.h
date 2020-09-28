// math_util.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef math_util_h
#define math_util_h

#include <stdint.h>

#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#define ABS(a) (((a) < 0) ? (-(a)) : (a))
#define SIGN(a) ((a) < 0)

// Signed s16xs16=s32 multiply
//
// The int32_t parameter types are only so compiler generated code doesn't
// unnecessarily truncate the upper bits when it has no ill effect.

int32_t sys_multiply(int32_t a, int32_t b);

static const uint16_t SIN_PERIOD = 0x400;
static const int16_t SIN_MAX = 0x4000;

int16_t cos(uint16_t angle);
int16_t sin(uint16_t angle);

#endif
