// vdp.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp.h"

// private register constants
// these are free to move around as needed
static VDP_REG VDP_BASE = (VDP_REG)0x010000;

static VDP_REG VDP_RENDER_CTRL_BASE = VDP_BASE + 0x20;

static VDP_REG VDP_SCROLL_TILE_ADDRESS_BASE = VDP_BASE + 0x10;
static VDP_REG VDP_HSCROLL_BASE = VDP_BASE + 0x14;
static VDP_REG VDP_VSCROLL_BASE = VDP_BASE + 0x18;
static VDP_REG VDP_SCROLL_MAP_ADDRESS_BASE = VDP_BASE + 0x1c;

// exported constants

const VDPLayer VDP_ALL_LAYERS = 0x1f;

VDP_REG VDP_CURRENT_RASTER_BASE = VDP_BASE + 0x00;

// scrolling layer map attributes

const uint16_t SCROLL_MAP_X_FLIP_SHIFT = 9;
const uint16_t SCROLL_MAP_Y_FLIP_SHIFT = 10;

const uint16_t SCROLL_MAP_X_FLIP = 1 << SCROLL_MAP_X_FLIP_SHIFT;
const uint16_t SCROLL_MAP_Y_FLIP = 1 << SCROLL_MAP_Y_FLIP_SHIFT;
const uint16_t SCROLL_MAP_PAL_SHIFT = 12;

// sprite meta attributes

// x_block
const uint16_t SPRITE_X_FLIP = 1 << 10;

// y_block
const uint16_t SPRITE_Y_FLIP = 1 << 9;
const uint16_t SPRITE_16_TALL = 1 << 10;
const uint16_t SPRITE_16_WIDE = 1 << 11;

// g_block
const uint16_t SPRITE_PRIORITY_SHIFT = 10;
const uint16_t SPRITE_PAL_SHIFT = 12;

// convenience macros

#define VDP_LAYER_ENABLE (*((VDP_REG) VDP_RENDER_CTRL_BASE + 0))
#define VDP_ALPHA_OVER_ENABLE (*((VDP_REG) VDP_RENDER_CTRL_BASE + 1))
#define VDP_SCROLL_WIDE_MAP_ENABLE (*((VDP_REG) VDP_RENDER_CTRL_BASE + 2))

#define VDP_TARGET_RASTER_X (*((VDP_REG) VDP_RENDER_CTRL_BASE + 3))
#define VDP_TARGET_RASTER_Y (*((VDP_REG) VDP_RENDER_CTRL_BASE + 4))

#define VDP_MATRIX_A (*((VDP_REG) VDP_HSCROLL_BASE + 1))
#define VDP_MATRIX_B (*((VDP_REG) VDP_HSCROLL_BASE + 2))
#define VDP_MATRIX_C (*((VDP_REG) VDP_HSCROLL_BASE + 3))
#define VDP_MATRIX_D (*((VDP_REG) VDP_VSCROLL_BASE + 1))

#define VDP_AFFINE_PRETRANSLATE_X (*((VDP_REG) VDP_VSCROLL_BASE + 2))
#define VDP_AFFINE_PRETRANSLATE_Y (*((VDP_REG) VDP_VSCROLL_BASE + 3))

#define VDP_SPRITE_TILE_BASE (*((volatile uint16_t *) VDP_BASE + 7))
#define VDP_SPRITE_BLOCK_ADDRESS (*((VDP_REG) VDP_BASE + 0))
#define VDP_SPRITE_DATA (*((VDP_REG) VDP_BASE + 1))

#define VDP_PALETTE_ADDRESS (*((volatile uint16_t *) VDP_BASE + 2))
#define VDP_PALETTE_WRITE_DATA (*((volatile uint16_t *) VDP_BASE + 3))

#define VDP_VRAM_ADDRESS (*((volatile uint16_t *) VDP_BASE + 4))
#define VDP_VRAM_WRITE_DATA (*((volatile uint16_t *) VDP_BASE + 5))
#define VDP_ADDRESS_INCREMENT (*((volatile uint16_t *) VDP_BASE + 6))

void vdp_set_layer_map_base(uint8_t layer, uint16_t address) {
    VDP_SCROLL_MAP_ADDRESS_BASE[layer] = address / 2;
}

void vdp_set_layer_tile_base(uint8_t layer, uint16_t address) {
    VDP_SCROLL_TILE_ADDRESS_BASE[layer] = address / 2;
}

void vdp_set_alpha_over_layers(VDPLayer layers) {
    VDP_ALPHA_OVER_ENABLE = layers;
}

void vdp_enable_layers(VDPLayer layers) {
    VDP_LAYER_ENABLE = layers;
}

void vdp_write_vram(uint16_t word) {
    VDP_VRAM_WRITE_DATA = word;
}

void vdp_fill_vram(uint16_t count, uint16_t word) {
    for (uint16_t i = 0; i < count; i++) {
        VDP_VRAM_WRITE_DATA = word;
    }
}

void vdp_seek_vram(uint16_t address) {
    VDP_VRAM_ADDRESS = address;
}

void vdp_write_palette_range(uint8_t color_id_start, uint8_t count, const uint16_t *palette_start) {
    VDP_PALETTE_ADDRESS = color_id_start;

    for (uint16_t i = 0; i < count; i++) {
        VDP_PALETTE_WRITE_DATA = palette_start[i];
    }
}

void vdp_set_single_palette_color(uint8_t color_id, uint16_t color) {
    VDP_PALETTE_ADDRESS = color_id;
    VDP_PALETTE_WRITE_DATA = color;
}

void vdp_seek_palette(uint8_t color_id) {
    VDP_PALETTE_ADDRESS = color_id;
}

void vdp_write_palette_color(uint16_t color) {
    VDP_PALETTE_WRITE_DATA = color;
}

void vdp_set_layer_scroll(uint8_t layer, uint16_t scroll_x, uint16_t scroll_y) {
    uint8_t index = layer &0xff;
    VDP_HSCROLL_BASE[index] = scroll_x;
    VDP_VSCROLL_BASE[index] = scroll_y;
}

void vdp_set_vram_increment(uint8_t increment) {
    VDP_ADDRESS_INCREMENT = increment;
}

void vdp_write_single_sprite_meta(uint8_t sprite_id, uint16_t x_block, uint16_t y_block, uint16_t g_block) {
    VDP_SPRITE_BLOCK_ADDRESS = sprite_id;

    VDP_SPRITE_DATA = x_block;
    VDP_SPRITE_DATA = y_block;
    VDP_SPRITE_DATA = g_block;
}

void vdp_seek_sprite(uint8_t sprite_id) {
    VDP_SPRITE_BLOCK_ADDRESS = sprite_id;
}

void vdp_write_sprite_meta(uint16_t x_block, uint16_t y_block, uint16_t g_block) {
    VDP_SPRITE_DATA = x_block;
    VDP_SPRITE_DATA = y_block;
    VDP_SPRITE_DATA = g_block;
}

void vdp_set_sprite_tile_base(uint16_t base) {
    VDP_SPRITE_TILE_BASE = base / 2;
}

void vdp_clear_all_sprites() {
    const uint16_t y_block = 480;

    VDP_SPRITE_BLOCK_ADDRESS = 0;

    for (uint16_t i = 0; i < 256; i++) {
        VDP_SPRITE_DATA = 0;
        VDP_SPRITE_DATA = y_block;
        VDP_SPRITE_DATA = 0;
    }
}

void vdp_set_wide_map_layers(VDPLayer layers) {
    VDP_SCROLL_WIDE_MAP_ENABLE = layers;
}

void vdp_set_target_raster_x(uint16_t x) {
    VDP_TARGET_RASTER_X = x;
}

void vdp_set_target_raster_y(uint16_t y) {
    VDP_TARGET_RASTER_Y = y;
}

void vdp_set_affine_matrix(int16_t a, int16_t b, int16_t c, int16_t d) {
    VDP_MATRIX_A = a;
    VDP_MATRIX_B = b;
    VDP_MATRIX_C = c;
    VDP_MATRIX_D = d;
}

void vdp_set_affine_pretranslate(int16_t x, int16_t y) {
    VDP_AFFINE_PRETRANSLATE_X = x;
    VDP_AFFINE_PRETRANSLATE_Y = y;
}

void vdp_wait_frame_ended() {
    const uint16_t final_line = 480;

    while (VDP_CURRENT_RASTER_Y != final_line) {}
}
