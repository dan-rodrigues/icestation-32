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

    SB_SPRAM256KA cpu_ram_0(
        .ADDRESS(address),
        .DATAIN(write_data[15:0]),
        .MASKWREN(mask_write_en[3:0]),
        .WREN(write_en),
        .CHIPSELECT(cs),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(read_data[15:0])
    );

    SB_SPRAM256KA cpu_ram_1(
        .ADDRESS(address),
        .DATAIN(write_data[31:16]),
        .MASKWREN(mask_write_en[7:4]),
        .WREN(write_en),
        .CHIPSELECT(cs),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(read_data[31:16])
    );

endmodule
