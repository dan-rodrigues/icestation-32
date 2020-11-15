// vdp_sprite_render.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module vdp_sprite_render(
    input clk,
    input restart,

    // line buffer writing
    output reg [9:0] line_buffer_write_address,
    output reg [9:0] line_buffer_write_data,
    output reg line_buffer_write_en,

    // prefetch reading
    input [13:0] vram_base_address,
    output vram_read_data_needs_x_flip,
    output reg [13:0] vram_read_address,
    input [31:0] vram_read_data,
    input vram_data_valid,

    // shared between g_block / x_block attributes
    output reg [7:0] sprite_meta_address,

    // g_block reading
    input [9:0] character,
    input [3:0] palette,
    input [1:0] pixel_priority,

    // x_block reading
    input [9:0] target_x,
    input flip_x,

    // hit list reading
    output reg [8:0] hit_list_read_address,
    input [7:0] sprite_id,
    input [3:0] line_offset,
    input width_select,
    input hit_list_ended
);
    // --- Hit list reading ---

    reg [7:0] sprite_id_r;
    reg [3:0] line_offset_r;
    reg width_select_r;
    reg hit_list_ended_r;

    reg hit_list_data_valid;
    reg hit_list_input_valid;

    wire hit_list_ready = hit_list_input_valid && hit_list_dependency_ready;
    wire hit_list_dependency_ready = x_block_ready;
    wire hit_list_end_reached = x_block_finished;

    always @(posedge clk) begin
        if (hit_list_ready) begin
            sprite_id_r <= sprite_id;
            line_offset_r <= line_offset;
            width_select_r <= width_select;
            hit_list_ended_r <= hit_list_ended | hit_list_read_address[8];
        end
    end

    always @(posedge clk) begin
        if (restart) begin
            hit_list_read_address <= 0;
            hit_list_data_valid <= 0;
            hit_list_input_valid <= 0;
        end else begin
            hit_list_data_valid <= 0;
            hit_list_input_valid <= 1;

            if (hit_list_ready) begin
                hit_list_read_address <= hit_list_read_address + 1;

                hit_list_data_valid <= 1;
                hit_list_input_valid <= 0;
            end
        end
    end

    // --- Sprite x_block / g_block reading ---

    reg [1:0] x_block_loaded;
    reg x_block_data_valid;

    reg x_block_ready;
    reg x_block_finished;

    wire x_block_dependency_ready = vram_fetcher_ready;
    
    // Inputs from hitlist:

    reg [3:0] xb_line_offset;
    reg xb_width_select_r;

    // Outputs to VRAM fetcher:

    // x_block
    reg [9:0] target_x_r;
    reg flip_x_r;
    assign vram_read_data_needs_x_flip = flip_x_r;

    // y_block
    reg width_r;

    // g_block
    reg [9:0] character_r;
    reg [3:0] palette_r;
    reg [1:0] priority_r;

    always @(posedge clk) begin
        if (restart) begin
            x_block_ready <= 1;
            x_block_loaded <= 0;
            x_block_data_valid <= 0;
            x_block_finished <= 0;
        end else if (hit_list_data_valid && hit_list_ended_r) begin
            // finished for this line
            x_block_data_valid <= 0;
            x_block_ready <= 0;

            x_block_finished <= 1;
        end else if (!x_block_finished && !x_block_ready) begin
            if (x_block_loaded && x_block_dependency_ready) begin
                // x_block
                target_x_r <= target_x;
                flip_x_r <= flip_x;

                // y_block
                width_r <= xb_width_select_r;

                // g_block
                character_r <= character;
                palette_r <= palette;
                priority_r <= pixel_priority;

                x_block_data_valid <= 1;
                x_block_ready <= 1;
            end

            x_block_loaded <= 1;
        end else if (!x_block_finished && x_block_ready && hit_list_data_valid) begin
            sprite_meta_address <= sprite_id_r;

            // pipelined for the vram fetcher
            xb_line_offset <= line_offset_r;
            xb_width_select_r <= width_select_r;

            x_block_loaded <= 0;
            x_block_ready <= 0;
            x_block_data_valid <= 0;
        end
    end

    // --- VRAM sprite row fetching ---

    localparam VRAM_READ_LATENCY = 3;
    localparam ROW_OFFSET = 128;

    reg fetching_second_row;
    reg sprite_row_is_valid;
    reg char_x;

    reg [1:0] vram_load_counter;
    reg vram_loading;

    // line needs to be offset *to the next row*
    wire [13:0] char_offset = xb_line_offset[2:0] + xb_line_offset[3] * ROW_OFFSET;
    wire [13:0] sprite_row_vram_address = vram_base_address + character_r * 8 + char_offset;

    // verilator lint_off UNUSED
    reg sprite_finished;
    // verilator lint_on UNUSED

    reg vram_fetcher_ready;

    // pipelined attribtues from earlier fetch
    reg [3:0] vf_palette;
    reg [1:0] vf_priority;
    reg [9:0] vf_target_x;
    reg vf_flip;

    reg [31:0] vf_row_prefetched;

    always @(posedge clk) begin
        if (restart) begin
            vram_loading <= 0;
            sprite_finished <= 0;

            sprite_row_is_valid <= 0;

            vram_fetcher_ready <= 1;

            `debug(vram_load_counter <= 0;)
            `debug(vram_read_address <= 0;)
            `debug(fetching_second_row <= 0;)
        end else begin
            sprite_finished <= 0;
            sprite_row_is_valid <= 0;

            if (vram_loading) begin
                if (vram_load_counter != VRAM_READ_LATENCY) begin
                    vram_load_counter <= vram_load_counter + 1;
                end else if (vram_data_valid)  begin
                    // this can be set before the ready signal since blitter makes its own copy
                    // on the very first step
                    vf_row_prefetched <= vram_read_data;

                    vf_palette <= palette_r;
                    vf_priority <= priority_r;
                    vf_flip <= flip_x_r;

                    vf_target_x <= target_x_r;

                    sprite_row_is_valid <= 1;

                    // 8pixel / 16pixel width handling

                    if (width_r && !fetching_second_row) begin
                        // setup to read next 8px row...
                        vram_read_address <= vram_read_address + 8;
                        vram_load_counter <= 0;

                        // ...and render first 8px in mean time
                        char_x <= 0;
                        fetching_second_row <= 1;
                    end else begin
                        // render second half of 16 pixel sprite if needed
                        char_x <= fetching_second_row;

                        sprite_finished <= 1;
                        vram_loading <= 0;

                        vram_fetcher_ready <= 1;
                    end
                end
            end else if (x_block_data_valid) begin
                vram_read_address <= sprite_row_vram_address;

                vram_load_counter <= 0;
                fetching_second_row <= 0;
                vram_loading <= 1;
                vram_fetcher_ready <= 0;

                sprite_row_is_valid <= 0;
            end
        end
    end

    // --- Blitter ---

    wire blitter_input_valid = sprite_row_is_valid;
    wire [9:0] blitter_x_start = vf_target_x + (char_x ^ vf_flip) * 8;
    wire pixel_is_opaque = (blitter_output_pixel != 0);

    reg [31:0] blitter_row_shifter;
    reg [3:0] blitter_palette;
    reg [1:0] blitter_priority;

    wire blitter_drawing_first_pixel = blitter_input_valid;
    wire [31:0] blitter_output_source = blitter_drawing_first_pixel ? vf_row_prefetched : blitter_row_shifter;

    reg [3:0] blitter_pixel_counter;
    wire blitter_all_pixels_counted = blitter_pixel_counter[3];

    wire [3:0] blitter_output_pixel = blitter_output_source[31:28];
    wire [1:0] blitter_output_priority = (blitter_drawing_first_pixel ? vf_priority : blitter_priority);
    wire [3:0] blitter_output_palette = (blitter_drawing_first_pixel ? vf_palette : blitter_palette);
    
    wire [31:0] blitter_next_shift = {blitter_output_source[27:0], 4'b0000};

    wire blitter_drawing = blitter_input_valid || !blitter_all_pixels_counted;
    wire line_buffer_write_en_nx =  pixel_is_opaque && blitter_drawing;
    wire [9:0] line_buffer_write_address_nx = blitter_input_valid ? blitter_x_start : line_buffer_write_address + 1;

    reg [2:0] blitter_pixel_counter_nx;

    always @* begin
        blitter_pixel_counter_nx = blitter_pixel_counter;

        if (blitter_input_valid) begin
            blitter_pixel_counter_nx = 0;
        end else if (!blitter_all_pixels_counted) begin
            blitter_pixel_counter_nx = blitter_pixel_counter + 1;
        end
    end

    always @(posedge clk) begin
        line_buffer_write_en <= line_buffer_write_en_nx;
        line_buffer_write_data <= {blitter_output_priority, blitter_output_palette, blitter_output_pixel};
        blitter_row_shifter <= blitter_next_shift;
        line_buffer_write_address <= line_buffer_write_address_nx;
        blitter_pixel_counter <= blitter_pixel_counter_nx;

        if (blitter_input_valid) begin
            blitter_palette <= vf_palette;
            blitter_priority <= vf_priority;
        end
    end

endmodule
