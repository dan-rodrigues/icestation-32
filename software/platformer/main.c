// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp.h"
#include "math_util.h"

#include <stdint.h>
#include <stdbool.h>

#include "fg_tiles.h"
#include "fg_palette.h"

#include "sprite_tiles.h"
#include "sprite_palette.h"

// TODO rename and convert from bin
#include "map-flat.h"

// hero frame defs, from earlier demo

typedef enum {
    RUN0,
    RUN1,
    RUN2,

    JUMP_RISING,
    JUMP_FALLING,

    LOOKING_UP,

    LOOKING_SCREEN_DIRECT,
    LOOKING_SCREEN_LEFT,
    LOOKING_SCREEN_RIGHT,

    PEACE_SIGN
} HeroFrame;

typedef struct {
    HeroFrame frame;

    int16_t x_offset;
    int16_t y_offset;

    uint16_t x_flip;

    // fixing this at 3 tiles for now
    const int16_t tiles[3 + 1];
} SpriteFrame;

static const SpriteFrame hero_frames[] = {
    {RUN0, 0, -1, 0, {0x000, 0x0e0, -1}},
    {RUN1, 0, 0, 0, {0x002, 0x0e0, -1}},
    {RUN2, 0, 0, 0, {0x004, 0x0e0, -1}},

    {JUMP_RISING, 0, 0, 0, {0x006, 0x0e8, -1}},
    {JUMP_FALLING, 0, 0, 0, {0x1a4, 0x18e, -1}},

    {LOOKING_UP, 0, 0, 0, {0x004, 0x140, -1}},

    {LOOKING_SCREEN_DIRECT, 0, 0, 0, {0x00e, 0x108, -1}},
    {LOOKING_SCREEN_LEFT, 0, 0, 0, {0x00e, 0x0e0, -1}},
    {LOOKING_SCREEN_RIGHT, 0, 0, 1, {0x00e, 0x0e0, -1}},

    {PEACE_SIGN, 0, 0, 0, {0x16e, 0x166, -1}},
};

static const size_t hero_frame_count = sizeof(hero_frames) / sizeof(SpriteFrame);

void draw_hero_sprites(uint8_t *base_sprite_id, HeroFrame frame, int16_t x, int16_t y, int16_t sprite_tile_id);
void upload_16x16_sprite(const uint32_t *tiles, uint16_t source_tile_base, uint16_t sprite_tile_base, uint16_t sprite_tile);


int main() {
    vdp_enable_layers(SCROLL0 | SPRITES);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);

    vdp_set_layer_scroll(0, 0, 0);

    const uint16_t tile_vram_base = 0x0000;

    // foreground tiles
    // the map expects them on the latter pages so
    const uint16_t foreground_tile_count = 128;

    vdp_set_layer_tile_base(0, tile_vram_base);

    vdp_set_vram_increment(1);
    // this loads it to the 3rd "page" of 128 tiles, where it is expected
    vdp_seek_vram(0 + 0x1800);
    for (uint16_t i = 0; i < foreground_tile_count * 32 / 4; i++) {
        vdp_write_vram(fg_tiles[i] & 0xffff);
        vdp_write_vram(fg_tiles[i] >> 16);
    }

    // foreground map

    const uint16_t map_vram_base = 0x4000;

    vdp_set_layer_map_base(0, map_vram_base);

    vdp_set_vram_increment(2);
    vdp_seek_vram(map_vram_base);

    uint32_t *map = (uint32_t *)mapFlat;
    for (uint16_t i = 0; i < 0x2000 / 4; i++) {
        vdp_write_vram(map[i] & 0xffff);
        vdp_write_vram(map[i] >> 16);
    }

    vdp_set_vram_increment(1);

    // foreground palette

    // the original map expeccts palette_id = 2
    vdp_write_palette_range(2 * 0x10, 0x10, fg_palette);

    // sprites (GFX is uploaded frame-by-frame)

    vdp_seek_palette(0);

    const uint16_t sprite_vram_base = 0x6000;

    vdp_set_sprite_tile_base(sprite_vram_base);

    vdp_write_palette_range(0, 0x10, sprite_palette);

    // DEMO: one sprite on screen
    // just borrow the affine_demo stuff where it uploads frames automatically
    // and cleanup as going along etc.

    uint8_t base_sprite_id = 0;

    vdp_clear_all_sprites();

    // background color

    vdp_set_single_palette_color(0, 0xf088);
    
    while (1) {
        draw_hero_sprites(&base_sprite_id, RUN2, 32, 32, 0);

        vdp_wait_frame_ended();
    }

    return 0;
}

void draw_hero_sprites(uint8_t *base_sprite_id, HeroFrame frame, int16_t x, int16_t y, int16_t sprite_tile_id) {
    const uint8_t hero_palette = 0;

    // resolve frame
    const SpriteFrame *sprite_frame = NULL;
    for (int i = 0; i < hero_frame_count; i++) {
        if (hero_frames[i].frame == frame) {
            sprite_frame = &hero_frames[i];
            break;
        }
    }

    // should never happen, have a proper assert for this case
    if (sprite_frame == NULL) {
        // move to some common utility file
        __asm__("ebreak");
    }

    uint8_t sprite_id = *base_sprite_id;

    const int16_t *charMap = sprite_frame->tiles;
    for (int i = 0; i < 8; i++) {
        int16_t sourceChar = charMap[i];
        if (sourceChar == -1) {
            break;
        }

        // sprite meta

        uint16_t x_block = x + sprite_frame->x_offset;
        x_block &= 0x3ff;
        // assuming flipped state
        // *unless the attribute says otherwise*
        if (sprite_frame->x_flip) {
            // ... nothing!
        } else {
            x_block |= SPRITE_X_FLIP;
        }

        uint16_t y_block = y + sprite_frame->y_offset;
        y_block &= 0x1ff;
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

        uint16_t g_block = sprite_tile_id;
        g_block |= 3 << SPRITE_PRIORITY_SHIFT | hero_palette << SPRITE_PAL_SHIFT;

        // upload and set graphics

        upload_16x16_sprite(sprite_tiles, sourceChar, 0x6000, sprite_tile_id);

        vdp_write_single_sprite_meta(sprite_id, x_block, y_block, g_block);

        // update positions for next run

        y -= 16;
        sprite_id++;
        sprite_tile_id += 2;
    }

    *base_sprite_id = sprite_id;
}

void upload_16x16_sprite(const uint32_t *tiles, uint16_t source_tile_base, uint16_t sprite_tile_base, uint16_t sprite_tile) {
    vdp_set_vram_increment(1);
    vdp_seek_vram(sprite_tile_base + sprite_tile * 0x10);

    // 16x16 arrangement
    for (int i = 0; i < 4; i++) {
        if (i == 2) {
            vdp_seek_vram(sprite_tile_base + (0x10 + sprite_tile) * 0x10);
        }

        uint8_t nextRow = i & 2;

        for (int row = 0; row < 8; row++) {
            // could reuse the new 32bit function
            // TODO: share a block copy function
            uint32_t doubleRow = tiles[((i & 1) + source_tile_base + (nextRow ? 0x10 : 0)) * 8 + row];
            vdp_write_vram(doubleRow & 0xffff);
            vdp_write_vram(doubleRow >> 16);
        }
    }
}
