// vdp_vram_bus_arbiter_standard.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"
`include "layer_encoding.vh"

// 3 layer, non-interleaved bus arbiter
// Unlike vdp_vram_bus_arbiter_interleaved, tilemaps are stored in VRAM contiguously
// This sacrifices 1 layer in exchange for more flexible, less wasteful VRAM management

module vdp_vram_bus_arbiter_standard(
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

    reg [10:0] scroll_x_selected;
    reg [9:0] scroll_y_selected;
    reg [14:0] scroll_map_base_selected;
    reg scroll_use_wide_map_selected;

    always @* begin
        case (map_address_layer_select)
            `LAYER_SCROLL0: scroll_x_selected = scroll_x_0;
            `LAYER_SCROLL1: scroll_x_selected = scroll_x_1;
            default: scroll_x_selected = scroll_x_2;
        endcase

        case (map_address_layer_select)
            `LAYER_SCROLL0: scroll_y_selected = scroll_y_0;
            `LAYER_SCROLL1: scroll_y_selected = scroll_y_1;
            default: scroll_y_selected = scroll_y_2;
        endcase

        scroll_map_base_selected = full_scroll_map_base(map_address_layer_select);
        scroll_use_wide_map_selected = scroll_use_wide_map[map_address_layer_select];
    end

    // --- Tile address generator ---

    wire [2:0] tile_raster_y_granular = raster_y[2:0];
    wire [13:0] tile_address;

    vdp_tile_address_generator tile_address_generator(
        .clk(clk),

        .scroll_y_granular(tile_scroll_y_granular_selected),
        .raster_y_granular(tile_raster_y_granular),
        .vram_data(tile_map_data_selected),
        .tile_base_address(tile_base_selected),

        .tile_address(tile_address)
    );

    reg [2:0] tile_scroll_y_granular_selected;
    reg [15:0] tile_map_data_selected;
    reg [13:0] tile_base_selected;

    always @* begin
        case (tile_address_layer_select)
            `LAYER_SCROLL0: tile_scroll_y_granular_selected = scroll_y_0[2:0];
            `LAYER_SCROLL1: tile_scroll_y_granular_selected = scroll_y_1[2:0];
            default: tile_scroll_y_granular_selected = scroll_y_2[2:0];
        endcase

        tile_map_data_selected = scroll_map_data_hold[tile_address_layer_select];
        tile_base_selected = full_scroll_tile_base(tile_address_layer_select);
    end

    // --- Map address generators ---

    wire [10:0] raster_x_next_tile = raster_x_offset[9:3] + 1;

    wire [13:0] map_address = map_address_16b[14:1];
    wire map_word_select = map_address_16b[0];

    wire [14:0] map_address_16b;

    vdp_map_address_generator #(
        .REGISTERED_INPUTS(1)
    ) map_address_generator (
        .clk(clk),

        .raster_y(raster_y),
        .raster_x_coarse(raster_x_next_tile),

        .scroll_x_coarse(scroll_x_selected[9:3]),
        .scroll_y(scroll_y_selected),

        .map_base_address(scroll_map_base_selected),
        .stride(scroll_use_wide_map_selected ? 128 : 64),

        .map_address_16b(map_address_16b)
    );

    // --- Scroll meta prefetch ---

    reg [15:0] scroll_map_data_hold [0:3];

    wire [3:0] palette_selected = map_selected_word[15:12];

    // A delay is needed on the VRAM word select since the fetches are pipelined

    wire map_word_select_d;

    delay_ff #(
        .DELAY(3)
    ) map_word_select_dm (
        .clk(clk),
        .in(map_word_select),
        .out(map_word_select_d)
    );

    wire [15:0] map_selected_word = map_word_select_d ? vram_read_data_odd : vram_read_data_even;

    assign scroll_palette_0 = palette_selected;
    assign scroll_palette_1 = palette_selected;
    assign scroll_palette_2 = palette_selected;
    assign scroll_palette_3 = 0;

    assign scroll_x_flip_0 = scroll_map_data_hold[`LAYER_SCROLL0][9];
    assign scroll_x_flip_1 = scroll_map_data_hold[`LAYER_SCROLL1][9];
    assign scroll_x_flip_2 = scroll_map_data_hold[`LAYER_SCROLL2][9];
    assign scroll_x_flip_3 = 0;

    always @(posedge clk) begin
        if (scroll_meta_load[`LAYER_SCROLL0])
            scroll_map_data_hold[`LAYER_SCROLL0] <= map_selected_word;
        if (scroll_meta_load[`LAYER_SCROLL1])
            scroll_map_data_hold[`LAYER_SCROLL1] <= map_selected_word;
        if (scroll_meta_load[`LAYER_SCROLL2])
            scroll_map_data_hold[`LAYER_SCROLL2] <= map_selected_word; 
        if (scroll_meta_load[`LAYER_SCROLL3])
            scroll_map_data_hold[`LAYER_SCROLL3] <= map_selected_word;
    end

    // --- VRAM bus control ---

    reg [13:0] vram_address_nx;
    reg [1:0] vram_render_write_en_mask_nx;

    reg [1:0] map_address_layer_select;
    reg [1:0] tile_address_layer_select;

    always @* begin
        scroll_meta_load = 0;
        scroll_char_load = 0;

        map_address_layer_select = 0;
        tile_address_layer_select = 0;

        load_all_scroll_row_data = 0;
        vram_render_write_en_mask_nx = 0;

        vram_address_nx = 0;
        vram_written = 0;

        vram_sprite_read_data_valid = 0;

        case (raster_x_offset[2:0])
            0: begin
                // now: s0 map data
                scroll_meta_load = `LAYER_SCROLL0_OHE;

                // host write - every 8 cycles
                vram_address_nx = vram_write_address_16b;
                vram_written = 1;
                vram_render_write_en_mask_nx = vram_port_write_en_mask;
            end
            1: begin
                // now: s1 map
                scroll_meta_load = `LAYER_SCROLL1_OHE;

                // next: sprite access
                vram_address_nx = vram_sprite_address;

                // next next: s0 tile address
                tile_address_layer_select = `LAYER_SCROLL0;
            end
            2: begin
                // now: s2 map
                scroll_meta_load = `LAYER_SCROLL2_OHE;

                // next: s0 tile
                vram_address_nx = tile_address;

                // next next: s1 tile address
                tile_address_layer_select = `LAYER_SCROLL1;
            end
            3: begin
                // next: s1 tile
                vram_address_nx = tile_address;

                // next next: s2 tile address
                tile_address_layer_select = `LAYER_SCROLL2;
            end
            4: begin
                // now: sprites acccess
                vram_sprite_read_data_valid = 1;

                // next: s2 tile
                vram_address_nx = tile_address;

                // next next: s0 map
                map_address_layer_select = `LAYER_SCROLL0;
            end
            5: begin
                // now: s0 tile
                scroll_char_load = `LAYER_SCROLL0_OHE;

                // next: s0 map
                vram_address_nx = map_address;

                // next next: s1 map
                map_address_layer_select = `LAYER_SCROLL1;
            end
            6: begin
                // now: s1 tile
                scroll_char_load = `LAYER_SCROLL1_OHE;

                // next: s1 map
                vram_address_nx = map_address;

                // next next: s2 map
                map_address_layer_select = `LAYER_SCROLL2;
            end
            7: begin
                // now: s1 tile
                // (this should be implicit according to load_all...)
                scroll_char_load = `LAYER_SCROLL2_OHE;

                // next: s2 map
                vram_address_nx = map_address;

                // now: s3 tile, which is loaded simultaneously with the previously prefetched layers
                load_all_scroll_row_data = 1;
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
        vram_address_even <= affine_needs_vram ? affine_vram_address_even : vram_address_nx;
        vram_we_even <= affine_needs_vram ? 0 : vram_render_write_en_mask_nx[0];

        vram_address_odd <= affine_needs_vram ? affine_vram_address_odd : vram_address_nx;
        vram_we_odd <= affine_needs_vram ? 0 : vram_render_write_en_mask_nx[1];
    end

    // --- VRAM base address mapping functions ---

    function [13:0] full_scroll_tile_base;
        input [1:0] layer;

        begin
            full_scroll_tile_base = {scroll_tile_base >> (layer * 4), 11'b0};
        end

    endfunction
        
    function [14:0] full_scroll_map_base;
        input [1:0] layer;

        begin
            full_scroll_map_base = {scroll_map_base >> (layer * 4), 12'b0};
        end

    endfunction

endmodule
