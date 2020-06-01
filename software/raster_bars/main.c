#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"

static const uint16_t SCREEN_HEIGHT = 480;

typedef struct {
    int16_t x;
    int16_t y;
} Vertex;

static void draw_layer_mask();
static void draw_raster_bars(uint16_t line_offset);
static void draw_triangle(uint16_t angle);

int main() {
    vdp_enable_copper(false);

    // TODO: opaque layer for masking
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    // opaque tile for foreground
    vdp_set_layer_tile_base(0, 0x0000);
    vdp_set_vram_increment(1);
    vdp_seek_vram(0);
    vdp_fill_vram(0x20 / 2, 0x1111);

    // set all map tiles to use opaque tile
    vdp_set_layer_map_base(0, 0x1000);
    vdp_set_vram_increment(2);
    vdp_seek_vram(0x1000);
    // tile 00 for entire map
    vdp_fill_vram(0x1000, 0x0000);

    // palette for opaque color
    vdp_set_single_palette_color(1, 0xf088);

    uint16_t line_offset = 0;
    uint16_t angle = 0;

//    draw_layer_mask();

    vdp_wait_frame_ended();
    
    while (true) {
//        vdp_enable_layers(0);
//        draw_raster_bars(line_offset);
//        draw_layer_mask();
        draw_triangle(angle);

        vdp_enable_copper(true);

        vdp_wait_frame_ended();

        line_offset++;
        angle++;
    }

    return 0;
}

static void draw_triangle(uint16_t angle) {
    Vertex vertices[3];

    for (uint8_t i = 0; i < 3; i++) {
        const int16_t screen_center_x = 848 / 2 + 240;
        const int16_t screen_center_y = 480 / 2;
        const int16_t radius = 48;

        uint16_t angle_offset = i * SIN_PERIOD / 3;
        int16_t sin_t = sin(angle + angle_offset);
        int16_t cos_t = cos(angle + angle_offset);

        int16_t sprite_x = sys_multiply(cos_t, -radius) / SIN_MAX;
        int16_t sprite_y = sys_multiply(sin_t, -radius) / SIN_MAX;

        sprite_x += screen_center_x;
        sprite_y += screen_center_y;

        vertices[i].x = sprite_x;
        vertices[i].y = sprite_y;
    }

    draw_layer_mask(vertices);
}

static void draw_triangle_edge(int32_t *x1, int32_t *x2, uint16_t y_base, uint16_t y_end, int32_t dx_1, int32_t dx_2) {
    int32_t x1_long = *x1;
    int32_t x2_long = *x2;

    for (uint16_t y = y_base; y < y_end; y++) {
        int16_t e1 = x1_long / 0x10000;
        int16_t e2 = x2_long / 0x10000;

        // delta update for next line
        x1_long += dx_1;
        x2_long += dx_2;

        int16_t left = MIN(e1, e2);
        int16_t right = MAX(e1, e2);

        if (left >= right) {
            continue;
        }

        // edge left side
        cop_wait_target_x(left);
        cop_write_compressed(&VDP_LAYER_ENABLE, SCROLL0, false);

        if ((right - left) > 2) {
            // ...wait to reach the ride side of the edge...
            cop_wait_target_x(right);
        }

        // edge right side
        cop_write_compressed(&VDP_LAYER_ENABLE, 0, true);
    }

    *x1 = x1_long;
    *x2 = x2_long;
}

static void sort_vertex_pair(Vertex *v1, Vertex *v2) {
    if (v2->y < v1->y) {
        Vertex t = *v1;
        *v1 = *v2;
        *v2 = t;
    }
}

static void sort_vertices(Vertex *vertices) {
    sort_vertex_pair(&vertices[0], &vertices[1]);
    sort_vertex_pair(&vertices[1], &vertices[2]);
    sort_vertex_pair(&vertices[0], &vertices[1]);
}

// triangle mask
static void draw_layer_mask(Vertex *vertices) {
    cop_ram_seek(0);

    sort_vertices(vertices);

    Vertex top = vertices[0];
    Vertex mid = vertices[1];
    Vertex bottom = vertices[2];

    // top to mid

    int16_t dx = mid.x - top.x;
    int16_t dy = mid.y - top.y;

    int16_t dx_m = bottom.x - top.x;
    int16_t dy_m = bottom.y - top.y;

    // top segment
    cop_set_target_y(top.y);

    // actually want dx/dy since the y increments per line but x changes variably
    int32_t delta_x = (ABS(dx) * 0x10000) / ABS(dy);
    int32_t delta_x_m = (ABS(dx_m) * 0x10000) / ABS(dy_m);

    if (dx < 0) {
        delta_x = -delta_x;
    }

    if (dx_m < 0) {
        delta_x_m = -delta_x_m;
    }

    int32_t x1_long = top.x << 16;
    int32_t x2_long = x1_long;

    draw_triangle_edge(&x1_long, &x2_long, top.y, mid.y, delta_x, delta_x_m);

    dx = bottom.x - mid.x;
    dy = bottom.y - mid.y;

    bool bottom_segment_visible = (dy != 0);
    if (bottom_segment_visible) {
        delta_x = (ABS(dx) * 0x10000) / ABS(dy);

        if (dx < 0) {
            delta_x = -delta_x;
        }

        // bottom segment
        draw_triangle_edge(&x1_long, &x2_long, mid.y, bottom.y, delta_x, delta_x_m);
    }

    cop_write(&VDP_LAYER_ENABLE, 0);

    cop_jump(0);
    // FIXME: the op immediately after this one is run because it's already fetched
    // can either accept this as a "branch delay slot" or build in a wait state
    cop_set_target_x(0);
}

static void draw_raster_bars(uint16_t line_offset) {
    static const uint16_t color_masks[] = {
        0xff00, 0xf0f0, 0xf00f, 0xffff, 0xfff0, 0xf0ff, 0xff0f, 0xffff
    };
    const size_t color_mask_count = sizeof(color_masks) / sizeof(uint16_t);
    const uint8_t bar_height = 32;

    COPBatchWriteConfig config = {
        .mode = CWM_DOUBLE,
        .reg = &VDP_PALETTE_ADDRESS
    };

    cop_ram_seek(0);

    cop_set_target_x(0);
    cop_wait_target_y(0);

    uint16_t line = 0;
    while (line < SCREEN_HEIGHT) {
        uint16_t selected_line = line + line_offset;
        uint16_t bar_offset = selected_line % bar_height;
        uint16_t visible_bar_height = bar_height - bar_offset;
        // clip if the bar "runs over the bottom of the screen"
        visible_bar_height = MIN(SCREEN_HEIGHT - line, visible_bar_height);

        // at some point these will have to be broken up
        // since the horizontal updates have to be woven into this table too
        config.batch_count = visible_bar_height - 1;
        config.batch_wait_between_lines = true;
        cop_start_batch_write(&config);

        uint8_t mask_selected = (selected_line / bar_height) % color_mask_count;
        uint16_t color_mask = color_masks[mask_selected];

        for (uint8_t bar_y = 0; bar_y < visible_bar_height; bar_y++) {
            uint16_t color = 0;
            uint8_t bar_y_offset = bar_y + bar_offset;
            uint8_t y = bar_y_offset % (bar_height / 2);

            if (bar_y_offset < (bar_height / 2)) {
                color = 0xf000 | y << 8 | y << 4 | y;
                color &= color_mask;
            } else {
                color = 0xffff - (y << 8) - (y << 4) - y;
                color &= color_mask;
            }

            cop_add_batch_double(&config, 0, color);
        }

        line += visible_bar_height;

        // must wait 1 line or else it'll immediately start processing the *next* line
        if (line < SCREEN_HEIGHT) {
            cop_wait_target_y(line);
        }
    }

    cop_jump(0);
}
