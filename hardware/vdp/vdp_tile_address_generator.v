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
    reg [2:0] scroll_y_granular_r;
    reg [2:0] raster_y_granular_r;
    reg [15:0] map_data_r;
    reg [13:0] tile_base_address_r;

    always @(posedge clk) begin
        scroll_y_granular_r <= scroll_y_granular;
        raster_y_granular_r <= raster_y_granular;
        map_data_r <= vram_data;
        tile_base_address_r <= tile_base_address;
    end

    wire y_flip = map_data_r[11];
    wire [2:0] tile_row = scroll_y_granular_r + raster_y_granular_r;
    wire [2:0] resolved_tile_row = y_flip ? ~tile_row : tile_row;
    wire [9:0] tile_number = map_data_r[9:0];

    assign tile_address = tile_base_address_r + {tile_number, resolved_tile_row};

endmodule
