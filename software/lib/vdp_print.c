// vdp_print.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp_print.h"

#include "tinyprintf.h"

static uint8_t current_x, current_y, current_palette_mask;
static VDPLayer current_layer;
static uint16_t current_vram_base;

static void seek_update() {
    bool second_page = (current_x % 128) >= 64;
    current_x %= 64;

    uint16_t address = current_y * 64 + current_x;
    address += (second_page ? 0x1000 : 0);

    vdp_seek_vram(current_vram_base + address);
}

static void vdp_putc(void *p, char c) {
    uint16_t map = c & 0xff;
    map |= current_palette_mask;

    vdp_write_vram(map);
    current_x++;

    if (current_x == 64) {
        seek_update();
    }
}

void vp_print_init() {
    init_printf(NULL, vdp_putc);
}

void vp_printf(uint8_t x, uint8_t y, uint8_t palette, VDPLayer layer, uint16_t vram_base, const char *fmt, ...) {
    vdp_set_vram_increment(1);

    current_palette_mask = palette << SCROLL_MAP_PAL_SHIFT;
    current_x = x;
    current_y = y;
    current_layer = layer;
    current_vram_base = vram_base;

    seek_update();

    va_list args;
    va_start(args, fmt);
    tfp_format(NULL, vdp_putc, fmt, args);
    va_end(args);
}

void vp_clear_row(uint8_t y, VDPLayer layer, uint16_t vram_base) {
    vdp_set_vram_increment(1);

    current_x = 0;
    current_y = y;
    current_palette_mask = 0;
    current_layer = layer;
    current_vram_base = vram_base;

    seek_update();

    for (uint32_t i = 0; i < SCREEN_ACTIVE_WIDTH / 8; i++) {
        vdp_putc(NULL, ' ');
    }
}

uint8_t vp_center_string_x(const char *string) {
    uint8_t length = 0;
    while (*string++) {
        length++;
    }

    return SCREEN_ACTIVE_WIDTH / 8 / 2 - length / 2;
}
