// gamepad.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef gamepad_h
#define gamepad_h

#include <stdint.h>

typedef enum {
    GP_B        = 1 << 0,
    GP_Y        = 1 << 1,
    GP_SELECT   = 1 << 2,
    GP_START    = 1 << 3,
    GP_UP       = 1 << 4,
    GP_DOWN     = 1 << 5,
    GP_LEFT     = 1 << 6,
    GP_RIGHT    = 1 << 7,
    GP_A        = 1 << 8,
    GP_X        = 1 << 9,
    GP_L        = 1 << 10,
    GP_R        = 1 << 11
} PadInput;

void pad_read(uint16_t *p1_current, uint16_t *p2_current, uint16_t *p1_edge, uint16_t *p2_edge);

#endif /* gamepad_h */
