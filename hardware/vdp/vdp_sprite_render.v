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
    output reg [12:0] line_buffer_write_data,
    output reg line_buffer_write_en,

    // prefetch reading
    input [13:0] vram_base_address,
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
    // verilator lint_off UNUSED
    reg finished;
    // verilator lint_on UNUSED

    wire hit_list_end_reached = x_block_finished;

    always @(posedge clk) begin
        if (restart) begin
            finished <= 0;
        end else if (hit_list_end_reached) begin
            finished <= 1;
        end
    end

    // --- hit list reading ---

    reg [7:0] sprite_id_r;
    reg [3:0] line_offset_r;
    reg width_select_r;
    reg hit_list_ended_r;

    reg hit_list_data_valid;

    reg hit_list_input_valid;
    wire hit_list_ready = hit_list_input_valid && hit_list_dependency_ready;

    wire hit_list_dependency_ready = x_block_ready;

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

`ifdef LOG_SPRITES

    always @(posedge clk) begin
        if (!restart && hit_list_data_valid && !finished) begin
            if (hit_list_ended_r) begin
                $display("BLIT: hit list end reached [%h]",
                    hit_list_read_address
                );
            end else begin
                $display("BLIT: hit list data in: (sprite %h, row: %h) = [%h]",
                    sprite_id_r,
                    line_offset_r,
                    hit_list_read_address
                );
            end
        end
    end

`endif

    // --- Sprite x_block / g_block reading ---

    localparam META_READ_LATENCY = 1;

    // pipelines from hit_list
    reg [7:0] xb_line_offset;
    reg xb_width_select_r;

    // FIXME: separate relevant bits instead...

    // x_block
    reg [9:0] target_x_r;
    reg flip_x_r;

    // g_block
    reg [9:0] character_r;
    reg [3:0] palette_r;
    reg [1:0] priority_r;

    reg [1:0] x_block_load_counter;
    reg x_block_data_valid;

    reg x_block_ready;
    reg x_block_finished;

    wire x_block_dependency_ready = vram_fetcher_ready;

    always @(posedge clk) begin
        if (restart) begin
            x_block_ready <= 1;
            x_block_load_counter <= 0;
            x_block_data_valid <= 0;
            x_block_finished <= 0;
        end else if (hit_list_data_valid && hit_list_ended_r) begin
            // finished for this line
            x_block_data_valid <= 0;
            x_block_ready <= 0;

            x_block_finished <= 1;
        end else if (!x_block_finished && !x_block_ready) begin
            // not ready means we're loading
            if (x_block_load_counter > 0) begin
                x_block_load_counter <= x_block_load_counter - 1;
            end else begin
                // load is done, see if consumer is ready
                if (x_block_dependency_ready) begin
                    // x_block
                    target_x_r <= target_x;
                    flip_x_r <= flip_x;
                    // g_block
                    character_r <= character;
                    palette_r <= palette;
                    priority_r <= pixel_priority;

                    x_block_data_valid <= 1;
                    x_block_ready <= 1;
                end
            end
        end else if (!x_block_finished && x_block_ready && hit_list_data_valid) begin
            sprite_meta_address <= sprite_id_r;

            // pipelined for the vram fetcher
            xb_line_offset <= line_offset_r;
            xb_width_select_r <= width_select_r;

            x_block_load_counter <= META_READ_LATENCY;

            x_block_ready <= 0;
            x_block_data_valid <= 0;
        end
    end

`ifdef LOG_SPRITES

    always @(posedge clk) begin
        if (!restart && !finished && x_block_data_valid) begin
            $display("BLIT: x block data in: (sprite %h, x: %h) = [%h]",
                sprite_id_r,
                x_block_read_data_r,
                hit_list_read_address
            );
        end
    end

`endif

    // --- VRAM sprite row fetching ---

    // 8 since that's the spacing between rows
    // (can fine tune later)
    // this shouldn't need to be high
    localparam VRAM_READ_LATENCY = 3; // should be 3 but faster blitter wrecks it
    localparam ROW_OFFSET = 128;

    reg fetching_second_row;
    reg sprite_row_is_valid;
    reg char_x;

    // FIXME: can use input instead of deriving here
    reg [3:0] vram_load_counter;
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
                // FIXME: use actual signal from vram sequencer outside
                // this would save the logic cost from repeating it here
                // - this would also allow setting the vram advance *in advance* earlier if
                if (vram_load_counter > 0) begin
                    vram_load_counter <= vram_load_counter - 1;
                end else if (vram_data_valid)  begin
                    // this can be set before the ready signal since blitter makes its own copy
                    // on the very first step
                    vf_row_prefetched <= vram_read_data;

                    vf_palette <= palette_r;
                    vf_priority <= priority_r;

                    vf_target_x <= target_x_r;
                    vf_flip <= flip_x_r;

                    sprite_row_is_valid <= 1;

                    // 8pixel / 16pixel width handling

                    if (xb_width_select_r && !fetching_second_row) begin
                        // setup to read next 8px row...
                        vram_read_address <= vram_read_address + 8;
                        vram_load_counter <= VRAM_READ_LATENCY;

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

                vram_load_counter <= VRAM_READ_LATENCY;
                fetching_second_row <= 0;
                vram_loading <= 1;
                vram_fetcher_ready <= 0;

                sprite_row_is_valid <= 0;
            end
        end
    end

`ifdef LOG_SPRITES

    // FIXME: noisy
    always @(posedge clk) begin
        if (!restart && sprite_row_is_valid && !finished) begin
            $display("BLIT: prefetch data in: (row: %h) = [%h]",
                vf_row_prefetched,
                vram_read_address
            );
        end
    end

`endif

    // --- blitter ---

    wire blitter_input_valid = sprite_row_is_valid;
    wire [9:0] blitter_x_start = vf_target_x + (char_x ^ vf_flip) * 8;
    wire pixel_is_opaque = (blitter_output_pixel != 0);

    reg [31:0] blitter_row_shifter;
    reg [3:0] blitter_palette;
    reg [1:0] blitter_priority;

    wire blitter_drawing_first_pixel = blitter_input_valid;
    wire [31:0] blitter_output_source = blitter_drawing_first_pixel ? vf_row_prefetched : blitter_row_shifter;

    reg [2:0] blitter_pixel_counter;

    wire [3:0] blitter_output_pixel = (vf_flip ? blitter_output_source[3:0] : blitter_output_source[31:28]);
    wire [1:0] blitter_output_priority = (blitter_drawing_first_pixel ? vf_priority : blitter_priority);
    wire [3:0] blitter_output_palette = (blitter_drawing_first_pixel ? vf_palette : blitter_palette);
    
    wire [31:0] blitter_next_shift = (vf_flip ? {4'b0000, blitter_output_source[31:4]} : {blitter_output_source[27:0], 4'b0000});

    wire blitter_drawing = blitter_input_valid || blitter_pixel_counter > 0;
    wire line_buffer_write_en_nx =  pixel_is_opaque && blitter_drawing;
    wire [9:0] line_buffer_write_address_nx = blitter_input_valid ? blitter_x_start : line_buffer_write_address + 1;

    wire [2:0] blitter_pixel_counter_nx;

    always @* begin
        blitter_pixel_counter_nx = 0;

        if (blitter_input_valid) begin
            blitter_pixel_counter_nx = 7;
        end else if (blitter_pixel_counter > 0) begin
            blitter_pixel_counter_nx = blitter_pixel_counter - 1;
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

// some simple metrics to measure performance
// cleanup for nicer toggleable logging

`ifdef LOG_SPRITES

    localparam FILTER_EMPTY_LINES = 1;

    wire blitter_finished = blitter_pixel_counter == 0;
    reg blitter_finished_d;

    integer cycles_between_sprite = 0;
    integer cycles_for_all_sprites = 0;

    integer sprites_rendered = 0;

    always @(posedge clk) begin
        blitter_finished_d <= blitter_finished;
    end

    always @(posedge clk) begin
        // this works for the time being since blitter is idle until the valid data comes in
        if (blitter_finished && !blitter_finished_d) begin
            if (!FILTER_EMPTY_LINES || sprites_rendered > 0) begin
                $display("BLITTER completed sprite row in %d cycles", cycles_between_sprite);
            end

            cycles_between_sprite = 0;
            sprites_rendered = sprites_rendered + 1;
        end

        if (sprite_finished) begin
            $display("completed entire sprite");
        end

        if (finished) begin
            if (!FILTER_EMPTY_LINES || sprites_rendered > 0) begin
                // $display("BLITTER completed %d sprites in %d cycles @ %t",
                //  sprites_rendered,
                //  cycles_for_all_sprites,
                //  $time());
                // $display("");
            end

            cycles_for_all_sprites = 0;
            sprites_rendered = 0;
        end

        // should be at the top
        if (restart && !finished) begin
            // $display("BLITTER out of time! sprites rendered: %d", sprites_rendered);
            // $display("");
        end else if (restart) begin
            cycles_between_sprite = 0;
            cycles_for_all_sprites = 0;
            sprites_rendered = 0;
        end else begin
            cycles_between_sprite = cycles_between_sprite + 1;
            cycles_for_all_sprites = cycles_for_all_sprites + 1;
        end
    end

`endif

`ifdef LOG_SPRITES

    // FIXME: noisy
    always @(posedge clk) begin
        if (!restart && blitter_input_valid && !finished) begin
            if (line_buffer_we) begin
                $display("BLIT: write to line buffer: [%h] = %h",
                    line_buffer_write_address,
                    line_buffer_write_data
                );
            end

            if (blitter_finished) begin
                $display("BLIT: sprite FINISHED");
            end else begin
                $display("BLIT: blitter using input:");
                $display("- row: %h", vf_row_prefetched);
                $display("- x start: %h", blitter_x_start);
            end
        end
    end

`endif

endmodule
