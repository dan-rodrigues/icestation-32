// vdp_map_address_generator.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_map_address_generator #(
    parameter [0:0] REGISTERED_INPUTS = 0
) (
    input clk,

    input [9:0] scroll_y,
    input [6:0] scroll_x_coarse,

    input [9:0] raster_y,
    input [6:0] raster_x_coarse,

    input [14:0] map_base_address,
    input [7:0] stride,

    output [14:0] map_address_16b
);
    reg [9:0] scroll_y_r;
    reg [6:0] scroll_x_coarse_r;
    reg [9:0] raster_y_r;
    reg [6:0] raster_x_coarse_r;
    reg [14:0] map_base_address_r;
    reg [7:0] stride_r;

    generate
        if (REGISTERED_INPUTS) begin
            always @(posedge clk) begin
                scroll_y_r <= scroll_y;
                scroll_x_coarse_r <= scroll_x_coarse;
                raster_y_r <= raster_y;
                raster_x_coarse_r <= raster_x_coarse;
                map_base_address_r <= map_base_address;
                stride_r <= stride;
            end
        end else begin
            always @* begin
                scroll_y_r = scroll_y;
                scroll_x_coarse_r = scroll_x_coarse;
                raster_y_r = raster_y;
                raster_x_coarse_r = raster_x_coarse;
                map_base_address_r = map_base_address;
                stride_r = stride;
            end
        end
    endgenerate

    wire [6:0] column = scroll_x_coarse_r + raster_x_coarse_r;
    wire [5:0] row = (scroll_y_r + raster_y_r) >> 3;

    // cheap, only requires +1 LUT
    wire map_page_select = (stride_r & 8'h80) && column[6];

    assign map_address_16b = {map_page_select, row, column[5:0]} + map_base_address_r;

endmodule

    // Most of these are probably the "+ map_base_address" which gets optimised when 64 or 128 is used
    // Number of cells:                 54
    //   SB_CARRY                       27
    //   SB_LUT4                        27

    // this is the nicer alternative but expensive
    // not as nice of an API though

    // always @* begin
    //  if (stride & 8'h80) begin
    //      //breaks, as expected
    //      map_address = {row, column} + map_base_address;
    //  end else begin
    //      // works, as before
    //      map_address = {row, column[5:0]} + map_base_address;
    //  end
    // end

     //   Number of cells:                 90
     //     SB_CARRY                       40
     //     SB_LUT4                        50

