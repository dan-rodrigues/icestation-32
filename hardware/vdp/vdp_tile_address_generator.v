// vdp_tile_address_generator.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_tile_address_generator(
    input clk,

    input [2:0] scroll_y_granular,
    input [2:0] raster_y_granular,
    input [15:0] vram_data,
    input [13:0] tile_base_address,

    output [13:0] tile_address
);
    reg [2:0] scroll_y_granular_h;
    reg [2:0] raster_y_granular_h;
    reg [15:0] map_data_h;
    reg [13:0] tile_base_address_h;

    always @(posedge clk) begin
        scroll_y_granular_h <= scroll_y_granular;
        raster_y_granular_h <= raster_y_granular;
        map_data_h <= vram_data;
        tile_base_address_h <= tile_base_address;
    end

    wire is_yflipped = map_data_h[10];
    wire [2:0] tile_row = scroll_y_granular_h + raster_y_granular_h;
    wire [2:0] resolved_tile_row = is_yflipped ? ~tile_row : tile_row;
    wire [8:0] tile_number = map_data_h[8:0];

    assign tile_address = tile_base_address_h + {tile_number, resolved_tile_row};

endmodule
