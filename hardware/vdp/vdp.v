// vdp.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"
`include "layer_encoding.vh"

module vdp #(
    parameter ENABLE_WIDESCREEN = 0,
    parameter CHAR_BASE_BITS = 4,
    parameter MAP_BASE_BITS = 4
) (
    input clk,
    input reset,

    // host interface

    input [15:0] host_address,
    
    input [15:0] host_write_data,
    input host_write_en,

    input host_read_en,
    output reg [15:0] host_read_data,
    output host_ready,

    // VGA output

    output reg [3:0] r,
    output reg [3:0] g,
    output reg [3:0] b,

    output vga_hsync,
    output vga_vsync,

    output active_display,

    // single-cycle strobes, NOT suitable for VGA

    output line_ended,
    output frame_ended,
    output active_frame_ended,

    output reg target_raster_hit,
    
    // VRAM interface

    output reg [13:0] vram_address_even,
    output reg vram_we_even,
    input [15:0] vram_read_data_even,
    output reg [15:0] vram_write_data_even,

    output reg [13:0] vram_address_odd,
    output reg vram_we_odd,
    input [15:0] vram_read_data_odd,    
    output reg [15:0] vram_write_data_odd
);
    // --- Video timing ---

    // 848x480@60hz

    localparam H_ACTIVE_WIDTH_848 = 848;
    localparam H_SYNC_848 = 112;
    localparam H_BACKPORCH_848 = 112;

    localparam V_FRONTPORCH_848 = 6;
    localparam V_SYNC_848 = 8;
    localparam V_BACKPORCH_848 = 23;

    // 640x480@60hz

    localparam H_ACTIVE_WIDTH_640 = 640;
    localparam H_SYNC_640 = 96;
    localparam H_BACKPORCH_640 = 48;

    localparam V_FRONTPORCH_640 = 11;
    localparam V_SYNC_640 = 2;
    localparam V_BACKPORCH_640 = 31;

    // common between both modes
    
    localparam V_ACTIVE_HEIGHT = 480;
    localparam H_FRONTPORCH = 16;

    // select one of the above video modes according to parameter

    localparam H_ACTIVE_WIDTH = ENABLE_WIDESCREEN ? H_ACTIVE_WIDTH_848 : H_ACTIVE_WIDTH_640;
    localparam H_SYNC = ENABLE_WIDESCREEN ? H_SYNC_848 : H_SYNC_640;
    localparam H_BACKPORCH = ENABLE_WIDESCREEN ? H_BACKPORCH_848 : H_BACKPORCH_640;

    localparam V_FRONTPORCH = ENABLE_WIDESCREEN ? V_FRONTPORCH_848 : V_FRONTPORCH_640;
    localparam V_SYNC = ENABLE_WIDESCREEN ? V_SYNC_848 : V_SYNC_640;
    localparam V_BACKPORCH = ENABLE_WIDESCREEN ? V_BACKPORCH_848 : V_BACKPORCH_640;

    // for use by other blocks below

    localparam OFFSCREEN_X_TOTAL = H_SYNC + H_FRONTPORCH + H_BACKPORCH;
    localparam HEIGHT_TOTAL = V_ACTIVE_HEIGHT + V_FRONTPORCH + V_SYNC + V_BACKPORCH;

    wire [11:0] raster_x;
    wire [10:0] raster_y;

    // verilator lint_off PINMISSING

    vdp_vga_timing #(
        .H_ACTIVE_WIDTH(H_ACTIVE_WIDTH),
        .V_ACTIVE_HEIGHT(V_ACTIVE_HEIGHT),
        .H_FRONTPORCH(H_FRONTPORCH),
        .H_SYNC(H_SYNC),
        .H_BACKPORCH(H_BACKPORCH),
        .V_FRONTPORCH(V_FRONTPORCH),
        .V_SYNC(V_SYNC),
        .V_BACKPORCH(V_BACKPORCH)
    ) vga_timing (
        .clk(clk),

        .raster_x(raster_x),
        .raster_y(raster_y),

        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .active_display(active_display),
        .active_frame_ended(active_frame_ended),

        .line_ended(line_ended),
        .frame_ended(frame_ended)
    );

    // verilator lint_on PINMISSING

    // --- Host interface ---

    wire [5:0] register_address;
    wire [15:0] register_write_data;
    wire register_write_en;

    vdp_host_interface host_interface(
        .clk(clk),
        .reset(reset),

        .read_en_in(host_read_en),
        .ready(host_ready),

        .write_en_in(host_write_en),
        .write_en_out(register_write_en),

        .address_in(host_address),
        .data_in(host_write_data),
        .data_out(register_write_data),
        .address_out(register_address)
    );

    // --- Register writes ---

    reg [5:0] layer_enable = 0;
    reg [4:0] layer_enable_alpha_over = 0;

    wire affine_enabled = layer_enable[5];
    wire enable_render = |layer_enable;

    reg [13:0] scroll_tile_base [0:3];
    reg [13:0] scroll_map_base [0:3];
    reg [15:0] scroll_x [0:3];
    reg [15:0] scroll_y [0:3];

    reg [3:0] scroll_use_wide_map;

    reg [13:0] sprite_tile_base;

    reg [13:0] vram_write_address_16b;
    reg [15:0] vram_write_data_16b;

    reg [1:0] vram_port_write_en_mask;
    reg [14:0] vram_write_address_full = 0;
    reg [7:0] vram_port_address_increment;

    always @(posedge clk) begin
        palette_write_en <= 0;
        sprite_metadata_write_en <= 0;

        sprite_metadata_block_select <= sprite_metadata_block_select_nx;

        if (sprite_metadata_write_en && sprite_meta_address_needs_increment) begin
            sprite_metadata_address <= sprite_metadata_address + 1;
        end

        if (palette_write_en) begin
            palette_write_address <= palette_write_address + 1;
        end

        if (register_write_en) begin
            if (register_address[5:4] == 2'b00) begin
                case (register_address[3:0])
                    0: begin
                        sprite_metadata_address <= register_write_data[7:0];
                        sprite_metadata_block_select <= 3'b001;
                    end
                    1: begin
                        sprite_metadata_write_data <= register_write_data;
                        sprite_metadata_write_en <= 1;
                    end
                    2: begin
                        palette_write_address <= register_write_data[7:0];
                    end
                    3: begin
                        pal_write_data <= register_write_data;
                        palette_write_en <= 1;
                    end
                    4: begin
                        vram_write_address_full <= register_write_data;
                        vram_port_write_en_mask <= 2'b00;
                    end
                    5: begin
                        // TODO: optimise this so the address doesn't need duplicating
                        // can get a vram_written input from sequencer below
                        vram_write_data_16b <= register_write_data;
                        vram_write_address_16b <= vram_write_address_full[14:1];
                        vram_port_write_en_mask <= vram_write_address_full[0] ? 2'b10 : 2'b01;
                        vram_write_address_full <= vram_write_address_full + vram_port_address_increment;
                    end
                    6: begin
                        vram_port_address_increment <= register_write_data[7:0];
                    end
                    7: begin
                        sprite_tile_base <= register_write_data;
                    end
                    default: begin
                        `stop($display("unimplemented register: %x", register_address);)
                    end
                endcase
            end else if (register_address[5:4] == 2'b01) begin
                case (register_address[3:2])
                    // can save LUTs by packing this into a single reg and write all at once
                    0: scroll_tile_base[register_address[1:0]] <= register_write_data;
                    1: scroll_x[register_address[1:0]] <= register_write_data;
                    2: scroll_y[register_address[1:0]] <= register_write_data;
                    3: scroll_map_base[register_address[1:0]] <= register_write_data;
                endcase
            end else if (register_address[5:4] == 2'b10) begin
                case (register_address[3:0])
                    0: layer_enable <= register_write_data[5:0];
                    1: layer_enable_alpha_over <= register_write_data[7:0];
                    2: scroll_use_wide_map <= register_write_data[3:0];
                    3: target_raster_x <= register_write_data[10:0];
                    4: target_raster_y <= register_write_data[9:0];
                    default: begin
                        `stop($display("unimplemented register: %x", register_address);)
                    end
                endcase
            end
        end
    end

    // --- Register reads ---

    always @(posedge clk) begin
        case (register_address[1:0])
            0: host_read_data <= raster_x;
            2: host_read_data <= raster_y;
        endcase
    end

    // --- Sprite metadata writing ---
    
    reg [7:0] sprite_metadata_address;
    reg [2:0] sprite_metadata_block_select;
    reg [15:0] sprite_metadata_write_data;
    reg sprite_metadata_write_en;

    reg [2:0] sprite_metadata_block_select_nx;
    wire sprite_meta_address_needs_increment = sprite_metadata_block_select == 3'b100;

    always @* begin
        sprite_metadata_block_select_nx = sprite_metadata_block_select;

        if (sprite_metadata_write_en) begin
            sprite_metadata_block_select_nx = sprite_metadata_block_select << 1;

            if (sprite_meta_address_needs_increment) begin
                sprite_metadata_block_select_nx = 3'b001;
            end
        end
    end

    // --- Raster count target ---

    reg [10:0] target_raster_x;
    reg [9:0] target_raster_y;

    wire target_raster_x_hit = target_raster_x == raster_x;
    wire target_raster_y_hit = target_raster_y == raster_y;

    wire target_raster_hit_nx = target_raster_x_hit && target_raster_y_hit;

    always @(posedge clk) begin
        target_raster_hit <= target_raster_hit_nx;
    end

    // --- Affine layer register mapping ---

    // affine layer reuses the regular scroll registers
    // the two kinds of layers can't be active at the same time so reuse these to save LCs

    wire [15:0] affine_pretranslate_x = scroll_x[0];
    wire [15:0] affine_pretranslate_y = scroll_y[0];

    wire [15:0] affine_a = scroll_x[1];
    wire [15:0] affine_b = scroll_x[2];
    wire [15:0] affine_c = scroll_x[3];
    wire [15:0] affine_d = scroll_y[1];

    wire [15:0] affine_translate_x = scroll_y[2];
    wire [15:0] affine_translate_y = scroll_y[3];

    // --- Palette RAM ---

    reg [7:0] palette_write_address = 0;
    reg [15:0] pal_write_data;
    reg palette_write_en = 0;

    reg [15:0] palette_ram [0:255];
    reg [15:0] palette_output;

    wire [7:0] palette_masked_read_address = prioritized_masked_pixel;
    reg [15:0] palette_masked_output;

    wire [7:0] palette_read_address = prioritized_pixel;

    always @(posedge clk) begin
        if (palette_write_en) begin
            palette_ram[palette_write_address] <= pal_write_data;
        end

        palette_output <= palette_ram[palette_read_address];
        palette_masked_output <= palette_ram[palette_masked_read_address];
    end

    // --- Blender ---

    assign layer_mask = ~layer_enable_alpha_over;

    wire source_layer_enabled = |(prioritized_masked_layer & layer_enable_alpha_over);
    wire [11:0] blender_output_color;

    vdp_blender blender(
        .clk(clk),

        .source_layer_enabled(source_layer_enabled),
        .source_color(palette_masked_output),

        .dest_color(palette_output),

        .output_color(blender_output_color)
    );

    wire [11:0] output_color = (enable_render && active_display ? blender_output_color : 12'b0);

    always @(posedge clk) begin
        r <= output_color[11:8];
        g <= output_color[7:4];
        b <= output_color[3:0];
    end

    // --- Raster offset for scrolling layers ---

    localparam SCROLL_START_LEAD_TIME = 32;
    localparam SCROLL_OFFSCREEN_ADVANCE = -8;

    reg [9:0] raster_x_offset;

    localparam HEIGHT_DIFF = HEIGHT_TOTAL - 512;

    wire scroll_base_x_start = raster_x == (OFFSCREEN_X_TOTAL - SCROLL_START_LEAD_TIME + 0);

    // the +1 is to preserve alignment between raster_x[2:0] (used to sequence VRAM access)
    localparam SCROLL_BASE_X_INITIAL = SCROLL_OFFSCREEN_ADVANCE + 1;

    always @(posedge clk) begin
        raster_x_offset <= scroll_base_x_start ? SCROLL_BASE_X_INITIAL : raster_x_offset + 1;
    end

    // --- Raster offset for sprites ---

    localparam SPRITE_START_LEAD_TIME = 10;

    reg [9:0] sprites_x;
    reg [8:0] sprites_y;

    reg [8:0] sprites_y_nx;

    always @* begin
        sprites_y_nx = raster_y;

        // the raster_y counter does not count up to a power-of-2
        // this manual offset handling is added to make it appear as if it does to the sprite core
        if (raster_y >= V_ACTIVE_HEIGHT) begin
            if (raster_y > (HEIGHT_TOTAL - 16)) begin
                // there may be a 16px tall sprite coming in from the top of the screen
                sprites_y_nx = (512 - 16) + (raster_y - (HEIGHT_TOTAL - 16));
            end else begin
                sprites_y_nx = V_ACTIVE_HEIGHT;
            end
        end 
    end

    wire sprites_x_start = (raster_x == (OFFSCREEN_X_TOTAL - SPRITE_START_LEAD_TIME - 1));
    wire sprites_x_reset = line_ended;
    reg sprites_x_counting = 0;

    localparam sprites_x_initial = -1;

    always @(posedge clk) begin
        // used for line buffer read address for display
        if (sprites_x_reset) begin
            sprites_x_counting <= 0;
        end else if (sprites_x_start) begin
            sprites_x_counting <= 1;
        end

        sprites_x <= (sprites_x_counting ? sprites_x + 1 : sprites_x_initial);

        // used for raster collision test
        sprites_y <= sprites_y_nx;
    end

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

    reg [13:0] gen_even_next_map_address;
    reg [13:0] gen_odd_next_map_address;

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
            gen_even_map_base = map_base_coarse_to_address(scroll_map_base[0]);
            gen_even_use_wide_map = scroll_use_wide_map[0];
            // 1
            gen_odd_hscroll = scroll_x[1];
            gen_odd_scroll_y = scroll_y[1];
            gen_odd_map_base = map_base_coarse_to_address(scroll_map_base[1]);
            gen_odd_use_wide_map = scroll_use_wide_map[1];
        end else begin
            // 2
            gen_even_hscroll = scroll_x[2];
            gen_even_scroll_y = scroll_y[2];
            gen_even_map_base = map_base_coarse_to_address(scroll_map_base[2]);
            gen_even_use_wide_map = scroll_use_wide_map[2];
            // 3
            gen_odd_hscroll = scroll_x[3];
            gen_odd_scroll_y = scroll_y[3];
            gen_odd_map_base = map_base_coarse_to_address(scroll_map_base[3]);
            gen_odd_use_wide_map = scroll_use_wide_map[3];
        end
    end

    // --- Tile address generator ---

    reg [2:0] tile_address_gen_scroll_y_granular;
    wire [2:0] tile_address_gen_raster_y_granular = raster_y[2:0];
    reg [15:0] tile_address_gen_map_data_in;
    reg [13:0] tile_address_gen_base_address;

    reg [13:0] tile_address_gen_tile_address_out;

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
        .raster_x_coarse(raster_x_offset[9:3]),

        .scroll_x_coarse(gen_odd_hscroll[9:3] + 1),
        .scroll_y(gen_odd_scroll_y),

        .map_base_address(gen_odd_map_base),
        .stride(gen_odd_use_wide_map ? 128 : 64),

        .map_address(gen_odd_next_map_address)
    );

    wire [31:0] vram_read_data_r = {vram_read_data_odd_r, vram_read_data_even_r};

    // --- Scroll meta prefetch ---

    reg [15:0] scroll_map_data_h [0:3];

    always @(posedge clk) begin
        // (scroll0 meta doesn't need to be held)

        if (scroll_meta_load[LAYER_SCROLL1])
            scroll_map_data_h[LAYER_SCROLL1] <= vram_read_data_odd_r;
        if (scroll_meta_load[LAYER_SCROLL2])
            scroll_map_data_h[LAYER_SCROLL2] <= vram_read_data_even_r; 
        if (scroll_meta_load[LAYER_SCROLL3])
            scroll_map_data_h[LAYER_SCROLL3] <= vram_read_data_odd_r;
    end

    // --- Scroll pixel generators ---

    wire [3:0] scroll_gen_hflip = {
        gen_odd_hflip,
        gen_even_hflip,
        gen_odd_hflip,
        gen_even_hflip
    };

    wire [15:0] scroll_gen_palette = {
        gen_odd_palette,
        gen_even_palette,
        gen_odd_palette,
        gen_even_palette
    };

    wire [31:0] scroll_output_pixel;

    wire [7:0] scroll0_output_pixel = scroll_output_pixel[7:0];
    wire [7:0] scroll1_output_pixel = scroll_output_pixel[15:8];
    wire [7:0] scroll2_output_pixel = scroll_output_pixel[23:16];
    wire [7:0] scroll3_output_pixel = scroll_output_pixel[31:24];

    generate
        genvar i;
        for (i = 0; i < 4; i = i + 1) begin : scroll_pixel_gen
            vdp_scroll_pixel_generator #(
                .STAGE_PIXEL_ROW(i != 3)
            ) scroll_pixel_generator(
                .clk(clk),

                .scroll_x_granular(scroll_x[i][2:0]),
                .raster_x_granular(raster_x_offset[2:0]),
                .pixel_row(vram_read_data_r),
                .palette_number(scroll_gen_palette[i * 4 + 3: i * 4]),
                .hflip(scroll_gen_hflip[i]),
                .meta_load_enable(scroll_meta_load[i]),
                .tile_row_load_enable(scroll_char_load[i]),
                .shifter_preload_load_enable(load_all_scroll_row_data),

                .pixel(scroll_output_pixel[i * 8 + 7: i * 8])
            );
        end
    endgenerate

    // --- Priority control --- 

    wire [7:0] prioritized_pixel;
    wire [4:0] prioritized_masked_layer;
    wire [7:0] prioritized_masked_pixel;

    // verilator lint_off UNUSED
    wire [4:0] prioritized_layer;
    // verilator lint_on UNUSED

    wire [4:0] layer_mask;

    wire [7:0] selected_layer_pixel = affine_enabled ? affine_output_pixel : scroll0_output_pixel;

    vdp_priority_compute priority_compute(
        .clk(clk),

        .scroll1_pixel(selected_layer_pixel),
        .scroll2_pixel(scroll1_output_pixel),
        .scroll3_pixel(scroll2_output_pixel),
        .scroll4_pixel(scroll3_output_pixel),

        .sprite_pixel(sprite_pixel),
        .sprite_priority(sprite_pixel_priority),

        .layer_enable(layer_enable[4:0] & (affine_enabled ? 5'b10001 : 5'b11111)),
        .layer_mask(layer_mask),

        .prioritized_pixel(prioritized_pixel),
        .prioritized_layer(prioritized_layer),
        .prioritized_masked_layer(prioritized_masked_layer),
        .prioritized_masked_pixel(prioritized_masked_pixel)
    );

    // --- VRAM bus arbiter ---
    
    reg [13:0] vram_address_even_nx;
    reg [13:0] vram_address_odd_nx;
    reg [1:0] vram_render_write_en_mask_nx;
    reg [31:0] vram_write_data_nx;

    reg [3:0] scroll_meta_load;
    reg [3:0] scroll_char_load;

    reg load_all_scroll_row_data;

    always @* begin
        scroll_meta_load = 0;
        scroll_char_load = 0;

        load_all_scroll_row_data = 0;
        vram_write_data_nx = 0;
        vram_render_write_en_mask_nx = 0;

        gen_toggle_nx = 0;
        vram_address_even_nx = 0;
        vram_address_odd_nx = 0;

        tile_address_gen_scroll_y_granular = 0;
        tile_address_gen_map_data_in = 0;
        tile_address_gen_base_address = 0;

        vram_sprite_read_data_valid = 0;

        // TODO: define and document the -1 offset in one place
        case ((raster_x[2:0] - 1) &3'b111)
            0: begin
                // now: s2/s3 map data
                scroll_meta_load = LAYER_SCROLL2_OHE | LAYER_SCROLL3_OHE;

                // next: s1 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s1 prepare tile address gen
                tile_address_gen_scroll_y_granular = scroll_y[1][2:0];
                tile_address_gen_map_data_in = scroll_map_data_h[1];
                tile_address_gen_base_address = tile_base_coarse_to_address(scroll_tile_base[1]);
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
                tile_address_gen_base_address = tile_base_coarse_to_address(scroll_tile_base[2]);
            end
            2: begin
                // now: nothing, because this was a CPU write

                // next: s2 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: s3 tile
                tile_address_gen_scroll_y_granular = scroll_y[3][2:0];
                tile_address_gen_map_data_in = scroll_map_data_h[3];
                tile_address_gen_base_address = tile_base_coarse_to_address(scroll_tile_base[3]);
            end
            3: begin
                gen_toggle_nx = 0;

                // now: s0 tile
                scroll_char_load = LAYER_SCROLL0_OHE;

                // next: s3 tile
                vram_address_even_nx = tile_address_gen_tile_address_out;
                vram_address_odd_nx = tile_address_gen_tile_address_out;

                // next next: none
            end
            4: begin
                gen_toggle_nx = 1;

                // now: s1 tile
                scroll_char_load = LAYER_SCROLL1_OHE;

                // next: s0/s1 map address
                vram_address_even_nx = gen_even_next_map_address;
                vram_address_odd_nx = gen_odd_next_map_address;
            end
            5: begin
                // now: s2 tile
                scroll_char_load = LAYER_SCROLL2_OHE;

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
                vram_render_write_en_mask_nx = vram_port_write_en_mask;

                // now: s0/s1 map data
                scroll_meta_load = LAYER_SCROLL0_OHE | LAYER_SCROLL1_OHE;

                // s0: prepare tile address gen
                tile_address_gen_scroll_y_granular = scroll_y[0][2:0];
                tile_address_gen_map_data_in = vram_read_data_even_r;
                tile_address_gen_base_address = tile_base_coarse_to_address(scroll_tile_base[0]);
            end
        endcase
    end

    // --- Sprites ---

    wire [7:0] sprite_pixel;
    wire [1:0] sprite_pixel_priority;

    wire [13:0] vram_sprite_address;
    reg vram_sprite_read_data_valid;

    wire sprite_core_reset = line_ended;

    vdp_sprite_core sprites(
        .clk(clk),
        .start_new_line(sprite_core_reset),

        .x(sprites_x),
        .y(sprites_y),

        .meta_address(sprite_metadata_address),
        .meta_write_data(sprite_metadata_write_data),
        .meta_block_select(sprite_metadata_block_select),
        .meta_we(sprite_metadata_write_en),

        .vram_base_address(tile_base_coarse_to_address(sprite_tile_base)),
        .vram_read_address(vram_sprite_address),
        .vram_read_data(vram_read_data_r),
        .vram_data_valid(vram_sprite_read_data_valid),

        .pixel(sprite_pixel),
        .pixel_priority(sprite_pixel_priority)
    );

    // --- Affine layer ---

    wire [13:0] affine_vram_address_even, affine_vram_address_odd;

    wire [7:0] affine_output_pixel;

    reg [9:0] affine_x;
    wire [8:0] affine_y = raster_y;

    wire affine_x_start = raster_x == (OFFSCREEN_X_TOTAL - 7);

    // NOTE: this may effect sprite fillrate so this should probably be wound back a bit with pipeline delay etc.
    wire affine_x_end = raster_x == H_ACTIVE_WIDTH + OFFSCREEN_X_TOTAL - 1;

    reg affine_offscreen;
    localparam affine_x_initial = -2;

    always @(posedge clk) begin
        affine_x <= affine_x + 1;

        if (affine_x_start) begin
            affine_x <= affine_x_initial;
            affine_offscreen <= 0;
        end else if (affine_x_end) begin
            affine_offscreen <= 1;
        end
    end

    vdp_affine_layer affine(
        .clk(clk),

        .x(affine_x),
        .y(affine_y),

        .pretranslate_x(affine_pretranslate_x),
        .pretranslate_y(affine_pretranslate_y),

        .translate_x(affine_translate_x),
        .translate_y(affine_translate_y),

        .a(affine_a),
        .b(affine_b),
        .c(affine_c),
        .d(affine_d),

        .vram_even_address(affine_vram_address_even),
        .vram_even_data(vram_read_data_even_r),

        .vram_odd_address(affine_vram_address_odd),
        .vram_odd_data(vram_read_data_odd_r),

        .output_pixel(affine_output_pixel)
    );

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

    // convenience functions for address mapping, these could be combined to a single function
    // but the ability to configure BASE_BITS is being removed eventually so not going to bother with that

    function [13:0] tile_base_coarse_to_address;
        input [13:0] tile_base;

        begin
            tile_base_coarse_to_address = {
                tile_base[13:13 - CHAR_BASE_BITS + 1],
                {(14 - CHAR_BASE_BITS){1'b0}}
            };
        end

    endfunction
        
    function [13:0] map_base_coarse_to_address;
        input [13:0] map_base;

        begin
            map_base_coarse_to_address = {
                map_base[13:13 - MAP_BASE_BITS + 1],
                {(14 - MAP_BASE_BITS){1'b0}}
            };
        end

    endfunction

endmodule
