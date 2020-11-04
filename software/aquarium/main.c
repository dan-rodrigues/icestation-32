// main.c: demonstrate use of sprite priorities
//
// Copyright (C) 2020 Mara "vmedea" <vmedea@protonmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>

#include "vdp.h"
#include "font.h"
#include "rand.h"

// dev-friendly way to define gfx inline
#define L(a,b,c,d,e,f,g,h) (e << 12) | (f << 8) | (g << 4) | (h << 0), (a << 12) | (b << 8) | (c << 4) | (d << 0)
#define _ 0   // transparent
#define a 10
#define b 11
#define c 12
#define d 13
#define e 14
#define f 15

static const uint16_t gfx[][16] = {
    {
        L(1,1,1,1,1,1,1,2),
        L(1,1,1,1,1,1,1,2),
        L(1,1,1,1,1,1,1,2),
        L(1,1,1,1,1,1,1,2),
        L(1,1,1,1,1,1,1,2),
        L(1,1,1,1,1,1,1,2),
        L(1,1,1,1,1,1,1,2),
        L(2,2,2,2,2,2,2,2),
    },
    {
        L(_,_,_,_,_,_,_,_),
        L(_,_,2,2,_,2,_,_),
        L(_,2,3,1,2,2,_,_),
        L(_,2,1,1,1,2,_,_),
        L(_,2,1,1,2,2,_,_),
        L(_,_,2,2,_,2,_,_),
        L(_,_,_,_,_,_,_,_),
        L(_,_,_,_,_,_,_,_),
    },
    {
        L(_,_,_,_,_,_,_,_),
        L(_,_,2,2,2,_,2,_),
        L(_,2,1,1,1,2,2,_),
        L(_,2,3,1,1,1,2,_),
        L(_,2,1,1,1,1,2,_),
        L(_,2,1,1,1,2,2,_),
        L(_,_,2,2,2,_,2,_),
        L(_,_,_,_,_,_,_,_),
    },
    {
        L(_,_,_,_,_,_,_,_),
        L(_,2,2,2,2,_,2,_),
        L(2,1,1,1,1,2,2,_),
        L(2,3,1,1,1,1,2,_),
        L(2,1,1,1,1,1,2,_),
        L(2,1,1,1,1,2,2,_),
        L(_,2,2,2,2,_,2,_),
        L(_,_,_,_,_,_,_,_),
    },
    {
        L(_,_,2,2,_,_,_,2),
        L(_,2,1,1,2,_,2,2),
        L(2,1,3,1,1,2,1,2),
        L(2,1,1,1,1,1,1,2),
        L(2,1,1,1,1,1,1,2),
        L(2,1,1,1,1,2,1,2),
        L(_,2,1,1,2,_,2,2),
        L(_,_,2,2,_,_,_,2),
    },
};
#undef _
#undef a
#undef b
#undef c
#undef d
#undef e
#undef f
#undef L

const uint16_t bg_color = 0xf001;
// bright colors
static const uint16_t fg_colors1[] = {
    0xff22, 0xff82, 0xfff2, 0x0000, // layers
    0xf33f, 0xf73f, 0xfb2f, 0xff4f, // sprites
    0xffff, 0xf88f, // info
};
// dimmed colors
static const uint16_t fg_colors2[] = {
    0xff00, 0xfe60, 0xfcc0, 0x0000, // layers
    0xf00f, 0xf60e, 0xeb0e, 0xff0f, // sprites
    0xffff, 0xf8ff, // info
};

const uint8_t LAYER_COUNT = 3;
const uint16_t TILE_VRAM_BASE = 0x0000;
const uint16_t LAYER_MAP_BASE[3] = {0x1000, 0x3000, 0x5000};
const uint16_t BASE_X = 712;
const uint16_t BASE_Y = 300;

const uint16_t NSPRITES = 40;
const uint16_t POSEXP = 3;    // fixed-point precision of sprite positions to allow for fractional speeds
const uint16_t INFO_X = 22;
const uint16_t INFO_Y = 2;
// aquarium walls
const uint16_t X_MIN = 250;
const uint16_t X_MAX = 450;
const uint16_t Y_MIN = 185;
const uint16_t Y_MAX = 325;

static void print(uint8_t palette_id, const char *string) {
    uint16_t attr = palette_id << SCROLL_MAP_PAL_SHIFT;
    while (*string) {
        vdp_write_vram((*string & 0xff) | attr);
        string++;
    }
}

int main() {
    uint8_t enabled_layers = SCROLL0 | SCROLL1 | SCROLL2 | (LAYER_COUNT == 4 ? SCROLL3 : 0) | SPRITES;

    vdp_enable_layers(enabled_layers);
    vdp_set_wide_map_layers(SCROLL0 | SCROLL1 | SCROLL2);
    vdp_set_alpha_over_layers(0);

    vdp_set_vram_increment(1);

    vdp_clear_all_sprites();
    vdp_set_sprite_tile_base(TILE_VRAM_BASE);

    for (uint8_t i = 0; i < LAYER_COUNT; i++) {
        vdp_set_layer_map_base(i, LAYER_MAP_BASE[i]);
        vdp_set_layer_tile_base(i, TILE_VRAM_BASE);
    }

    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, ' ');

    upload_font(TILE_VRAM_BASE);
    vdp_seek_vram(TILE_VRAM_BASE + 128 * 16);
    vdp_write_vram_block((const uint16_t*)gfx, sizeof(gfx));

    // palette setup
    vdp_set_single_palette_color(0, bg_color);
    for (uint8_t i = 0; i < sizeof(fg_colors1) / sizeof(fg_colors1[0]); i++) {
        vdp_set_single_palette_color(i * 0x10 + 1, fg_colors1[i]);
        vdp_set_single_palette_color(i * 0x10 + 2, fg_colors2[i]);
        vdp_set_single_palette_color(i * 0x10 + 3, 0xf000); // non-tranparent black
    }

    // aquarium decoration
    for (uint8_t i = 0; i < LAYER_COUNT; i++) {
        uint8_t palette_id = i;

        for (uint8_t y = 0; y < 9; ++y) {
            vdp_seek_vram(LAYER_MAP_BASE[i] + y * 64);
            for (uint8_t x = 0; x < 9; ++x) {
                if ((x < 2 || x > 6) || (y < 2 || y > 6))
                    vdp_write_vram(128 | (palette_id << SCROLL_MAP_PAL_SHIFT));
                else
                    vdp_write_vram(0);
            }
        }
    }

    // legend
    vdp_seek_vram(LAYER_MAP_BASE[0] + INFO_Y * 64 + INFO_X);
    print(9, "Sprite Priority");
    for (uint8_t i = 0; i < 4; ++i) {
        vdp_seek_vram(LAYER_MAP_BASE[0] + (INFO_Y + 2 + i * 2) * 64 + INFO_X + 3);
        vdp_write_vram((129 + i) | ((i + 4) << SCROLL_MAP_PAL_SHIFT));
        vdp_write_vram(' ');
        vdp_write_vram(' ');
        vdp_write_vram(' ');
        vdp_write_vram(' ');
        vdp_write_vram(' ');
        vdp_write_vram(' ');
        vdp_write_vram(('0' + i) | (8 << SCROLL_MAP_PAL_SHIFT));
    }

    // fixed layer scroll offsets
    for (uint8_t i = 0; i < LAYER_COUNT; i++) {
        vdp_set_layer_scroll(i, BASE_X - i * 7, BASE_Y - i * 7);
    }

    // initial fish positioning
    int16_t sprite_x[NSPRITES], sprite_y[NSPRITES];
    int16_t sprite_dx[NSPRITES], sprite_dy[NSPRITES];
    uint16_t sprite_g[NSPRITES];
    for (uint8_t idx = 0; idx < NSPRITES; ++idx) {
        sprite_x[idx] = (X_MIN + randbits(8)) << POSEXP;
        sprite_y[idx] = (Y_MIN + randbits(7)) << POSEXP;
        int16_t speed = (idx & 3) + 2;
        sprite_dx[idx] = (idx & 1) ? -speed : speed;
        sprite_dy[idx] = (idx & 2) ? -1 : 1;
        sprite_g[idx] = (129 + (idx & 3)) | (((idx & 3) + 4) << SPRITE_PAL_SHIFT) | ((idx & 3) << SPRITE_PRIORITY_SHIFT);
    }

    while (true) {
        vdp_seek_sprite(0);
        for (uint8_t idx = 0; idx < NSPRITES; ++idx) {
            // subtract an offset when flipped to prevent a jarring jump; even 8x8 sprites are flipped as if they are 16x16, this compensates for that
            bool xflip = sprite_dx[idx] > 0;
            uint16_t xofs = xflip ? -8 : 0;
            vdp_write_sprite_meta(
                    (((sprite_x[idx] >> POSEXP) + xofs) & 0x3ff) | (xflip ? SPRITE_X_FLIP : 0),
                    ((sprite_y[idx] >> POSEXP) & 0x1ff), sprite_g[idx]);
        }

        for (uint8_t idx = 0; idx < NSPRITES; ++idx) {
            sprite_x[idx] += sprite_dx[idx];
            sprite_y[idx] += sprite_dy[idx];
            if (sprite_x[idx] < (X_MIN << POSEXP) && sprite_dx[idx] < 0)
                sprite_dx[idx] = -sprite_dx[idx];
            if (sprite_x[idx] > (X_MAX << POSEXP) && sprite_dx[idx] > 0)
                sprite_dx[idx] = -sprite_dx[idx];
            if (sprite_y[idx] < (Y_MIN << POSEXP) && sprite_dy[idx] < 0)
                sprite_dy[idx] = -sprite_dy[idx];
            if (sprite_y[idx] > (Y_MAX << POSEXP) && sprite_dy[idx] > 0)
                sprite_dy[idx] = -sprite_dy[idx];
        }

        vdp_wait_frame_ended();
    }
}
