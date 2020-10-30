// vdp_sprite_raster_collision.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_sprite_raster_collision #(
`ifdef FORMAL
    // This FORMAL condition can applied in a wrapper testbench instead of doing it here
    // the assertions below can then be lifted out of this source since they just assert on outputs anyway
    parameter SPRITES_TOTAL = 16
`else
    parameter SPRITES_TOTAL = 255
`endif
) (
    input clk,
    input restart,

    input [8:0] render_y,

    // sprite attribute data
    input [8:0] sprite_y,
    input [4:0] sprite_height,
    input width_select_in,
    input flip_y,

    // sprite to read attributes for
    output reg [7:0] sprite_test_id,

    // hit list outputs
    output reg [8:0] hit_list_index,
    output reg [7:0] sprite_id,
    output reg [3:0] sprite_y_intersect,
    output reg width_select_out,

    output reg hit_list_write_en,

    output reg finished
);
    localparam READ_LATENCY = 3;

    // changes per line
    reg [8:0] render_y_r;

    // changes per sprite
    reg [8:0] sprite_y_r;
    reg [4:0] sprite_height_r;

    wire ready;

    delay_ffr #(.DELAY(3)) ready_dm (
        .clk(clk),
        .reset(restart),
        .in(1),
        .out(ready)
    );

    wire output_valid;

    delay_ffr #(.DELAY(1)) output_valid_dm (
        .clk(clk),
        .reset(restart),
        .in(ready),
        .out(output_valid)
    );

    wire flip_y_d, width_select_d;

    delay_ffr #(.DELAY(2), .WIDTH(2)) attributes_dm (
        .clk(clk),
        .reset(restart),
        .in({flip_y, width_select_in}),
        .out({flip_y_d, width_select_d})
    );

    wire [4:0] sprite_height_d;

    delay_ffr #(.DELAY(2), .WIDTH(5)) sprite_height_dm (
        .clk(clk),
        .reset(restart),
        .in(sprite_height),
        .out(sprite_height_d)
    );

    reg finished_t;

    reg [8:0] sprite_y_intersect_t;
    reg has_collision, has_collision_t;

    wire [8:0] sprite_y_intersect_nx = render_y_r - sprite_y_r;
    wire has_collision_nx = sprite_y_intersect_nx < sprite_height_r;
    wire hit_list_needs_increment = ready && (has_collision_t || will_finish);

    wire finished_nx = finished_t || all_sprites_processed;
    wire will_finish = !finished_t && finished_nx;

    wire all_sprites_processed = (sprite_id == (SPRITES_TOTAL - READ_LATENCY + 1)) && output_valid;
    wire hit_list_full = hit_list_index == 9'h100;

    wire collision_needs_writing = (ready && has_collision_t && !finished_t);
    wire hit_list_terminator_needs_writing = (!hit_list_full && finished_t);
    wire hit_list_write_en_nx = collision_needs_writing || hit_list_terminator_needs_writing;

    always @(posedge clk) begin
        if (restart) begin
            finished <= 0;
            finished_t <= 0;
            hit_list_write_en <= 0;

            // probably not needed, account for any latency and remove
            // this is already registered in parent vdp module
            render_y_r <= render_y;
            
            // -1 for preincrement index
            hit_list_index <= -1;

            sprite_test_id <= 0;
            sprite_id <= -(READ_LATENCY) - 1;
        end else if (!finished) begin
            hit_list_index <= hit_list_needs_increment ? hit_list_index + 1 : hit_list_index;
            sprite_test_id <= sprite_test_id + 1;
            sprite_id <= sprite_id + 1;

            hit_list_write_en <= hit_list_write_en_nx;

            finished_t <= finished_nx;
            finished <= finished_t;
        end else begin
            hit_list_write_en <= 0;
        end
    end

    always @(posedge clk) begin
        // register inputs from y_block
        sprite_y_r <= sprite_y;
        sprite_height_r <= sprite_height;

        // register comparator result from previously read y_block
        sprite_y_intersect_t <= sprite_y_intersect_nx;
        has_collision_t <= has_collision_nx;

        // move the above registered result to the output for this module
        sprite_y_intersect <= flip_y_d ? sprite_height_d - sprite_y_intersect_t - 1 : sprite_y_intersect_t;
        has_collision <= has_collision_t;
        width_select_out <= width_select_d;
    end

`ifdef FORMAL

    reg past_valid = 0;
    integer valid_count = 0;

    initial begin
        restrict(restart);
    end

    always @(posedge clk) begin
        if (past_valid) begin
            assume(!restart);
        end
    end

    always @(posedge clk) begin
        if (past_valid) begin
            if ($past(restart)) begin
                assert(!output_valid);
            end
        end

        past_valid <= 1;

        if (!restart) begin
            valid_count <= valid_count + 1;
        end else begin
            valid_count <= 0;
        end
    end

    // expectations when evaluation just started

    always @(posedge clk) begin
        if (past_valid) begin
            if ($fell(restart)) begin
                assert(sprite_test_id == 8'h00);
                assert(!finished);
                assert(!output_valid);
                assert(!hit_list_write_en);
            end
        end
    end

    // expectations when evaluation just finished
    
    always @(posedge clk) begin
        if (past_valid) begin
            if ($rose(finished)) begin
                assert(output_valid);
                assert(hit_list_write_en);
            end
        end
    end

    always @(posedge clk) begin
        if (past_valid) begin
            if ($rose(output_valid) && has_collision) begin
                if (has_collision) begin
                    // it's PRE increment pointer so it's only 00 on the first collision
                    assert(hit_list_index == 8'h00);
                    assert(hit_list_write_en);
                end else begin
                    // and it should be ff (or -1) if there was no collision initially
                    assert(hit_list_index == 8'hff);
                    assert(!hit_list_write_en);
                end 
            end
        end
    end

    // temporary variables for use with the below assertions

    integer sprite_pos, raster_pos;
    integer sprite_top;
    integer flipped_y_intersect;

    localparam PIPE_DELAY = 3;

    // the pipeline adds latency of PIPE_DELAY cycles so these are added for convenience

    reg [8:0] input_sprite_y;
    reg [8:0] input_render_y;
    reg [7:0] input_sprite_height;
    reg input_flip_y;
    reg input_width_select_in;

    always @(posedge clk) begin
        input_sprite_y = $past(sprite_y, PIPE_DELAY - 1);
        input_render_y = $past(render_y, PIPE_DELAY - 1);
        input_sprite_height = $past(sprite_height, PIPE_DELAY - 1);
        input_flip_y = $past(flip_y, PIPE_DELAY - 1);
        input_width_select_in = $past(width_select_in, PIPE_DELAY - 1);
    end

    always @(posedge clk) begin
        if (valid_count > (PIPE_DELAY + 1)) begin
            sprite_top = input_sprite_y;
            sprite_pos = input_sprite_y + input_sprite_height;
            raster_pos = input_render_y;
            flipped_y_intersect = (sprite_y_intersect ^ {4{input_flip_y}}) % input_sprite_height;

            // a) cases where there IS collision
            if (!finished && output_valid && has_collision) begin
                // intersect should in be in range (0..<sprite_height)
                assert(flipped_y_intersect < input_sprite_height);

                // raster >= sprite.top
                // assert($past(render_y, PIPE_DELAY) >= $past(sprite_y, PIPE_DELAY));

                // sprite.bottom > raster
                assert(sprite_pos > raster_pos);

                assert(width_select_out == input_width_select_in);

                assert(hit_list_write_en);
            end

            // b) cases where there is NO collision:
            if (!finished && output_valid && !has_collision) begin
                assert(raster_pos < sprite_top
                    || raster_pos >= sprite_pos);

                assert(!hit_list_write_en);
            end
        end

        // render_y is not supposed to change in the middle of a sprite list evaluation
        if (!restart) begin
            assume($stable(render_y));
        end
    end

`endif

endmodule
