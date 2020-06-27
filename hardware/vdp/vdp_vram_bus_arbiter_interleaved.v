// vdp_vram_bus_arbiter_interleaved.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"
`include "layer_encoding.vh"

// This is the original VRAM bus arbiter that uses interleaved tilemaps
// It allows for 4 scrolling layers using separate odd / even addresses for the separate RAMs
// The downside is that the interleaving means VRAM space may be wasted

// This is one of the older parts of the project before and could use some cleanup

module vdp_vram_bus_arbiter_interleaved(
    input clk,

    // Reference raster positions

    input [10:0] raster_x_offset,
    input [10:0] raster_x,
    input [9:0] raster_y,

    // Scroll attributes

    input [10:0] scroll_x_0, scroll_x_1, scroll_x_2, scroll_x_3,
    input [9:0] scroll_y_0, scroll_y_1, scroll_y_2, scroll_y_3,

    // 4 layers combined
    input [15:0] scroll_tile_base,
    input [15:0] scroll_map_base,

    // Affine attributes

    input affine_enabled,
    input affine_offscreen,
    input [13:0] affine_vram_address_even, affine_vram_address_odd,

    // Sprite attributes

    input [13:0] vram_sprite_address,

    // 4 layers combined
    input [3:0] scroll_use_wide_map,

    // Output scroll attributes

    output [3:0] scroll_palette_0, scroll_palette_1, scroll_palette_2, scroll_palette_3,
    output scroll_x_flip_0, scroll_x_flip_1, scroll_x_flip_2, scroll_x_flip_3,

    // Output control for various functional blocks

    output reg load_all_scroll_row_data,
    output reg vram_written,
    output reg vram_sprite_read_data_valid,

    output reg [3:0] scroll_char_load,
    output reg [3:0] scroll_meta_load,

    // VRAM write control

    input [1:0] vram_port_write_en_mask,
    input [13:0] vram_write_address_16b,
    input [15:0] vram_write_data_16b,

    // VRAM interface

    input [15:0] vram_read_data_even,  vram_read_data_odd,

    output reg [13:0] vram_address_even,  vram_address_odd,
    output reg [15:0] vram_write_data_even, vram_write_data_odd,
    output reg vram_we_even, vram_we_odd
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
        
    wire [3:0] gen_even_palette = vram_read_data_even[15:12];
    wire gen_even_hflip = vram_read_data_even[9];

    wire [3:0] gen_odd_palette = vram_read_data_odd[15:12];
    wire gen_odd_hflip = vram_read_data_odd[9];

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
            gen_even_hscroll = scroll_x_0;
            gen_even_scroll_y = scroll_y_0;
            gen_even_map_base = full_scroll_map_base(0);
            gen_even_use_wide_map = scroll_use_wide_map[0];
            // 1
            gen_odd_hscroll = scroll_x_1;
            gen_odd_scroll_y = scroll_y_1;
            gen_odd_map_base = full_scroll_map_base(1);
            gen_odd_use_wide_map = scroll_use_wide_map[1];
        end else begin
            // 2
            gen_even_hscroll = scroll_x_2;
            gen_even_scroll_y = scroll_y_2;
            gen_even_map_base = full_scroll_map_base(2);
            gen_even_use_wide_map = scroll_use_wide_map[2];
            // 3
            gen_odd_hscroll = scroll_x_3;
            gen_odd_scroll_y = scroll_y_3;
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

    wire [10:0] raster_x_next_tile = raster_x_offset[9:3] + 1;

    vdp_map_address_generator even_generator(
        .raster_y(raster_y),
        .raster_x_coarse(raster_x_next_tile),

        .scroll_x_coarse(gen_even_hscroll[9:3]),
        .scroll_y(gen_even_scroll_y),

        .map_base_address(gen_even_map_base),
        .stride(gen_even_use_wide_map ? 128 : 64),

        .map_address_16b(gen_even_next_map_address)
    );

    vdp_map_address_generator odd_generator(
        .raster_y(raster_y),
        .raster_x_coarse(raster_x_next_tile),

        .scroll_x_coarse(gen_odd_hscroll[9:3]),
        .scroll_y(gen_odd_scroll_y),

        .map_base_address(gen_odd_map_base),
        .stride(gen_odd_use_wide_map ? 128 : 64),

        .map_address_16b(gen_odd_next_map_address)
    );

    // --- Scroll meta prefetch ---

    reg [15:0] scroll_map_data_hold [0:3];

    wire [3:0] even_palette = vram_read_data_even[15:12];
    wire [3:0] odd_palette = vram_read_data_odd[15:12];

    wire even_x_flip = vram_read_data_even[9];
    wire odd_x_flip = vram_read_data_odd[9];

    assign scroll_palette_0 = even_palette;
    assign scroll_palette_1 = odd_palette;
    assign scroll_palette_2 = even_palette;
    assign scroll_palette_3 = odd_palette;

    assign scroll_x_flip_0 = even_x_flip;
    assign scroll_x_flip_1 = odd_x_flip;
    assign scroll_x_flip_2 = even_x_flip;
    assign scroll_x_flip_3 = odd_x_flip;

    always @(posedge clk) begin
        // (scroll0 meta doesn't need to be held)

        if (scroll_meta_load[`LAYER_SCROLL1])
            scroll_map_data_hold[`LAYER_SCROLL1] <= vram_read_data_odd;
        if (scroll_meta_load[`LAYER_SCROLL2])
            scroll_map_data_hold[`LAYER_SCROLL2] <= vram_read_data_even; 
        if (scroll_meta_load[`LAYER_SCROLL3])
            scroll_map_data_hold[`LAYER_SCROLL3] <= vram_read_data_odd;
    end

    // --- VRAM bus control ---

    reg [13:0] vram_address_even_nx, vram_address_odd_nx;
    reg [1:0] vram_render_write_en_mask_nx;

    always @* begin
        scroll_meta_load = 0;
        scroll_char_load = 0;

        load_all_scroll_row_data = 0;
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
                tile_address_gen_scroll_y_granular = scroll_y_1[2:0];
                tile_address_gen_map_data_in = scroll_map_data_hold[1];
                tile_address_gen_base_address = full_scroll_tile_base(1);
            end
            1: begin
                // now: sprite row data available
                vram_sprite_read_data_valid = 1;

                // next: s2 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s3 tile
                tile_address_gen_scroll_y_granular = scroll_y_2[2:0];
                tile_address_gen_map_data_in = scroll_map_data_hold[2];
                tile_address_gen_base_address = full_scroll_tile_base(2);
            end
            2: begin
                // now: nothing, because this was a CPU write

                // next: s2 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s3 tile
                tile_address_gen_scroll_y_granular = scroll_y_3[2:0];
                tile_address_gen_map_data_in = scroll_map_data_hold[3];
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
                vram_written = 1;
                vram_render_write_en_mask_nx = vram_port_write_en_mask;

                // now: s0/s1 map data
                scroll_meta_load = `LAYER_SCROLL0_OHE | `LAYER_SCROLL1_OHE;

                // s0: prepare tile address gen
                tile_address_gen_scroll_y_granular = scroll_y_0[2:0];
                tile_address_gen_map_data_in = vram_read_data_even;
                tile_address_gen_base_address = full_scroll_tile_base(0);
            end
        endcase
    end

    // --- VRAM write data passthrough ---

    always @* begin
        vram_write_data_even = vram_write_data_16b;
        vram_write_data_odd = vram_write_data_16b;
    end

    // --- VRAM bus registers ---

    wire affine_needs_vram = affine_enabled && !affine_offscreen;

    always @(posedge clk) begin
        vram_address_even <= affine_needs_vram ? affine_vram_address_even : vram_address_even_nx;
        vram_we_even <= affine_needs_vram ? 0 : vram_render_write_en_mask_nx[0];

        vram_address_odd <= affine_needs_vram ? affine_vram_address_odd : vram_address_odd_nx;
        vram_we_odd <= affine_needs_vram ? 0 : vram_render_write_en_mask_nx[1];
    end

    // --- VRAM base address mapping functions ---

    function [13:0] full_scroll_tile_base;
        input [1:0] layer;

        begin
            full_scroll_tile_base = {scroll_tile_base >> (layer * 4), 10'b0};
        end

    endfunction
        
    function [13:0] full_scroll_map_base;
        input [1:0] layer;

        begin
            full_scroll_map_base = {scroll_map_base >> (layer * 4), 10'b0};
        end

    endfunction

endmodule
