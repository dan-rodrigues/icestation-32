#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"

static const int32_t EDGE_Q_1 = 0x10000;

static const int16_t SCALE_Q_1 = 0x0100;

typedef struct {
    int16_t x;
    int16_t y;
} Vertex;

static void draw_transformed_triangle(Vertex *vertices);
static void draw_triangle(uint16_t angle, int16_t scale);

int main() {
    vdp_enable_copper(false);

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
    uint16_t angle = SIN_PERIOD / 4;

    int16_t scale = 0x200; // 0x100;
    
    while (true) {
        draw_triangle(angle, scale);

        // this wait must happen before enabling the copper
        // there is risk of contention with register writes otherwise
        vdp_wait_frame_ended();
        vdp_enable_copper(true);

        line_offset++;
        angle++;

        if (angle % 8 == 0) {
            scale += 1;
            scale &= 0x3ff;
        }

    }

    return 0;
}

static void draw_triangle(uint16_t angle, int16_t scale) {
    const int16_t screen_center_x = 848 / 2 + 240;
    const int16_t screen_center_y = 480 / 2;
    const int16_t radius = 240 - 1;

    Vertex vertices[3];

    for (uint8_t i = 0; i < 3; i++) {
        uint16_t angle_offset = i * SIN_PERIOD / 3;
        int16_t sin_t = sin(angle + angle_offset);
        int16_t cos_t = cos(angle + angle_offset);

        int16_t vertex_x = sys_multiply(cos_t, -radius) / SIN_MAX;
        int16_t vertex_y = sys_multiply(sin_t, -radius) / SIN_MAX;

        vertex_x = sys_multiply(vertex_x, scale) / SCALE_Q_1;
        vertex_y = sys_multiply(vertex_y, scale) / SCALE_Q_1;

        vertex_x += screen_center_x;
        vertex_y += screen_center_y;

        vertices[i].x = vertex_x;
        vertices[i].y = vertex_y;
    }

    draw_transformed_triangle(vertices);
}

static void draw_triangle_edge(int32_t *x1, int32_t *x2, int16_t y_base, int16_t y_end, int32_t x1_delta, int32_t x2_delta) {
    bool needs_swap;

    if (*x1 == *x2) {
        needs_swap = x1_delta > x2_delta;
    } else {
        needs_swap = *x1 > *x2;
    }

    int32_t left, right;
    int32_t delta_left, delta_right;

    if (!needs_swap) {
        left = *x1;
        right = *x2;
        delta_left = x1_delta;
        delta_right = x2_delta;
    } else {
        left = *x2;
        right = *x1;
        delta_left = x2_delta;
        delta_right = x1_delta;
    }

    for (int16_t y = y_base; y < y_end && y < 480; y++) {
        left += delta_left;
        right += delta_right;

        if (y < 0) {
            // this row is off the top of the screen
            continue;
        }

        int16_t edge_left = left / EDGE_Q_1;
        int16_t edge_right = right / EDGE_Q_1;

        const int16_t screen_max_x = 848 + 240 - 8;

        // edge left side...
        if (edge_left < 0) {
            cop_wait_target_x(0);
        } else {
            cop_wait_target_x(edge_left);
        }

        cop_write_compressed(&VDP_LAYER_ENABLE, SCROLL0, false);

        if ((edge_right - edge_left) > 2) {
            if (edge_right > screen_max_x) {
                cop_wait_target_x(screen_max_x);
            } else {
                // ...wait to reach the ride side of the edge...
                cop_wait_target_x(edge_right);
            }
        } else if ((edge_right - edge_left) > 1) {
            cop_write_compressed(&VDP_LAYER_ENABLE, SCROLL0, false);
        }

        // ...edge right side
        cop_write_compressed(&VDP_LAYER_ENABLE, 0, true);
    }

    *x1 = needs_swap ? right : left;
    *x2 = needs_swap ? left : right;
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

static void draw_transformed_triangle(Vertex *vertices) {
    cop_ram_seek(0);

    // this "pauses" the copper until the active frame actually starts at raster_y=0
    cop_wait_target_y(0);

    sort_vertices(vertices);

    Vertex top = vertices[0];
    Vertex mid = vertices[1];
    Vertex bottom = vertices[2];

    // top segment

    int16_t dx1 = mid.x - top.x;
    int16_t dy1 = mid.y - top.y;

    int16_t dx2 = bottom.x - top.x;
    int16_t dy2 = bottom.y - top.y;

    if (dy2 == 0) {
        // this is a zero height triangle so nothing to do
        return;
    }

    if (top.y > 0) {
        cop_set_target_y(top.y);
    }

    // note it's dx/dy rather than dy/dx
    // the triangle edges are drawn by stepping through each vertical line, then doing x += (dx/dy)

    int32_t x1_delta;
    int32_t x2_delta = (ABS(dx2) * EDGE_Q_1) / ABS(dy2);

    if (dx2 < 0) {
        x2_delta = -x2_delta;
    }

    int32_t x1_long = top.x * EDGE_Q_1;
    int32_t x2_long = x1_long;

    bool top_segment_visible = (dy1 != 0);
    if (top_segment_visible) {
        x1_delta = (ABS(dx1) * EDGE_Q_1) / ABS(dy1);

        if (dx1 < 0) {
            x1_delta = -x1_delta;
        }

        draw_triangle_edge(&x1_long, &x2_long, top.y, mid.y, x1_delta, x2_delta);
    }

    // bottom segment

    dx1 = bottom.x - mid.x;
    dy1 = bottom.y - mid.y;

    if (!top_segment_visible) {
        x1_long = mid.x * EDGE_Q_1;
        x2_long = top.x * EDGE_Q_1;
    }

    bool bottom_segment_visible = (dy1 != 0);
    if (bottom_segment_visible) {
        x1_delta = (ABS(dx1) * EDGE_Q_1) / ABS(dy1);

        if (dx1 < 0) {
            x1_delta = -x1_delta;
        }

        draw_triangle_edge(&x1_long, &x2_long, mid.y, bottom.y, x1_delta, x2_delta);
    }

    cop_write(&VDP_LAYER_ENABLE, 0);

    cop_jump(0);
    // branch delay slot, which could be eliminated by spending more LCs in the copper
    cop_set_target_x(0);
}
