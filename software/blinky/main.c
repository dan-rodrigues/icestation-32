// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>

#include "vdp.h"
#include "status.h"

int main() {
    // Blink leds 0..7 along to the vsync clock
    uint32_t frame = 0;
    while (true) {
        status_set_leds(frame / 16);
        vdp_wait_frame_ended();
        frame += 1;
    }
}
