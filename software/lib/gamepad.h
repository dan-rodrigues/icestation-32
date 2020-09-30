// gamepad.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef gamepad_h
#define gamepad_h

#include <stdint.h>
#include <stdbool.h>

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

typedef struct {
    union {
        struct {
            bool b, y, select, start;
            bool up, down, left, right;
            bool a, x;
            bool l, r;
        };

        bool indexed[12];
    };

    uint16_t raw;
} PadInputDecoded;

extern const PadInputDecoded PAD_INPUT_DECODED_NO_INPUT;

void pad_read(uint16_t *p1_current, uint16_t *p2_current, uint16_t *p1_edge, uint16_t *p2_edge);
void pad_decode_input(uint16_t encoded_input, PadInputDecoded *decoded_input);

#endif /* gamepad_h */
