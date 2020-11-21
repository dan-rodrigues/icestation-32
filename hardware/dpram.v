// dpram.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module dpram #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDRESS_WIDTH = 8,

    parameter integer DATA_BITS = DATA_WIDTH - 1,
    parameter integer ADDRESS_BITS = ADDRESS_WIDTH - 1
) (
    input clk,

    input write_en,
    input [ADDRESS_BITS:0] write_address,
    input [DATA_BITS:0] write_data,

    input [ADDRESS_BITS:0] read_address,
    output reg [DATA_BITS:0] read_data
);
    localparam WORDS = 1 << ADDRESS_WIDTH;

    reg [DATA_BITS:0] mem [0:WORDS - 1];

    always @(posedge clk) begin
        if (write_en) begin
            mem[write_address] <= write_data;
        end

        read_data <= mem[read_address];
    end

endmodule
