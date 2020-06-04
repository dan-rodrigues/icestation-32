// cop_ram.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module cop_ram(
    input clk,

    input [10:0] write_address,
    input [15:0] write_data,
    input write_en,

    input [10:0] read_address,
    output reg [15:0] read_data,
    input read_en
);
    reg [15:0] ram [0:2047];

    always @(posedge clk) begin
        if (write_en) begin
            ram[write_address] <= write_data[15:0];
        end

        if (read_en) begin
            read_data <= ram[read_address];
        end
    end

    wire has_contention =  read_en && write_en && read_address == write_address;

    always @(posedge clk) begin
        if (has_contention) begin
            $display("COP RAM contention: %x", read_address);
        end
    end

endmodule
