// reset_generator.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module reset_generator #(
    parameter integer DURATION_EXPONENT = 8
) (
    input clk_1x,
    input clk_2x,
    input pll_locked,

    // (TODO: an actual user reset input, presumably from a button or otherwise)

    output reg reset_1x = 1,
    output reg reset_2x = 1
);
    reg pll_locked_r;

    always @(negedge clk_2x) begin
        pll_locked_r <= pll_locked;
    end

    reg [DURATION_EXPONENT:0] counter = 0;
    
    reg reset = 1;

    always @(negedge clk_2x) begin
        if (!pll_locked_r) begin
            counter <= 0;
            reset <= 1;
        end else begin
            if (!counter[DURATION_EXPONENT]) begin
                counter <= counter + 1;
            end else if (!clk_1x) begin
                // ensure that both reset_1x and reset_2x occur on the same rising edge
                reset <= 0;
            end
        end
    end

    always @(posedge clk_1x) begin
        reset_1x <= reset;
    end

    always @(posedge clk_2x) begin
        reset_2x <= reset;
    end

endmodule
