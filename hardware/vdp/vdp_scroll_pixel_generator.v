// vdp_scroll_pixel_generator.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_scroll_pixel_generator #(
    parameter STAGE_PIXEL_ROW = 1
) (
    input clk,
    input [2:0] scroll_x_granular,
    input [2:0] raster_x_granular,
    input [31:0] pixel_row,
    input [3:0] palette_number,

    input tile_row_load_enable,
    input meta_load_enable,
    input shifter_preload_load_enable,

    output reg [7:0] pixel
);

    reg [31:0] pixel_row_preloaded;
    reg [31:0] output_pixel_row_t;
    reg [31:0] output_pixel_row;
    
    reg [3:0] output_palette_number;
    reg [3:0] palette_number_preloaded;
    reg [3:0] output_palette_number_t;

    wire [7:0] pixel_nx = {output_palette_number, output_pixel_row[31:28]};

    always @(posedge clk) begin
        pixel <= pixel_nx;
    end

    always @(posedge clk) begin
        if (STAGE_PIXEL_ROW && tile_row_load_enable) begin
            pixel_row_preloaded <= pixel_row;
        end

        if (meta_load_enable) begin
            palette_number_preloaded <= palette_number;
        end
    end

    always @(posedge clk) begin
        if (shifter_preload_load_enable) begin
            output_pixel_row_t <= STAGE_PIXEL_ROW ? pixel_row_preloaded : pixel_row;
            output_palette_number_t <= palette_number_preloaded;
        end
    end

    always @(posedge clk) begin
        if (~(scroll_x_granular) == raster_x_granular) begin
            output_pixel_row <= output_pixel_row_t;
            output_palette_number <= output_palette_number_t;
        end else begin
            output_pixel_row <= {output_pixel_row[27:0], 4'b0000};
        end
    end

endmodule
