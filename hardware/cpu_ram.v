// cpu_ram.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module cpu_ram(
    input clk,

    input [13:0] address,
    input cs,
    input write_en,
    input [3:0] wstrb,
    input [31:0] write_data,

    output [31:0] read_data  
);
    wire [7:0] mask_write_en = {
        wstrb[3], wstrb[3],
        wstrb[2], wstrb[2],
        wstrb[1], wstrb[1],
        wstrb[0], wstrb[0]
    };

    spram_256k cpu_ram_0(
        .clk(clk),
        .address(address),
        .write_data(write_data[15:0]),
        .mask(mask_write_en[3:0]),
        .write_en(write_en),
        .cs(cs),
        .read_data(read_data[15:0])
    );

    spram_256k cpu_ram_1(
        .clk(clk),
        .address(address),
        .write_data(write_data[31:16]),
        .mask(mask_write_en[7:4]),
        .write_en(write_en),
        .cs(cs),
        .read_data(read_data[31:16])
    );

endmodule
