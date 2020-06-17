// vdp_vga_timing.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_vga_timing #(
    parameter H_ACTIVE_WIDTH = 848,
    parameter V_ACTIVE_HEIGHT = 480,

    parameter H_FRONTPORCH = 16,
    parameter H_SYNC = 112,
    parameter H_BACKPORCH = 112,

    parameter V_FRONTPORCH = 6,
    parameter V_SYNC = 8,
    parameter V_BACKPORCH = 23
) (
    input clk,

    output reg [10:0] raster_x = 0,
    output reg [9:0] raster_y = 0,

    output reg line_ended,
    output reg frame_ended,

    output reg active_line_started,
    output reg active_frame_ended,

    output reg hsync,
    output reg vsync,
    output reg active_display
);
    localparam STATE_FP = 0;
    localparam STATE_SYNC = 1;
    localparam STATE_BP = 2;
    localparam STATE_ACTIVE = 3;

    localparam H_SIZE = H_ACTIVE_WIDTH + H_FRONTPORCH + H_SYNC + H_BACKPORCH;
    localparam V_SIZE = V_ACTIVE_HEIGHT + V_FRONTPORCH + V_SYNC + V_BACKPORCH;

    localparam H_OFFSCREEN_WIDTH = H_SIZE - H_ACTIVE_WIDTH;
    localparam V_OFFSCREEN_HEIGHT = V_SIZE - V_ACTIVE_HEIGHT;

    wire line_ended_nx = x_fsm_nx == STATE_FP && x_fsm == STATE_ACTIVE;
    wire frame_ended_nx = y_fsm_nx == STATE_ACTIVE && y_fsm == STATE_BP && line_ended_nx;
    wire active_frame_ended_nx = line_ended_nx && y_fsm == STATE_ACTIVE && y_fsm_nx == STATE_FP;

    wire hsync_b_nx = x_fsm == STATE_SYNC;
    wire vsync_b_nx = y_fsm == STATE_SYNC;

    wire active_display_nx = y_fsm == STATE_ACTIVE && x_fsm_nx == STATE_ACTIVE;

    wire active_line_started_nx = x_fsm == STATE_FP && x_fsm_nx == STATE_ACTIVE;

    reg [1:0] x_fsm_nx;

    always @* begin
        x_fsm_nx = (raster_x == x_next_count ? x_fsm + 1 : x_fsm);
    end

    reg [1:0] y_fsm_nx;

    always @* begin
        y_fsm_nx = y_fsm;

        if (line_ended_nx) begin
            y_fsm_nx = (raster_y == y_next_count ? y_fsm + 1 : y_fsm);
        end
    end

    reg [1:0] x_fsm = 0;
    reg [1:0] y_fsm = STATE_ACTIVE;

    always @(posedge clk) begin
        x_fsm <= x_fsm_nx;
        y_fsm <= y_fsm_nx;
    end

    reg [10:0] x_next_count, y_next_count;

    // target counts to advance state

    always @* begin
        (* full_case, parallel_case *)
        case (x_fsm)
            STATE_FP: x_next_count = H_FRONTPORCH - 1;
            STATE_SYNC: x_next_count = H_FRONTPORCH + H_SYNC - 1;
            STATE_BP: x_next_count = H_SYNC + H_FRONTPORCH + H_BACKPORCH - 1;
            STATE_ACTIVE: x_next_count = H_SIZE - 1;
        endcase
    end

    always @* begin
        (* full_case, parallel_case *)
        case (y_fsm)
            STATE_FP: y_next_count = V_ACTIVE_HEIGHT + V_FRONTPORCH - 1;
            STATE_SYNC: y_next_count = V_ACTIVE_HEIGHT + V_FRONTPORCH + V_SYNC - 1;
            STATE_BP: y_next_count = V_SIZE - 1;
            STATE_ACTIVE: y_next_count = V_ACTIVE_HEIGHT - 1;
        endcase
    end

    reg [10:0] raster_x_nx;
    reg [9:0] raster_y_nx;

    always @* begin
        raster_x_nx = raster_x + 1;
        raster_y_nx = raster_y;

        if (line_ended_nx) begin
            raster_x_nx = 0;
            raster_y_nx = raster_y + 1;

            if (frame_ended_nx) begin
                raster_y_nx = 0;
            end
        end
    end

    always @(posedge clk) begin
        raster_x <= raster_x_nx;
        raster_y <= raster_y_nx;
    end

    always @(posedge clk) begin
        hsync <= !hsync_b_nx;
        vsync <= !vsync_b_nx;
        active_display <= active_display_nx;
        line_ended <= line_ended_nx;
        frame_ended <= frame_ended_nx;
        active_line_started <= active_line_started_nx;
        active_frame_ended <= active_frame_ended_nx;
    end

`ifdef FORMAL

    reg past_valid = 0;
    reg [1:0] past_counter = 0;

    initial begin
        restrict(reset);
    end

    always @(posedge clk) begin
        if (past_counter < 3) begin
            past_counter <= past_counter + 1;
        end else begin
            past_valid <= 1;
        end

        if (past_counter != 0) begin
            assume(!reset);
        end
    end

    always @(posedge clk) begin
        if (!$past(reset) && past_counter > 2) begin
            assert(active_display == (raster_x > H_OFFSCREEN_WIDTH && raster_y < (V_SIZE - V_OFFSCREEN_HEIGHT)));

            assert(!hsync == ((raster_x >= H_FRONTPORCH) && (raster_x < H_FRONTPORCH + H_SYNC)));
            assert(!vsync == ((raster_y >= V_ACTIVE_HEIGHT + V_FRONTPORCH) && (raster_y < V_ACTIVE_HEIGHT + V_FRONTPORCH + V_SYNC)));

            assert(line_ended_nx == (raster_x == (H_SIZE - 1)));
            assert(line_ended == (raster_x == 0));

            assert(frame_ended_nx == (raster_y == (V_SIZE - 1)));
            assert(active_frame_ended_nx == (raster_y == V_ACTIVE_HEIGHT - 1 && line_ended_nx));
        end
    end

`endif

endmodule
