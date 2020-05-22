// delay_ff.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

// verilator lint_save
// verilator lint_off DECLFILENAME

module delay_ff #(
    parameter DELAY = 1,
    parameter WIDTH = 1
) (
    input clk,

    input [WIDTH-1:0] in,
    output [WIDTH-1:0] out
);
    delay_ffr #(
        .DELAY(DELAY),
        .WIDTH(WIDTH)
    ) ffr (
        .clk(clk),
        .reset(0),

        .in(in),
        .out(out)
    );

endmodule


module delay_ffr #(
    parameter DELAY = 1,
    parameter WIDTH = 1
) (
    input clk,
    input reset,

    input [WIDTH-1:0] in,
    output [WIDTH-1:0] out
);

    reg [WIDTH-1:0] r [0:DELAY];

    assign out = r[DELAY-1];

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < DELAY; i = i + 1) begin
                r[i] <= 0;
            end
        end else begin
            r[0] <= in;

            if (DELAY > 1) begin
                for (i = 1; i < DELAY; i = i + 1) begin
                    r[i] <= r[i - 1];
                end
            end
        end
    end

endmodule

// verilator lint_restore
