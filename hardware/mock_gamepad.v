// mock_gamepad.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module mock_gamepad(
    input clk,

    // Parallel button inputs
    
    input [11:0] pad_btn,

    // Serial control

    input pad_clk,
    input pad_latch,

    // Serial out

    output [1:0] pad_out
);
    reg pad_clk_r;
    reg [11:0] pad_shift;

    // P1 reading only for now
    assign pad_out[0] = pad_shift[0];
    assign pad_out[1] = 1'b0;

    always @(posedge clk) begin
        if (pad_latch) begin
            pad_shift <= pad_btn;
        end

        if (pad_clk && !pad_clk_r) begin
            pad_shift <= pad_shift >> 1;
        end

        pad_clk_r <= pad_clk;
    end

endmodule
