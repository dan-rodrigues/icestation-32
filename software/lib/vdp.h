// vdp.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef vdp_h
#define vdp_h

#include <stdint.h>
#include <stdbool.h>

typedef volatile uint16_t *const VDP_REG;

static VDP_REG VDP_BASE = (VDP_REG)0x010000;

typedef enum {
    SCROLL0 = 1 << 0,
    SCROLL1 = 1 << 1,
    SCROLL2 = 1 << 2,
    SCROLL3 = 1 << 3,
    SPRITES = 1 << 4,

    AFFINE = 1 << 5
} VDPLayer;

extern const VDPLayer VDP_ALL_LAYERS;

// MARK: Screen metrics

extern const uint16_t SCREEN_ACTIVE_WIDTH;
extern const uint16_t SCREEN_ACTIVE_HEIGHT;
extern const uint16_t SCREEN_OFFSCREEN_X;

extern const uint16_t RASTER_X_MAX;

// MARK: Attributes

// scrolling layer map attribute bits

extern const uint16_t SCROLL_MAP_X_FLIP_SHIFT;
extern const uint16_t SCROLL_MAP_Y_FLIP_SHIFT;

extern const uint16_t SCROLL_MAP_X_FLIP;
extern const uint16_t SCROLL_MAP_Y_FLIP;
extern const uint16_t SCROLL_MAP_PAL_SHIFT;

// sprite meta block attribute bits

// y_block
extern const uint16_t SPRITE_Y_FLIP;
extern const uint16_t SPRITE_16_TALL;
extern const uint16_t SPRITE_16_WIDE;

// g_block
extern const uint16_t SPRITE_PRIORITY_SHIFT;
extern const uint16_t SPRITE_PAL_SHIFT;

// x_block
extern const uint16_t SPRITE_X_FLIP;

// MARK: Read functions

static const VDP_REG VDP_CURRENT_RASTER_BASE = VDP_BASE + 0x00;

#define VDP_CURRENT_RASTER_X (*((VDP_REG) VDP_CURRENT_RASTER_BASE + 0))
#define VDP_CURRENT_RASTER_Y (*((VDP_REG) VDP_CURRENT_RASTER_BASE + 2))

void vdp_wait_frame_ended(void);

// MARK: Write functions

void vdp_enable_copper(uint8_t enable);

void vdp_enable_layers(VDPLayer layers);
void vdp_set_alpha_over_layers(VDPLayer layers);
void vdp_set_wide_map_layers(VDPLayer layers);

void vdp_set_layer_tile_base(uint8_t layer, uint16_t address);
void vdp_set_layer_map_base(uint8_t layer, uint16_t address);

void vdp_seek_vram(uint16_t address);
void vdp_fill_vram(uint16_t count, uint16_t word);
void vdp_write_vram(uint16_t word);
void vdp_write_vram_block(const uint16_t *data, uint16_t size);
void vdp_set_vram_increment(uint8_t increment);

void vdp_write_palette_range(uint8_t color_id_start, uint32_t count, const uint16_t *palette_start);

void vdp_set_single_palette_color(uint8_t color_id, uint16_t color);
void vdp_seek_palette(uint8_t palette_id);
void vdp_write_palette_color(uint16_t color);

void vdp_set_layer_scroll(uint8_t layer, uint16_t scroll_x, uint16_t scroll_y);

void vdp_set_sprite_tile_base(uint16_t base);
void vdp_write_single_sprite_meta(uint8_t sprite_id, uint16_t x_block, uint16_t y_block, uint16_t g_block);
void vdp_seek_sprite(uint8_t sprite_id);
void vdp_write_sprite_meta(uint16_t x_block, uint16_t y_block, uint16_t g_block);
void vdp_clear_all_sprites(void);

void vdp_set_affine_matrix(int16_t a, int16_t b, int16_t c, int16_t d);
void vdp_set_affine_pretranslate(int16_t x, int16_t y);

void vdp_set_target_raster_x(uint16_t x);
void vdp_set_target_raster_y(uint16_t y);

void vdp_set_affine_matrix(int16_t a, int16_t b, int16_t c, int16_t d);
void vdp_set_affine_pretranslate(int16_t x, int16_t y);
void vdp_set_affine_translate(int16_t x, int16_t y);

// MARK: Convenience

bool vdp_layer_is_odd(VDPLayer layer);

#endif /* vdp_h */
