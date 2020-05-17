// vdp_sprite_line_buffer.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_sprite_line_buffer(
    input clk,

    input [9:0] read_address,
    output reg [11:0] read_data,

    input [9:0] write_address,
    input [11:0] write_data,
    input write_en
);
    // had issues with inferring this with the irregular sized memory
    // this will be contained in this wrapper module until that's sorted
    reg [7:0] ram0 [0:1023];
    reg [3:0] ram1 [0:1023];
    
    always @(posedge clk) begin
        if (write_en) begin
            ram0[write_address] <= write_data[7:0];
            ram1[write_address] <= write_data[11:8];
        end

        read_data[7:0] <= ram0[read_address];
        read_data[11:8] <= ram1[read_address];
    end

endmodule
