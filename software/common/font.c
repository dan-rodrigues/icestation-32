// font.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>

#include "vdp.h"
#include "font.h"

#include "font8x8_basic.h"
#include "font8x8_minimal.h"

// this converts the 1bpp font tiles to the required 4bpp color format

void upload_font(uint16_t vram_base) {
    upload_font_remapped(vram_base, 0, 1);
}

void upload_font_minimal(uint16_t vram_base) {
    upload_font_remapped_main(vram_base, 0, 1, font8x8_minimal, sizeof(font8x8_minimal)/8);
}

void upload_font_remapped(uint16_t vram_base, uint8_t transparent, uint8_t opaque) {
    upload_font_remapped_main(vram_base, transparent, opaque, font8x8_basic, sizeof(font8x8_basic)/8);
}

void upload_font_remapped_main(uint16_t vram_base, uint8_t transparent, uint8_t opaque, const char font[][8], uint16_t char_total) {
    vdp_seek_vram(vram_base);
    vdp_set_vram_increment(1);

    for (uint32_t char_id = 0; char_id < char_total; char_id++) {
        for(uint32_t line = 0; line < 8; line++) {
            uint32_t monochrome_line = font[char_id][line];
            uint32_t rendered_line = 0;

            for (uint32_t pixel = 0; pixel < 8; pixel++) {
                rendered_line <<= 4;
                rendered_line |= (monochrome_line & 0x01) ? opaque : transparent;

                monochrome_line >>= 1;
            }

            vdp_write_vram(rendered_line & 0xffff);
            vdp_write_vram(rendered_line >> 16);
        }
    }
}
