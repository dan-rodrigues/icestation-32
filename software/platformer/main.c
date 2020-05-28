// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp.h"
#include "math_util.h"
#include "assert.h"
#include "gamepad.h"

#include <stdint.h>
#include <stdbool.h>

#include "fg_tiles.h"
#include "fg_map.h"
#include "fg_palette.h"

#include "sprite_tiles.h"
#include "sprite_palette.h"

// vram layout constants

static const uint16_t SCROLL_TILE_BASE = 0x0000;
static const uint16_t SCROLL_MAP_BASE = 0x4000;
static const uint16_t SPRITE_TILE_BASE = 0x6000;

// sprite graphics

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

static const HeroFrame IDLE_HERO_FRAME = RUN2;

static const uint8_t HERO_FRAME_MAX_TILES = 2;
static const int16_t HERO_FRAME_TILES_END = -1;

typedef struct {
    HeroFrame frame;

    int16_t x_offset;
    int16_t y_offset;

    uint8_t x_flip;

    // const int16_t tiles[HERO_FRAME_MAX_TILES]
    const int16_t tiles[2];
} SpriteFrame;

// sprite positioning / updating

static const int32_t Q_1 = 0x10000;

typedef enum {
    LEFT, RIGHT
} SpriteDirection;

typedef struct {
    int16_t x, y;
    int16_t x_fraction, y_fraction;
} SpritePosition;

typedef struct {
    int32_t x, y;
} SpriteVelocity;

typedef struct {
    HeroFrame frame;
    uint32_t frame_counter;

    SpritePosition position;
    SpriteVelocity velocity;
    SpriteDirection direction;
} Hero;

void update_hero_state(Hero *hero, uint16_t pad, uint16_t pad_edge);
void apply_velocity(SpriteVelocity *velocity, SpritePosition *position);

void draw_hero_sprites(uint8_t *base_sprite_id, Hero *hero, int16_t sprite_tile);
void upload_16x16_sprite(uint16_t source_tile_base, uint16_t sprite_tile);

static const int16_t GROUND_OFFSET = 415;

int main() {
    vdp_enable_layers(SCROLL0 | SPRITES);

    // the foregound is a 512x512 map tiled repeatedly
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);
    vdp_set_vram_increment(1);

    const int16_t map_y_offset = -48;
    vdp_set_layer_scroll(0, 0, map_y_offset);

    vdp_seek_vram(0);
    vdp_fill_vram(0x8000, 0x0000);

    // foreground tiles

    vdp_set_layer_tile_base(0, SCROLL_TILE_BASE);

    vdp_set_vram_increment(1);
    // this loads tileset to the 3rd "page" of 128 tiles, where it is expected
    vdp_seek_vram(0 + 0x1800);
    vdp_write_vram_block((uint16_t *)fg_tiles, fg_tiles_length * 2);

    // foreground map

    vdp_set_layer_map_base(0, SCROLL_MAP_BASE);

    vdp_set_vram_increment(2);
    vdp_seek_vram(SCROLL_MAP_BASE);
    vdp_write_vram_block(fg_map, fg_map_length);
    vdp_set_vram_increment(1);

    // foreground palette

    const uint8_t palette_size = 0x10;

    const uint8_t map_palette_id = 2;
    vdp_write_palette_range(map_palette_id * palette_size, palette_size, fg_palette);

    // sprites

    vdp_set_sprite_tile_base(SPRITE_TILE_BASE);

    vdp_seek_palette(0);
    vdp_write_palette_range(0, palette_size, sprite_palette);

    // background color

    const uint16_t background_color = 0xf488;
    vdp_set_single_palette_color(0, background_color);

    SpritePosition hero_position = {.x = 400, .y = GROUND_OFFSET, .x_fraction = 0, .y_fraction = 0};
    SpriteVelocity hero_velocity = {0, 0};

    Hero hero = {
        .frame = IDLE_HERO_FRAME,
        .frame_counter = 0,
        .direction = RIGHT,
        .position = hero_position,
        .velocity = hero_velocity
    };

    // init gamepad state

    uint16_t p1_pad = 0;
    uint16_t p1_pad_edge = 0;

    // init sprites context before entering game loop

    uint8_t base_sprite_id = 0;
    vdp_clear_all_sprites();

    while (true) {
        update_hero_state(&hero, p1_pad, p1_pad_edge);
        draw_hero_sprites(&base_sprite_id, &hero, 0);

        vdp_wait_frame_ended();

        pad_read(&p1_pad, NULL, &p1_pad_edge, NULL);

        base_sprite_id = 0;
    }

    return 0;
}

void update_hero_state(Hero *hero, uint16_t pad, uint16_t pad_edge) {
    // walking left/right

    const int32_t walk_max_speed = 2 * Q_1;
    const int32_t walk_correction_delta = Q_1 / 2;
    const int32_t walk_idle_delta = Q_1 / 8;

    SpriteVelocity *velocity = &hero->velocity;
    SpritePosition *position = &hero->position;

    if (pad & GP_LEFT && (~pad & GP_RIGHT)) {
        velocity->x += !SIGN(velocity->x) ? -walk_correction_delta : -walk_idle_delta;
        velocity->x = MAX(-walk_max_speed, velocity->x);

        if (SIGN(velocity->x)) {
            hero->direction = LEFT;
        }
    } else if (pad & GP_RIGHT && (~pad & GP_LEFT)) {
        velocity->x += (SIGN(velocity->x) && velocity->x) ? walk_correction_delta : walk_idle_delta;
        velocity->x = MIN(walk_max_speed, velocity->x);

        if (!SIGN(velocity->x)) {
            hero->direction = RIGHT;
        }
    } else {
        int32_t abs_velocity = ABS(velocity->x);
        abs_velocity -= walk_idle_delta;
        abs_velocity = (SIGN(abs_velocity) ? 0 : abs_velocity);
        velocity->x = (SIGN(velocity->x) ? -abs_velocity : abs_velocity);
    }

    // jumping

    const int32_t jump_initial_speed = 5 * Q_1;

    bool grounded = hero->position.y >= GROUND_OFFSET;

    if (grounded && (pad_edge & GP_B)) {
        velocity->y = -jump_initial_speed;
    }

    // gravity

    const int32_t gravity_delta_high = Q_1 / 2;
    const int32_t gravity_delta_low = Q_1 / 6;
    const int32_t fall_velocity_max = 5 * Q_1;

    // holding button B sustains the jump for longer

    int32_t gravity_delta = (pad & GP_B ? gravity_delta_low : gravity_delta_high);

    velocity->y += gravity_delta;
    velocity->y = MIN(velocity->y, fall_velocity_max);

    // update hero position according to newly set velocity

    apply_velocity(velocity, position);

    // correct position if hero has "fallen through the ground"

    if (position->y > GROUND_OFFSET) {
        velocity->y = 0;
        position->y = GROUND_OFFSET;
        position->y_fraction = 0;
    }

    // animation

    grounded = hero->position.y >= GROUND_OFFSET;

    if (grounded) {
        // frame for idle state or walking

        switch (hero->frame) {
            case RUN0: case RUN1: case RUN2:
                break;
            default:
                hero->frame = IDLE_HERO_FRAME;
                break;
        }

        int32_t frame_counter = hero->frame_counter;

        if (frame_counter < 0) {
            const int32_t hero_default_frame_duration = 5 * Q_1;
            frame_counter = hero_default_frame_duration;
            hero->frame = (hero->frame == RUN2 ? RUN0 : hero->frame + 1);
        } else if (hero->velocity.x != 0) {
            int32_t frame_counter_delta = ABS(hero->velocity.x);
            frame_counter -= frame_counter_delta;
        } else {
            hero->frame = IDLE_HERO_FRAME;
        }

        hero->frame_counter = frame_counter;
    } else {
        // frame for jumping or falling

        hero->frame = (SIGN(velocity->y) ? JUMP_RISING : JUMP_FALLING);
    }
}

void apply_velocity(SpriteVelocity *velocity, SpritePosition *position) {
    int32_t x_full = position->x * Q_1 | (position->x_fraction & 0xffff);
    x_full += velocity->x;
    position->x_fraction = x_full & 0xffff;
    position->x = x_full / Q_1;

    int32_t y_full = position->y * Q_1 | (position->y_fraction & 0xffff);
    y_full += velocity->y;
    position->y_fraction = y_full & 0xffff;
    position->y = y_full / Q_1;
}

void draw_hero_sprites(uint8_t *base_sprite_id, Hero *hero, int16_t sprite_tile) {
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

    const uint8_t hero_palette = 0;
    const uint8_t hero_priority = 3;

    const SpriteFrame *sprite_frame = NULL;
    for (uint16_t i = 0; i < hero_frame_count; i++) {
        if (hero_frames[i].frame == hero->frame) {
            sprite_frame = &hero_frames[i];
            break;
        }
    }

    assert(sprite_frame);

    uint8_t sprite_id = *base_sprite_id;
    int16_t sprite_y = hero->position.y;

    for (uint8_t i = 0; i < HERO_FRAME_MAX_TILES; i++) {
        int16_t frame_tile = sprite_frame->tiles[i];
        if (frame_tile == HERO_FRAME_TILES_END) {
            break;
        }

        // sprite metadata

        uint16_t x_block = hero->position.x + sprite_frame->x_offset;
        x_block &= 0x3ff;
        bool hero_needs_flip = (hero->direction == RIGHT);
        bool frame_needs_flip = sprite_frame->x_flip;
        x_block |= (hero_needs_flip ^ frame_needs_flip ? SPRITE_X_FLIP : 0);

        uint16_t y_block = sprite_y + sprite_frame->y_offset;
        y_block &= 0x1ff;
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

        uint16_t g_block = sprite_tile;
        g_block |= hero_priority << SPRITE_PRIORITY_SHIFT | hero_palette << SPRITE_PAL_SHIFT;

        // upload sprite graphis
        upload_16x16_sprite(frame_tile, sprite_tile);

        // set sprite metadata (pointing to the graphics uploaded in previous step)
        vdp_write_single_sprite_meta(sprite_id, x_block, y_block, g_block);

        sprite_y -= 16;
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
