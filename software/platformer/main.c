// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp.h"
#include "math_util.h"
#include "assert.h"

#include <stdint.h>
#include <stdbool.h>

#include "fg_tiles.h"
#include "fg_palette.h"

#include "sprite_tiles.h"
#include "sprite_palette.h"

// TODO rename and convert from bin
#include "map-flat.h"

// vram layout constants

static const uint16_t SPRITE_TILE_BASE = 0x6000;

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

static const uint8_t HERO_FRAME_MAX_TILES = 2;
static const int16_t HERO_FRAME_TILES_END = -1;

typedef struct {
    HeroFrame frame;

    int16_t x_offset;
    int16_t y_offset;

    uint8_t x_flip;

    const int16_t tiles[2]; // tiles[HERO_FRAME_MAX_TILES]
} SpriteFrame;

static const SpriteFrame hero_frames[] = {
    {RUN0, 0, -1, 0, {0x000, 0x0e0}},
    {RUN1, 0, 0, 0, {0x002, 0x0e0}},
    {RUN2, 0, 0, 0, {0x004, 0x0e0}},

    {JUMP_RISING, 0, 0, 0, {0x006, 0x0e8}},
    {JUMP_FALLING, 0, 0, 0, {0x1a4, 0x18e}},

    {LOOKING_UP, 0, 0, 0, {0x004, 0x140}},

    {LOOKING_SCREEN_DIRECT, 0, 0, 0, {0x00e, 0x108}},
    {LOOKING_SCREEN_LEFT, 0, 0, 0, {0x00e, 0x0e0}},
    {LOOKING_SCREEN_RIGHT, 0, 0, 1, {0x00e, 0x0e0}},

    {PEACE_SIGN, 0, 0, 0, {0x16e, 0x166}},
};

static const size_t hero_frame_count = sizeof(hero_frames) / sizeof(SpriteFrame);

void draw_hero_sprites(uint8_t *base_sprite_id, HeroFrame frame, int16_t x, int16_t y, int16_t sprite_tile_id);
void upload_16x16_sprite(uint16_t source_tile_base, uint16_t sprite_tile);


int main() {
    vdp_enable_layers(SCROLL0 | SPRITES);

    // the foregound is a 512x512 map tiled repeatedly
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    vdp_set_layer_scroll(0, 0, -48);

    // clear for fpga but disable for sim, this is pretty slow
    vdp_set_vram_increment(1);
    vdp_seek_vram(0);
    vdp_fill_vram(0x8000, 0x0000);

    const uint16_t tile_vram_base = 0x0000;

    // foreground tiles
    // the map expects them on the latter pages so
    const uint16_t foreground_tile_count = 128;

    vdp_set_layer_tile_base(0, tile_vram_base);

    vdp_set_vram_increment(1);
    // this loads it to the 3rd "page" of 128 tiles, where it is expected
    vdp_seek_vram(0 + 0x1800);
    vdp_write_vram_block((uint16_t *)fg_tiles, foreground_tile_count * 32 / 2);

    // foreground map

    const uint16_t map_vram_base = 0x4000;

    vdp_set_layer_map_base(0, map_vram_base);

    vdp_set_vram_increment(2);
    vdp_seek_vram(map_vram_base);
    vdp_write_vram_block((uint16_t *)mapFlat, 0x2000 / 2);

    vdp_set_vram_increment(1);

    // foreground palette

    // the original map expeccts palette_id = 2
    vdp_write_palette_range(2 * 0x10, 0x10, fg_palette);

    // sprites (GFX is uploaded frame-by-frame)

    vdp_set_sprite_tile_base(SPRITE_TILE_BASE);

    vdp_seek_palette(0);
    vdp_write_palette_range(0, 0x10, sprite_palette);

    uint8_t base_sprite_id = 0;

    vdp_clear_all_sprites();

    // background color

    vdp_set_single_palette_color(0, 0xf088);

    uint8_t frame_counter = 0;

    // relocate to animatio specific function
    HeroFrame hero_frame = RUN0;
    uint16_t hero_x = 400;
    uint8_t hero_frame_counter = 0;

    while (1) {
        // quick and dirty walk animation
        // needs to be made speed aware
        hero_x--;

        // walk counter update
        if (hero_frame_counter == 0) {
            const uint8_t hero_default_frame_duration = 5;
            hero_frame_counter = hero_default_frame_duration;

            hero_frame = (hero_frame == RUN2 ? RUN0 : hero_frame + 1);
        }

        hero_frame_counter--;

        // draw hero

        const int16_t ground_offset = 415;
        draw_hero_sprites(&base_sprite_id, hero_frame, hero_x, ground_offset, 0);

        vdp_wait_frame_ended();

        frame_counter++;
        base_sprite_id = 0;
    }

    return 0;
}

void draw_hero_sprites(uint8_t *base_sprite_id, HeroFrame frame, int16_t x, int16_t y, int16_t sprite_tile) {
    const uint8_t hero_palette = 0;
    const uint8_t hero_priority = 3;

    const SpriteFrame *sprite_frame = NULL;
    for (uint16_t i = 0; i < hero_frame_count; i++) {
        if (hero_frames[i].frame == frame) {
            sprite_frame = &hero_frames[i];
            break;
        }
    }

    assert(sprite_frame != NULL);

    uint8_t sprite_id = *base_sprite_id;

    for (uint8_t i = 0; i < HERO_FRAME_MAX_TILES; i++) {
        int16_t frame_tile = sprite_frame->tiles[i];
        if (frame_tile == HERO_FRAME_TILES_END) {
            break;
        }

        // sprite meta

        uint16_t x_block = x + sprite_frame->x_offset;
        x_block &= 0x3ff;
        x_block |= (sprite_frame->x_flip ? SPRITE_X_FLIP : 0);

        uint16_t y_block = y + sprite_frame->y_offset;
        y_block &= 0x1ff;
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

        uint16_t g_block = sprite_tile;
        g_block |= hero_priority << SPRITE_PRIORITY_SHIFT | hero_palette << SPRITE_PAL_SHIFT;

        // upload and set graphics

        upload_16x16_sprite(frame_tile, sprite_tile);

        vdp_write_single_sprite_meta(sprite_id, x_block, y_block, g_block);

        // update positions for next run

        y -= 16;
        sprite_id++;
        sprite_tile += 2;
    }

    *base_sprite_id = sprite_id;
}

void upload_16x16_sprite(uint16_t source_tile_base, uint16_t sprite_tile) {
    vdp_seek_vram(SPRITE_TILE_BASE + sprite_tile * 0x10);

    uint16_t *source_tiles = (uint16_t *)(sprite_tiles + source_tile_base * 8);
    const uint16_t frame_row_word_size = 0x10 * 2;

    // first row (upper 16x8 half)
    vdp_write_vram_block(source_tiles, frame_row_word_size);

    // second row (lower 16x8 half)
    const uint16_t sprite_row_word_stride = 0x20 * 0x10 / 2;
    vdp_seek_vram(SPRITE_TILE_BASE + (0x10 + sprite_tile) * 0x10);
    vdp_write_vram_block(source_tiles + sprite_row_word_stride, frame_row_word_size);
}
