#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"
#include "font.h"
#include "vdp_print.h"

static const int32_t EDGE_Q_1 = 0x10000;
static const int16_t SCALE_Q_1 = 0x0100;

typedef struct {
    int16_t x;
    int16_t y;
} Vertex;

typedef enum {
    ST_IDLE,
    ST_ZOOM_IN,
    ST_HOLD,
    ST_ZOOM_OUT
} State;

static void draw_transformed_triangle(Vertex *vertices);
static void draw_triangle(uint16_t angle, int16_t scale);

static VDPLayer POLYGON_VISIBLE_LAYERS = SCROLL0 | SCROLL1;
static VDPLayer POLYGON_HIDDEN_LAYERS = SCROLL1;

static const uint16_t TILE_BASE = 0x0000;
static const uint16_t MAP_BASE = 0x1000;

// current state context

static State state;

static int16_t angle;
static int16_t scale;
static uint8_t alpha;
static uint16_t state_counter;

static void enter_state(State new_state) {
    switch (new_state) {
        case ST_IDLE:
            angle = 0; //  SIN_PERIOD / 2;
            scale = 0x300; //2;
            alpha = 0xf; //0;
            break;
        case ST_ZOOM_IN:
            break;
        case ST_HOLD:
            break;
        case ST_ZOOM_OUT:
            break;
    }

    state_counter = 0;
    state = new_state;
}

static void update_current_state() {
    switch (state) {
        case ST_IDLE: {
            const uint16_t idle_frames = 180;

            if (state_counter > idle_frames) {
                enter_state(ST_ZOOM_IN);
            }

        } break;
        case ST_ZOOM_IN: {
            const int16_t target_scale = 0x3f0;

            if (scale > 0x20 && alpha != 0xf && state_counter % 4 == 0) {
                alpha++;
            }

            if (scale >= target_scale) {
                enter_state(ST_HOLD);
            }

            scale += 2;
        } break;
        case ST_HOLD: {
            if (state_counter > 60) {
                enter_state(ST_ZOOM_OUT);
            }
        } break;
        case ST_ZOOM_OUT: {
            if (scale < 0x100 && alpha != 0 && state_counter % 4 == 0) {
                alpha--;
            }

            if (scale > 0) {
                scale -= 2;
            } else {
                enter_state(ST_IDLE);
            }
        } break;
    }

    state_counter++;
    angle++;
}

int main() {
    vdp_enable_copper(false);
    vdp_enable_layers(POLYGON_HIDDEN_LAYERS);

    // must be called before the printf() variants are used
    vp_print_init();

    // tiles (8x8 font, common to both layers)
    vdp_set_layer_tile_base(0, TILE_BASE);
    vdp_set_layer_tile_base(1, TILE_BASE);

    const uint8_t background_index = 1;
    const uint8_t foreground_index = 2;
    upload_font_remapped(TILE_BASE, background_index, foreground_index);

    // the polygon layer (showing the text) is a full wdith 1024x512 layer
    // the scrolling background layer is a tiled 512x512 layer
    vdp_set_wide_map_layers(SCROLL0);
    // this layer is also alpha blending onto the checkboard background
    vdp_set_alpha_over_layers(SCROLL0);

    // checkerboard background

    vdp_set_layer_map_base(1, MAP_BASE);
    vdp_seek_vram(MAP_BASE + 1);
    vdp_set_vram_increment(2);

    const uint8_t checkerboard_dimension = 4;
    const uint16_t opaque_tile = ' ';

    for (uint8_t y = 0; y < 64; y++) {
        uint8_t y_even = (y / checkerboard_dimension) & 1;

        for (uint8_t x = 0; x < 64; x++) {
            const uint8_t light_palette = 1;
            const uint8_t dark_palette = 2;

            uint8_t x_even = (x / checkerboard_dimension) & 1;
            bool is_dark = y_even ^ x_even;

            uint8_t palette = is_dark ? dark_palette : light_palette;
            uint16_t map_word = opaque_tile | palette << SCROLL_MAP_PAL_SHIFT;
            vdp_write_vram(map_word);
        }
    }

    // initialise all map tiles to the empty opaque tile (space character)

    vdp_set_layer_map_base(0, MAP_BASE);
    vdp_set_vram_increment(2);
    vdp_seek_vram(MAP_BASE + 0);
    vdp_fill_vram(0x2000, opaque_tile);

    // print titles
    const char * const title = "You're watching an icestation-32 horizontal raster effects demonstration";
    const char * const subtitle = "Brought to you by vdp_copper.v";

    vp_printf(vp_center_string_x(title), 30, 0, SCROLL0, MAP_BASE, title);
    vp_printf(vp_center_string_x(subtitle), 30 + 1, 0, SCROLL0, MAP_BASE, subtitle);

    // checkerboard scrolling background

    const uint8_t checkerboard_bright_palette_id = 0x11;
    const uint16_t checkerboard_bright_color = 0xfccc;
    vdp_set_single_palette_color(checkerboard_bright_palette_id, checkerboard_bright_color);

    const uint8_t checkerboard_dark_palette_id = 0x21;
    const uint16_t checkerboard_dark_color = 0xf000;
    vdp_set_single_palette_color(checkerboard_dark_palette_id, checkerboard_dark_color);

    uint32_t frame_counter = 0;
    uint16_t line_offset = 0;
    uint16_t scroll = 0;

    enter_state(ST_IDLE);

    vdp_wait_frame_ended();

    while (true) {
        draw_triangle(angle, scale);

        // this wait must happen before changing copper enable state
        // there is risk of contention with VDP register writes otherwise
        vdp_wait_frame_ended();
        vdp_enable_copper(false);

        update_current_state();

        // TODO: printf metrics here

        const uint8_t metrics_x = 32;
        const uint8_t metrics_y = 36;

        vp_printf(metrics_x, metrics_y, 0, SCROLL0, MAP_BASE, "Copper RAM bytes used: %d", cop_ram_get_write_index());

//        vp_printf(metrics_x, metrics_y + 2, 0, SCROLL0, MAP_BASE, "OP_WRITE: %d", scroll);
//        vp_printf(metrics_x, metrics_y + 3, 0, SCROLL0, MAP_BASE, "OP_WRITE_COMPRESSED: %d", frame_counter);

        // polygon/text color updates

        const uint8_t polygon_bg_palette_id = 0x01;
        const uint16_t polygon_bg_color = 0xfa70;
        uint16_t color = (polygon_bg_color & 0x0fff) | alpha << 12;
        vdp_set_single_palette_color(polygon_bg_palette_id, color);

        const uint8_t polygon_fg_palette_id = 0x02;
        const uint16_t polygon_fg_color = 0xffff;
        color = (polygon_fg_color & 0x0fff) | alpha << 12;
        vdp_set_single_palette_color(polygon_fg_palette_id, color);

        vdp_set_layer_scroll(1, scroll, scroll);

        frame_counter++;
        line_offset++;

        if (frame_counter % 2) {
            scroll++;
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

static void draw_triangle_segment(int32_t *x1, int32_t *x2, int16_t y_base, int16_t y_end, int32_t x1_delta, int32_t x2_delta) {
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

    // clip segment to fit the screen height if needed

    bool segment_needs_drawing = true;

    if (y_base < 0 && y_end > 0) {
        // onscreen edge, but partially offscreen
        left += -y_base * delta_left;
        right += -y_base * delta_right;

        y_base = 0;
    } else if (y_base < 0 && y_end < 0) {
        // entirely offscreen edge, nothing to draw
        // advance deltas and bail out
        int16_t segment_height = y_end - y_base;

        left += segment_height * delta_left;
        right += segment_height * delta_right;

        segment_needs_drawing = false;
    }

    if (segment_needs_drawing) {
        y_end = MIN(y_end, SCREEN_ACTIVE_HEIGHT);

        for (int16_t y = y_base; y < y_end; y++) {
            left += delta_left;
            right += delta_right;

            int16_t edge_left = left / EDGE_Q_1;
            int16_t edge_right = right / EDGE_Q_1;

            const uint8_t line_start_slack = 16;
            const uint16_t left_bound = SCREEN_OFFSCREEN_X - line_start_slack;

            if (edge_left < left_bound) {
                // edge left side...
                cop_wait_target_x(left_bound);
            } else {
                cop_wait_target_x(edge_left);
            }

            cop_write_compressed(&VDP_LAYER_ENABLE, POLYGON_VISIBLE_LAYERS, false);

            if ((edge_right - edge_left) > 2) {
                const uint8_t line_end_slack = 3;
                const int16_t right_bound = RASTER_X_MAX - line_end_slack;

                if (edge_right > right_bound) {
                    cop_wait_target_x(right_bound);
                } else {
                    // ...wait to reach the ride side of the edge...
                    cop_wait_target_x(edge_right);
                }
            }

            // ...edge right side
            cop_write_compressed(&VDP_LAYER_ENABLE, POLYGON_HIDDEN_LAYERS, true);
        }
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

    // wait for raster (0, 0)
    cop_set_target_x(0);
    cop_wait_target_y(0);

    // ...
    cop_wait_target_x(2);

    // the copper at this point can be enabled as it will wait for raster using the above ops
    // the rest of the RAM is now available to be written without contention
    // this is fine so long as the copper PC (read pointer) doesn't "catch up" to the CPU write pointer
    vdp_enable_copper(true);

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
        // offset the triangle vertically if there is empty space above it
        cop_set_target_y(top.y);
    }

    // note it's dx/dy rather than dy/dx
    // the triangle edges are drawn by stepping through each vertical line, then doing x += (dx/dy)

    int32_t x1_delta;
    int32_t x2_delta = (dx2 * EDGE_Q_1) / dy2;

    int32_t x1_long = top.x * EDGE_Q_1;
    int32_t x2_long = x1_long;

    bool top_segment_visible = (dy1 != 0);
    if (top_segment_visible) {
        x1_delta = (dx1 * EDGE_Q_1) / dy1;

        draw_triangle_segment(&x1_long, &x2_long, top.y, mid.y, x1_delta, x2_delta);
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
        x1_delta = (dx1 * EDGE_Q_1) / dy1;

        draw_triangle_segment(&x1_long, &x2_long, mid.y, bottom.y, x1_delta, x2_delta);
    }

    cop_write(&VDP_LAYER_ENABLE, POLYGON_HIDDEN_LAYERS);

    cop_jump(0);
}
