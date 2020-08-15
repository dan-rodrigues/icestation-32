// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp.h"
#include "math_util.h"
#include "assert.h"
#include "gamepad.h"
#include "math_util.h"

#include "copper.h"
#include "vdp_regs.h"

#include <stdint.h>
#include <stdbool.h>

#include "fg_tiles.h"
#include "fg_map.h"
#include "fg_palette.h"

#include "ball_tiles.h"
#include "ball_palette.h"

#include "sprite_tiles.h"
#include "sprite_palette.h"

#include "cloud_small_tiles.h"
#include "cloud_small_palette.h"

// VRAM layout

static const uint16_t SCROLL_TILE_BASE = 0x5000;
static const uint16_t SCROLL_MAP_BASE = 0x4000;
static const uint16_t SPRITE_TILE_BASE = 0x7000;

// Hero sprites

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

// Sprite positioning / updating

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
void draw_hero_sprites(Hero *hero, int16_t sprite_tile);
void apply_velocity(SpriteVelocity *velocity, SpritePosition *position);

// Cloud sprites

static const uint16_t CLOUD_SPRITE_TILE_BASE = 0x020;
static const uint16_t CLOUD_SPRITE_TILE_SMALL = CLOUD_SPRITE_TILE_BASE;
static const uint16_t CLOUD_SPRITE_TILE_BIG = CLOUD_SPRITE_TILE_BASE + 0x20;
static const uint8_t CLOUD_PALETTE_ID = 6;

void draw_cloud_sprites(void);
void draw_small_cloud_sprite(int16_t x, int16_t y);
void draw_big_cloud_sprite(int16_t x, int16_t y);

void write_cached_sprite_meta(uint16_t x_block, uint16_t y_block, uint16_t g_block);
void upload_cached_sprite_meta(void);
static uint16_t *sprite_meta_cache_pointer;
static uint16_t sprite_meta[256 * 3];

// Affine ball

static const int16_t AFFINE_Q_1 = 0x400;
static const int16_t BALL_ANGLE_DELTA = 4;

void update_ball(uint16_t pad);
void scale_ball(uint16_t pad);
void configure_ball_affine(void);

int32_t current_ball_speed(void);

int16_t ball_angle = 0;
int16_t ball_inverse_scale = 0x1000;
bool ball_auto_scale = true;
bool ball_auto_scaling_up = true;
int32_t ball_auto_scale_idle_counter;

int16_t affine_pretranslate_x, affine_pretranslate_y;
int16_t affine_a, affine_b, affine_c, affine_d;
int16_t affine_scroll_x, affine_scroll_y;

// Scroll context

int32_t scroll_x_acc = 0;

void write_copper_program(void);
void upload_16x16_sprite(uint16_t source_tile_base, uint16_t sprite_tile);

static const int16_t GROUND_OFFSET = 432;

int main() {
    vdp_enable_copper(false);

    // Affine layer must be disabled to write VRAM
    vdp_enable_layers(0);

    // Foregound is a 512x512 map tiled repeatedly
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    const int16_t map_y_offset = -48;
    vdp_set_layer_scroll(0, 0, map_y_offset);

    vdp_set_vram_increment(1);
    vdp_seek_vram(0);
    vdp_fill_vram(0x8000, 0x0000);

    // Odd words contain 8x8 tiles

    const uint8_t ball_palette_id = 3;

    vdp_seek_vram(0x0001);
    vdp_set_vram_increment(2);

    for (size_t i = 0; i < ball_tiles_length; i++) {
        // Graphics are 4bit color and must be padded to the 8bit format
        uint32_t row = ball_tiles[i];

        for (uint32_t x = 0; x < 4; x++) {
            uint8_t pixel_lo = (row >> 28) & 0xf;
            pixel_lo |= (pixel_lo ? ball_palette_id << 4 : 0);

            uint8_t pixel_hi = (row >> 24) & 0xf;
            pixel_hi |= (pixel_lo ? ball_palette_id << 4 : 0);

            vdp_write_vram(pixel_lo | pixel_hi << 8);
            row <<= 8;
        }
    }

    // Even words contain a 128x128 map that references the above tiles

    const uint16_t affine_map_dimension = 128;
    const uint16_t affine_ball_dimension = 16;

    for (uint16_t y = 0; y < affine_ball_dimension; y++) {
        // Address needs to be reset every line as the 128x128 bitmap occupies a portion at top left
        // The full affine map size is 1024x1024 pixels
        vdp_seek_vram(y * affine_map_dimension);

        for (uint16_t x = 0; x < affine_ball_dimension / 2; x++) {
            uint16_t map = y * affine_ball_dimension + (x * 2);
            uint16_t map_word = map | (map + 1) << 8;
            vdp_write_vram(map_word);
        }
    }

    vdp_set_vram_increment(1);

    // Affine palette

    vdp_write_palette_range(ball_palette_id * 0x10, (uint8_t)ball_palette_length, ball_palette);

    // Foreground tiles

    vdp_set_layer_tile_base(0, SCROLL_TILE_BASE);

    // Load tileset to the 3rd "page" of 128 tiles, where it is expected
    vdp_seek_vram(SCROLL_TILE_BASE + 0x1800);
    vdp_write_vram_block((uint16_t *)fg_tiles, fg_tiles_length * 2);

    // Foreground map

    vdp_set_layer_map_base(0, SCROLL_MAP_BASE);

    vdp_seek_vram(SCROLL_MAP_BASE);
    vdp_write_vram_block(fg_map, fg_map_length);

    // Foreground palette

    const uint8_t palette_size = 0x10;
    const uint8_t map_palette_id = 2;

    vdp_write_palette_range(map_palette_id * palette_size, palette_size, fg_palette);

    // Sprites

    vdp_set_sprite_tile_base(SPRITE_TILE_BASE);

    vdp_seek_palette(0);
    vdp_write_palette_range(0, palette_size, sprite_palette);

    // Cloud sprites

    vdp_seek_vram(SPRITE_TILE_BASE + CLOUD_SPRITE_TILE_BASE * 0x10);
    vdp_write_vram_block((uint16_t *)cloud_small_tiles, cloud_small_tiles_length * 2);

    // Cloud palette

    vdp_write_palette_range(CLOUD_PALETTE_ID * 0x10, cloud_small_palette_length, &cloud_small_palette[0]);

    // Background color

    const uint16_t background_color = 0xf488;
    vdp_set_single_palette_color(0, background_color);

    SpritePosition hero_position = {.x = 560, .y = GROUND_OFFSET, .x_fraction = 0, .y_fraction = 0};
    SpriteVelocity hero_velocity = {0, 0};

    Hero hero = {
        .frame = IDLE_HERO_FRAME,
        .frame_counter = 0,
        .direction = RIGHT,
        .position = hero_position,
        .velocity = hero_velocity
    };

    // Gamepad state

    uint16_t p1_pad = 0;
    uint16_t p1_pad_edge = 0;

    vdp_clear_all_sprites();

    while (true) {
        sprite_meta_cache_pointer = &sprite_meta[0];

        update_ball(p1_pad);
        update_hero_state(&hero, p1_pad, p1_pad_edge);
        scroll_x_acc += current_ball_speed();

        draw_hero_sprites(&hero, 0);
        draw_cloud_sprites();

        vdp_wait_frame_ended();
        vdp_enable_copper(false);

        upload_cached_sprite_meta();

        write_copper_program();
        vdp_enable_copper(true);

        pad_read(&p1_pad, NULL, &p1_pad_edge, NULL);
    }

    return 0;
}

void update_hero_state(Hero *hero, uint16_t pad, uint16_t pad_edge) {
    SpriteVelocity *velocity = &hero->velocity;
    SpritePosition *position = &hero->position;

    // Jumping

    const int32_t jump_initial_speed = 5 * Q_1;

    bool grounded = hero->position.y >= GROUND_OFFSET;

    if (grounded && (pad_edge & GP_B)) {
        velocity->y = -jump_initial_speed;
    }

    // Gravity

    const int32_t gravity_delta_high = Q_1 / 2;
    const int32_t gravity_delta_low = Q_1 / 6;
    const int32_t fall_velocity_max = 5 * Q_1;

    // Holding button B sustains the jump for longer

    int32_t gravity_delta = (pad & GP_B ? gravity_delta_low : gravity_delta_high);

    velocity->y += gravity_delta;
    velocity->y = MIN(velocity->y, fall_velocity_max);

    // Update hero position according to newly set velocity

    velocity->x = current_ball_speed();
    apply_velocity(velocity, position);

    // Correct position if hero has "fallen through the ground"

    if (position->y > GROUND_OFFSET) {
        velocity->y = 0;
        position->y = GROUND_OFFSET;
        position->y_fraction = 0;
    }

    // Animation

    grounded = hero->position.y >= GROUND_OFFSET;

    if (grounded) {
        // Idle state or walking

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
        // Frame for jumping or falling

        hero->frame = (SIGN(velocity->y) ? JUMP_RISING : JUMP_FALLING);
    }
}

void apply_velocity(SpriteVelocity *velocity, SpritePosition *position) {
    // X position is fixed, so only update Y position here
    int32_t y_full = position->y * Q_1 | (position->y_fraction & 0xffff);
    y_full += velocity->y;
    position->y_fraction = y_full & 0xffff;
    position->y = y_full / Q_1;
}

void draw_hero_sprites(Hero *hero, int16_t sprite_tile) {
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
    const int16_t hero_y_offset = -18;

    const SpriteFrame *sprite_frame = NULL;
    for (uint16_t i = 0; i < hero_frame_count; i++) {
        if (hero_frames[i].frame == hero->frame) {
            sprite_frame = &hero_frames[i];
            break;
        }
    }

    assert(sprite_frame);

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
        y_block += hero_y_offset;
        y_block &= 0x1ff;
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

        uint16_t g_block = sprite_tile;
        g_block |= hero_priority << SPRITE_PRIORITY_SHIFT | hero_palette << SPRITE_PAL_SHIFT;

        // upload sprite graphics (only one hero frame is in VRAM at any given time)
        upload_16x16_sprite(frame_tile, sprite_tile);

        // set sprite metadata (pointing to the graphics uploaded in previous step)
        write_cached_sprite_meta(x_block, y_block, g_block);

        sprite_y -= 16;
        sprite_tile += 2;
    }
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

void update_ball(uint16_t pad) {
    scale_ball(pad);
    configure_ball_affine();

    ball_angle += BALL_ANGLE_DELTA;
}

void configure_ball_affine() {
    const int16_t ball_dimension = 128;
    const int16_t ball_x_offset = 256;

    affine_pretranslate_x = ball_dimension / 2;
    affine_pretranslate_y = ball_dimension / 2;

    int16_t scroll = (AFFINE_Q_1 * ball_dimension) / ball_inverse_scale;

    affine_scroll_x = -ball_x_offset;
    affine_scroll_y = scroll / 2 - GROUND_OFFSET;

    int16_t sint = sys_multiply(sin(ball_angle), ball_inverse_scale) / SIN_MAX;
    int16_t cost = sys_multiply(cos(ball_angle), ball_inverse_scale) / SIN_MAX;

    affine_a = cost;
    affine_b = sint;
    affine_c = -sint;
    affine_d = cost;
}

void write_copper_program() {
    cop_ram_seek(0);

    // Top part of screen: enable affine layer
    cop_set_target_x(0);
    cop_wait_target_y(0);
    cop_write(&VDP_HSCROLL_BASE[0], affine_scroll_x);
    cop_write(&VDP_VSCROLL_BASE[0], affine_scroll_y);
    cop_write(&VDP_AFFINE_PRETRANSLATE_X, affine_pretranslate_x);
    cop_write(&VDP_AFFINE_PRETRANSLATE_Y, affine_pretranslate_y);
    cop_write(&VDP_MATRIX_A, affine_a);
    cop_write(&VDP_MATRIX_B, affine_b);
    cop_write(&VDP_MATRIX_C, affine_c);
    cop_write(&VDP_MATRIX_D, affine_d);
    cop_write(&VDP_LAYER_ENABLE, AFFINE | SCROLL0 | SPRITES);

    // Bottom half of screen: disable affine layer and enable SCROLL0 instead
    // The scroll must be set here because the same regs are used for the affine scroll
    cop_wait_target_y(GROUND_OFFSET);
    cop_write(&VDP_HSCROLL_BASE[0], scroll_x_acc / Q_1);
    cop_write(&VDP_VSCROLL_BASE[0], -48);
    cop_write(&VDP_LAYER_ENABLE, SCROLL0 | SPRITES);

    cop_jump(0);
}

int32_t current_ball_speed() {
    // 128 * pi = 402.1
    const int16_t ball_circumference = 402;

    int32_t scaled_circumference = (ball_circumference * AFFINE_Q_1) / ball_inverse_scale;
    int32_t ground_delta = ((scaled_circumference * BALL_ANGLE_DELTA) * Q_1) / SIN_PERIOD;

    return ground_delta;
}

void scale_ball(uint16_t pad) {
    const int16_t scale_delta = 8;
    const int16_t scale_min = 0x0100;
    const int16_t scale_max = 0x1000;

    const int32_t idle_counter = 60 * 3;

    if (pad & GP_LEFT && (~pad & GP_RIGHT)) {
        ball_inverse_scale = MIN(ball_inverse_scale + scale_delta, scale_max);
        ball_auto_scale = false;
    }

    if (pad & GP_RIGHT && (~pad & GP_LEFT)) {
        ball_inverse_scale = MAX(ball_inverse_scale - scale_delta, scale_min);
        ball_auto_scale = false;
    }

    if (ball_auto_scale_idle_counter) {
        ball_auto_scale_idle_counter--;
    } else if (ball_auto_scale) {
        if (ball_auto_scaling_up) {
            ball_inverse_scale -= scale_delta;
            ball_auto_scaling_up = (ball_inverse_scale > scale_min);

            if (!ball_auto_scaling_up) {
                ball_auto_scale_idle_counter = idle_counter;
            }
        } else {
            ball_inverse_scale += scale_delta;
            ball_auto_scaling_up = !(ball_inverse_scale < scale_max);

            if (ball_auto_scaling_up) {
                ball_auto_scale_idle_counter = idle_counter;
            }
        }
    }
}

void draw_cloud_sprites() {
    int16_t cloud_small_x_offset = -(scroll_x_acc / Q_1 / 2);
    int16_t cloud_big_x_offset = -(scroll_x_acc / Q_1 / 3);

    static const SpritePosition cloud_base_positions_small[] = {
        {.x = 8, .y = 32}, {.x = 280, .y = 128}, {.x = 385, .y = 48}, {.x = 530, .y = 160}
    };

    static const SpritePosition cloud_base_positions_big[] = {
        {.x = 32, .y = 80}, {.x = 430, .y = 130}, {.x = 760, .y = 192}, {.x = 870, .y = 8}
    };

    for (uint32_t i = 0; i < sizeof(cloud_base_positions_big) / sizeof(SpritePosition); i++) {
        draw_big_cloud_sprite(
            cloud_base_positions_big[i].x + cloud_big_x_offset,
            cloud_base_positions_big[i].y
        );
    }

    for (uint32_t i = 0; i < sizeof(cloud_base_positions_small) / sizeof(SpritePosition); i++) {
        draw_small_cloud_sprite(
            cloud_base_positions_small[i].x + cloud_small_x_offset,
            cloud_base_positions_small[i].y
        );
    }
}

void draw_small_cloud_sprite(int16_t x_base, int16_t y_base) {
    uint16_t x_block = x_base;
    x_block &= 0x3ff;

    uint16_t y_block = y_base;
    y_block &= 0x1ff;
    y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

    uint16_t g_block = CLOUD_SPRITE_TILE_SMALL;
    g_block |= 0 << SPRITE_PRIORITY_SHIFT | CLOUD_PALETTE_ID << SPRITE_PAL_SHIFT;

    write_cached_sprite_meta(x_block, y_block, g_block);
    write_cached_sprite_meta((x_block + 16) & 0x3ff, y_block, g_block + 2);
    write_cached_sprite_meta((x_block + 32) & 0x3ff, y_block, g_block + 4);
    write_cached_sprite_meta((x_block + 48) & 0x3ff, y_block, g_block + 6);
}

void draw_big_cloud_sprite(int16_t x_base, int16_t y_base) {
    for (uint8_t y = 0; y < 3; y++) {
        for (uint8_t x = 0; x < 7; x++) {
            uint16_t x_block = x_base + x * 16;
            x_block &= 0x3ff;

            uint16_t y_block = y_base + y * 16;
            y_block &= 0x1ff;
            y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

            uint16_t g_block = (CLOUD_SPRITE_TILE_BIG + y * 0x20 + x * 2);
            g_block |= 0 << SPRITE_PRIORITY_SHIFT | CLOUD_PALETTE_ID << SPRITE_PAL_SHIFT;

            write_cached_sprite_meta(x_block, y_block, g_block);
        }
    }
}

void write_cached_sprite_meta(uint16_t x_block, uint16_t y_block, uint16_t g_block) {
    *sprite_meta_cache_pointer++ = x_block;
    *sprite_meta_cache_pointer++ = y_block;
    *sprite_meta_cache_pointer++ = g_block;
}

void upload_cached_sprite_meta() {
    vdp_seek_sprite(0);

    for (uint16_t *pointer = &sprite_meta[0]; pointer < sprite_meta_cache_pointer; pointer += 3) {
        vdp_write_sprite_meta(pointer[0], pointer[1], pointer[2]);
    }
}
