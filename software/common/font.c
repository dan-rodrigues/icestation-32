// font.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>

#include "vdp.h"
#include "font.h"

#include "font8x8_basic.h"

// this converts the 1bpp font tiles to the required 4bpp color format

void upload_font(uint16_t vram_base) {
    const uint16_t char_total = 128;

    vdp_seek_vram(vram_base);
    vdp_set_vram_increment(1);

    for (uint8_t char_id = 0; char_id < char_total; char_id++) {
        for(uint8_t line = 0; line < 8; line++) {
            uint8_t monochrome_line = font8x8_basic[char_id][line];
            uint32_t rendered_line = 0;

            for (uint8_t pixel = 0; pixel < 8; pixel++) {
                rendered_line <<= 4;
                rendered_line |= (monochrome_line &0x01) ? 0x01 : 0x00;

                monochrome_line >>= 1;
            }

            vdp_write_vram(rendered_line & 0xffff);
            vdp_write_vram(rendered_line >> 16);
        }
    }
}
