// vdp_vram_bus_arbiter_interleaved.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"
`include "layer_encoding.vh"

module vdp_vram_bus_arbiter_interleaved(
    input clk,

    // Reference raster positions

    input [10:0] raster_x_offset, // !
    input [10:0] raster_x,
    input [9:0] raster_y,

    // Scroll attributes

    input [10:0] scroll_x_0, scroll_x_1, scroll_x_2, scroll_x_3,
    input [9:0] scroll_y_0, scroll_y_1, scroll_y_2, scroll_y_3,

    input [3:0] scroll_map_base_0, scroll_map_base_1, scroll_map_base_2, scroll_map_base_3,
    input [3:0] scroll_tile_base_0, scroll_tile_base_1, scroll_tile_base_2, scroll_tile_base_3,

    // 4 layers combined
    input [3:0] scroll_use_wide_map,

    // VRAM read data
    input [15:0] vram_read_data_even, vram_read_data_odd,

    // Output scroll attributes

    output [3:0] scroll_palette_0, scroll_palette_1, scroll_palette_2, scroll_palette_3,
    output scroll_x_flip_0, scroll_x_flip_1, scroll_x_flip_2, scroll_x_flip_3,

    // VRAM address

    output reg [13:0] vram_address_even, output reg [13:0] vram_address_odd
);
    // --- Layer attribute selection ---

    reg [9:0] gen_even_hscroll;
    reg [9:0] gen_even_scroll_y;
    reg [13:0] gen_even_map_base;
    reg gen_even_use_wide_map;

    reg [9:0] gen_odd_hscroll;
    reg [9:0] gen_odd_scroll_y;
    reg [13:0] gen_odd_map_base;
    reg gen_odd_use_wide_map;
        
    wire [3:0] gen_even_palette = vram_read_data_even_r[15:12];
    wire gen_even_hflip = vram_read_data_even_r[9];

    wire [3:0] gen_odd_palette = vram_read_data_odd_r[15:12];
    wire gen_odd_hflip = vram_read_data_odd_r[9];

    wire [13:0] gen_even_next_map_address;
    wire [13:0] gen_odd_next_map_address;

    reg gen_toggle_nx;
    reg gen_toggle;

    always @(posedge clk) begin
        gen_toggle <= gen_toggle_nx;
    end

    always @* begin
        if (!gen_toggle) begin
            // 0
            gen_even_hscroll = scroll_x[0];
            gen_even_scroll_y = scroll_y[0];
            gen_even_map_base = full_scroll_map_base(0);
            gen_even_use_wide_map = scroll_use_wide_map[0];
            // 1
            gen_odd_hscroll = scroll_x[1];
            gen_odd_scroll_y = scroll_y[1];
            gen_odd_map_base = full_scroll_map_base(1);
            gen_odd_use_wide_map = scroll_use_wide_map[1];
        end else begin
            // 2
            gen_even_hscroll = scroll_x[2];
            gen_even_scroll_y = scroll_y[2];
            gen_even_map_base = full_scroll_map_base(2);
            gen_even_use_wide_map = scroll_use_wide_map[2];
            // 3
            gen_odd_hscroll = scroll_x[3];
            gen_odd_scroll_y = scroll_y[3];
            gen_odd_map_base = full_scroll_map_base(3);
            gen_odd_use_wide_map = scroll_use_wide_map[3];
        end
    end

    // --- Tile address generator ---

    reg [2:0] tile_address_gen_scroll_y_granular;
    wire [2:0] tile_address_gen_raster_y_granular = raster_y[2:0];
    reg [15:0] tile_address_gen_map_data_in;
    reg [13:0] tile_address_gen_base_address;

    wire [13:0] tile_address_gen_tile_address_out;

    vdp_tile_address_generator tile_address_generator(
        .clk(clk),

        .scroll_y_granular(tile_address_gen_scroll_y_granular),
        .raster_y_granular(tile_address_gen_raster_y_granular),
        .vram_data(tile_address_gen_map_data_in),
        .tile_base_address(tile_address_gen_base_address),

        .tile_address(tile_address_gen_tile_address_out)
    );

    // --- Map address generators ---

    vdp_map_address_generator even_generator(
        .raster_y(raster_y),
        .raster_x_coarse(raster_x_offset[9:3] + 1),

        .scroll_x_coarse(gen_even_hscroll[9:3]),
        .scroll_y(gen_even_scroll_y),

        .map_base_address(gen_even_map_base),
        .stride(gen_even_use_wide_map ? 128 : 64),

        .map_address(gen_even_next_map_address)
    );

    vdp_map_address_generator odd_generator(
        .raster_y(raster_y),
        .raster_x_coarse(raster_x_offset[9:3] + 1),

        .scroll_x_coarse(gen_odd_hscroll[9:3]),
        .scroll_y(gen_odd_scroll_y),

        .map_base_address(gen_odd_map_base),
        .stride(gen_odd_use_wide_map ? 128 : 64),

        .map_address(gen_odd_next_map_address)
    );

    // --- Scroll meta prefetch ---

    reg [15:0] scroll_map_data_h [0:3];

    always @(posedge clk) begin
        // (scroll0 meta doesn't need to be held)

        if (scroll_meta_load[`LAYER_SCROLL1])
            scroll_map_data_h[`LAYER_SCROLL1] <= vram_read_data_odd_r;
        if (scroll_meta_load[`LAYER_SCROLL2])
            scroll_map_data_h[`LAYER_SCROLL2] <= vram_read_data_even_r; 
        if (scroll_meta_load[`LAYER_SCROLL3])
            scroll_map_data_h[`LAYER_SCROLL3] <= vram_read_data_odd_r;
    end

    // --- VRAM bus control ---

    always @* begin
        scroll_meta_load = 0;
        scroll_char_load = 0;

        load_all_scroll_row_data = 0;
        vram_write_data_nx = 0;
        vram_render_write_en_mask_nx = 0;

        gen_toggle_nx = 0;
        vram_address_even_nx = 0;
        vram_address_odd_nx = 0;
        vram_written = 0;

        tile_address_gen_scroll_y_granular = 0;
        tile_address_gen_map_data_in = 0;
        tile_address_gen_base_address = 0;

        vram_sprite_read_data_valid = 0;

        // TODO: define and document the -1 offset in one place
        case ((raster_x[2:0] - 1) &3'b111)
            0: begin
                // now: s2/s3 map data
                scroll_meta_load = `LAYER_SCROLL2_OHE | `LAYER_SCROLL3_OHE;

                // next: s1 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s1 prepare tile address gen
                tile_address_gen_scroll_y_granular = scroll_y[1][2:0];
                tile_address_gen_map_data_in = scroll_map_data_h[1];
                tile_address_gen_base_address = full_scroll_tile_base(1);
            end
            1: begin
                // now: sprite row data available
                vram_sprite_read_data_valid = 1;

                // next: s2 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s3 tile
                tile_address_gen_scroll_y_granular = scroll_y[2][2:0];
                tile_address_gen_map_data_in = scroll_map_data_h[2];
                tile_address_gen_base_address = full_scroll_tile_base(2);
            end
            2: begin
                // now: nothing, because this was a CPU write

                // next: s2 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s3 tile
                tile_address_gen_scroll_y_granular = scroll_y[3][2:0];
                tile_address_gen_map_data_in = scroll_map_data_h[3];
                tile_address_gen_base_address = full_scroll_tile_base(3);
            end
            3: begin
                gen_toggle_nx = 0;

                // now: s0 tile
                scroll_char_load = `LAYER_SCROLL0_OHE;

                // next: s3 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: none
            end
            4: begin
                gen_toggle_nx = 1;

                // now: s1 tile
                scroll_char_load = `LAYER_SCROLL1_OHE;

                // next: s0/s1 map address
                vram_address_even_nx = gen_even_next_map_address;
                vram_address_odd_nx = gen_odd_next_map_address;
            end
            5: begin
                // now: s2 tile
                scroll_char_load = `LAYER_SCROLL2_OHE;

                // next: s1/s2 map address
                vram_address_even_nx = gen_even_next_map_address;
                vram_address_odd_nx = gen_odd_next_map_address;
            end
            6: begin
                // next: sprite row fetch (if any, this could be ignored in sprite_core)
                vram_address_even_nx = vram_sprite_address;
                vram_address_odd_nx = vram_sprite_address;

                // now: s3 tile, which is loaded simultaneously with the previously prefetched layers
                // the offset added to count[2:0] compensates for this being a cycle earlier
                load_all_scroll_row_data = 1;
            end
            7: begin
                // host write - every 8 cycles
                vram_address_even_nx = vram_write_address_16b;
                vram_address_odd_nx = vram_write_address_16b;
                vram_write_data_nx = {2{vram_write_data_16b}};
                vram_written = 1;
                vram_render_write_en_mask_nx = vram_port_write_en_mask;

                // now: s0/s1 map data
                scroll_meta_load = `LAYER_SCROLL0_OHE | `LAYER_SCROLL1_OHE;

                // s0: prepare tile address gen
                tile_address_gen_scroll_y_granular = scroll_y[0][2:0];
                tile_address_gen_map_data_in = vram_read_data_even_r;
                tile_address_gen_base_address = full_scroll_tile_base(0);
            end
        endcase
    end

    // --- VRAM bus registers ---

    reg [15:0] vram_read_data_even_r;
    reg [15:0] vram_read_data_odd_r;

    wire affine_needs_vram = affine_enabled && !affine_offscreen;

    always @(posedge clk) begin
        vram_address_even <= affine_needs_vram ? affine_vram_address_even : vram_address_even_nx;
        vram_write_data_even <= vram_write_data_nx[15:0];
        vram_we_even <= affine_needs_vram ? 0 : vram_render_write_en_mask_nx[0];

        vram_read_data_even_r <= vram_read_data_even;
        vram_read_data_odd_r <= vram_read_data_odd;

        vram_address_odd <= affine_needs_vram ? affine_vram_address_odd : vram_address_odd_nx;
        vram_write_data_odd <= vram_write_data_nx[31:16];
        vram_we_odd <= affine_needs_vram ? 0 : vram_render_write_en_mask_nx[1];
    end

/*
reg [13:0] vram_address_even_nx;
    reg [13:0] vram_address_odd_nx;
    reg [1:0] vram_render_write_en_mask_nx;
    reg [31:0] vram_write_data_nx;

    reg [3:0] scroll_meta_load;
    reg [3:0] scroll_char_load;

    reg load_all_scroll_row_data;
    reg vram_written;
    */

endmodule
