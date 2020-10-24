// debouncer.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module debouncer #(
    parameter integer BTN_COUNT = 8
) (
    input clk,
    input reset,

    input [BTN_COUNT - 1:0] btn,

    output reg [BTN_COUNT - 1:0] level,
    output reg [BTN_COUNT - 1:0] trigger,
    output reg [BTN_COUNT - 1:0] released
);
    localparam BTN_WIDTH = BTN_COUNT - 1;

    reg [BTN_WIDTH:0] btn_r [0:1];

    reg [15:0] debounce_counter_common;
    wire debounce_counter_common_tick = debounce_counter_common[15];

    reg [4:0] debounce_counter_button [0:BTN_WIDTH];

    always @(posedge clk) begin
        btn_r[1] <= btn_r[0];
        btn_r[0] <= btn;
    end

    reg [BTN_WIDTH:0] level_r;

    always @(posedge clk) begin
        if (reset) begin
            level <= 0;
            trigger <= 0;
            released <= 0;
        end else begin
            for (i = 0; i < BTN_COUNT; i = i + 1) begin
                if (debounce_counter_button[i][4]) begin
                    level[i] <= btn_r[1][i];
                end

                trigger[i] <= level[i] & ~level_r[i];
                released[i] <= ~level[i] & level_r[i];
                level_r[i] <= level[i];
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            debounce_counter_common <= 0;
        end else begin
            debounce_counter_common <= (debounce_counter_common_tick ? 0 : debounce_counter_common + 1);
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < BTN_COUNT; i = i + 1) begin
                debounce_counter_button[i] <= 0;
            end
        end else begin
            for (i = 0; i < BTN_COUNT; i = i + 1) begin
                if ((btn_r[0][i] == btn_r[1][i])) begin
                    if (debounce_counter_common_tick && !debounce_counter_button[i][4]) begin
                        debounce_counter_button[i] <= debounce_counter_button[i] + 1;
                    end
                end else begin
                    debounce_counter_button[i] <= 0;
                end
            end
        end
    end

    integer i;

endmodule
