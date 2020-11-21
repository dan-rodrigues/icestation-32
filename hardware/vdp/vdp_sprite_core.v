// vdp_sprite_core.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_sprite_core #(
    parameter [0:0] REGSTER_RENDER_X = 0
) (
    input clk,
    input start_new_line,

    input [9:0] render_x,
    input [8:0] render_y,

    input [7:0] meta_address,
    input [15:0] meta_write_data,
    input [2:0] meta_block_select,
    input meta_we,

    input [13:0] vram_base_address,
    output vram_read_data_needs_x_flip,
    output [13:0] vram_read_address,
    input [31:0] vram_read_data,
    input vram_data_valid,

    output [7:0] pixel,
    output [1:0] pixel_priority
);
    reg start_new_line_r;

    always @(posedge clk) begin
        start_new_line_r <= start_new_line;
    end

    // yosys hangs on the "make count" target with x_r removed:
    // > 28.39. Executing DFF2DFFE pass (transform $dff to $dffe where applicable).
    // ...
    // need to investigate this, leaving this commented out until then
    // It would save on LCs though
    // SPRITE_X_INITIAL needs to have an additional -1 if this change is made

    reg [9:0] render_x_r;

    generate
        if (REGSTER_RENDER_X) begin
            always @(posedge clk) begin
                render_x_r <= render_x;
            end
        end else begin
            always @* begin
                render_x_r = render_x;
            end
        end
    endgenerate

    // --- Metadata block writing ---

    assign x_block_we = meta_block_select[0] && meta_we;
    assign y_block_we = meta_block_select[1] && meta_we;
    assign g_block_we = meta_block_select[2] && meta_we;

    // --- y_block ---

    // ----whYy yyyyyyyy
    // y: sprite y (9 bits, could be extended to 10bits on another platform)
    // h: height select (8 or 16)
    // w: width select (8 or 16)
    // Y: Y flip - the advantage of doing it here is that it frees up bits in other attribute blocks
    // -: unused

    reg [15:0] y_block [0:255];

    reg [15:0] y_block_data_out;
    wire [7:0] y_block_read_address;

    wire y_block_we;

    always @(posedge clk) begin
        if (y_block_we) begin
            y_block[meta_address] <= meta_write_data;
        end

        y_block_data_out <= y_block[y_block_read_address];
    end

    // --- g_block ---

    // ppppPPgg gggggggg
    // g: character #
    // p: palette
    // P: priority

    reg [15:0] g_block [0:255];

    reg [15:0] g_block_data_out;
    wire [7:0] g_block_read_address;

    wire g_block_we;

    always @(posedge clk) begin
        if (g_block_we) begin
            g_block[meta_address] <= meta_write_data;
        end

        g_block_data_out <= g_block[g_block_read_address];
    end

    // --- x_block ---

    // -----Xxx xxxxxxxx
    // x: x position
    // X: flip
    // -: unused

    reg [15:0] x_block [0:255];

    reg [15:0] x_block_data_out;
    wire [7:0] x_block_read_address;

    wire x_block_we;

    always @(posedge clk) begin
        if (x_block_we) begin
            x_block[meta_address] <= meta_write_data;
        end
        
        x_block_data_out <= x_block[x_block_read_address];
    end

    // --- Hit list (private) ---

    // layout:
    // T--wcccc iiiiiiii
    // i: sprite ID
    // c: collision Y within sprite (0-15, 16px sprite tall is the max)
    // w: width select (8 or 16)
    // T: terminator bit
    // -: unused

    wire hit_list_select = render_y[0];

    wire hit_list_ended = hit_list_render_read_data[15];

    wire [15:0] hit_list_render_read_data = hit_list_select ?
        hit_list_read_data_1 : hit_list_read_data_0;

    wire [7:0] hit_list_read_address;

    wire [7:0] hit_list_write_address;
    wire hit_list_write_en;
    wire [15:0] hit_list_data_in;

    wire [15:0] hit_list_read_data_0;
    wire [15:0] hit_list_read_data_1;

    dpram #(
        .ADDRESS_WIDTH(8),
        .DATA_WIDTH(16)
    ) hit_list [1:0] (
        .clk(clk),

        .write_en({2{hit_list_write_en}} & {~hit_list_select, hit_list_select}),
        .write_address(hit_list_write_address),
        .write_data(hit_list_data_in),

        .read_address(hit_list_read_address),
        .read_data({hit_list_read_data_1, hit_list_read_data_0})
    );

    // --- Line buffers ---

    // Selected buffer toggles every line
    wire line_buffer_select = !render_y[0];

    wire [9:0] line_buffer_write_address;
    wire [9:0] line_buffer_write_data;
    wire line_buffer_write_en;

    wire [9:0] line_buffer_clear_write_address;
    wire line_buffer_clear_en;

    wire [19:0] line_buffer_data_out;
    wire [9:0] line_buffer_data_out_0 = line_buffer_data_out[9:0];
    wire [9:0] line_buffer_data_out_1 = line_buffer_data_out[19:10];

    genvar i;
    generate
        for (i = 0; i < 2; i = i + 1) begin : line_buffer_gen
            wire select = line_buffer_select ^ i;

            wire [9:0] write_address = select ? line_buffer_write_address : line_buffer_clear_write_address;
            wire [9:0] write_data = select ? line_buffer_write_data : line_buffer_clear_data_in;
            wire write_en = select ? line_buffer_write_en : line_buffer_clear_en;

            wire [9:0] read_data;
            assign line_buffer_data_out[i * 10+:10] = read_data;

            dpram #(
                .ADDRESS_WIDTH(10),
                .DATA_WIDTH(10)
            ) line_buffer (
                .clk(clk),

                .write_en(write_en),
                .write_address(write_address),
                .write_data(write_data),

                .read_address(line_buffer_display_read_address),
                .read_data(read_data)
            );
        end
    endgenerate
    
    // Clearing:

    reg [9:0] line_buffer_previous_read_address;
    assign line_buffer_clear_write_address = line_buffer_previous_read_address;
    wire [9:0] line_buffer_clear_data_in = 10'b0;

    assign line_buffer_clear_en = 1;

    always @(posedge clk) begin
        line_buffer_previous_read_address <= line_buffer_display_read_address;
    end
    
    // Reading:

    wire [9:0] line_buffer_display_read_address;
    wire [9:0] line_buffer_display_data;

    // data to read from active buffer
    assign line_buffer_display_data = line_buffer_select ?
        line_buffer_data_out_1 : line_buffer_data_out_0;

    assign line_buffer_display_read_address = render_x_r;

    // These are registered in the sprite_line_buffer module

    // 8bit palette index
    assign pixel = line_buffer_display_data[7:0];
    // 2bit priority
    assign pixel_priority = line_buffer_display_data[9:8];

    // there is no competing access from blitter / prefetch
    assign hit_list_read_address = hit_list_blitter_read_address;

    // --- Sprite raster-collision testing ---

    // attribute extraction from y_block data

    wire [8:0] sprite_y_read = y_block_data_out[8:0];
    wire [4:0] sprite_selected_height = y_block_data_out[10] ? 16 : 8;
    wire sprite_flip_y = y_block_data_out[9];
    wire sprite_width_select = y_block_data_out[11];

    assign hit_list_data_in[14:13] = 0;
    
    vdp_sprite_raster_collision collision(
        .clk(clk),
        .restart(start_new_line_r),

        .render_y(render_y),

        // reading
        .sprite_y(sprite_y_read),
        .sprite_test_id(y_block_read_address),
        .sprite_height(sprite_selected_height),
        .flip_y(sprite_flip_y),
        .width_select_in(sprite_width_select),

        // writing
        .sprite_y_intersect(hit_list_data_in[11:8]),
        .sprite_id(hit_list_data_in[7:0]),
        .hit_list_index(hit_list_write_address),
        .finished(hit_list_data_in[15]),
        .width_select_out(hit_list_data_in[12]),
        .hit_list_write_en(hit_list_write_en)
    );

    // --- Sprite render ---

    wire [7:0] hit_list_blitter_read_address;
    wire [7:0] blitter_sprite_meta_read_address;

    // these happen to be the same read address, at the same time
    assign g_block_read_address = blitter_sprite_meta_read_address;
    assign x_block_read_address = blitter_sprite_meta_read_address;

    vdp_sprite_render render(
        .clk(clk),
        .restart(start_new_line_r),

        .vram_base_address(vram_base_address),
        .vram_read_address(vram_read_address),
        .vram_read_data_needs_x_flip(vram_read_data_needs_x_flip),
        .vram_read_data(vram_read_data),
        .vram_data_valid(vram_data_valid),

        .sprite_meta_address(blitter_sprite_meta_read_address),

        .character(g_block_data_out[9:0]),
        .palette(g_block_data_out[15:12]),
        .pixel_priority(g_block_data_out[11:10]),

        .target_x(x_block_data_out[9:0]),
        .flip_x(x_block_data_out[10]),

        .line_buffer_write_address(line_buffer_write_address),
        .line_buffer_write_data(line_buffer_write_data),
        .line_buffer_write_en(line_buffer_write_en),
        
        .hit_list_read_address(hit_list_blitter_read_address),
        .sprite_id(hit_list_render_read_data[7:0]),
        .line_offset(hit_list_render_read_data[11:8]),
        .width_select(hit_list_render_read_data[12]),
        .hit_list_ended(hit_list_ended)
    );

endmodule
