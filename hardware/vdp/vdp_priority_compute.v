// vdp_priority_compute.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_priority_compute(
    input clk,

    input [7:0] scroll0_pixel,
    input scroll0_is_8bpp,

    input [7:0] scroll1_pixel,
    input [7:0] scroll2_pixel,
    input [7:0] scroll3_pixel,

    input [7:0] sprite_pixel,
    input [1:0] sprite_priority,

    input [4:0] layer_enable,
    input [4:0] layer_mask,

    output reg [7:0] prioritized_pixel,
    output reg [4:0] prioritized_layer,

    output reg [7:0] prioritized_masked_pixel,
    output reg [4:0] prioritized_masked_layer
);

    wire [4:0] layer_opacity = {
        |sprite_pixel[3:0],
        |scroll3_pixel[3:0],
        |scroll2_pixel[3:0],
        |scroll1_pixel[3:0],
        |(scroll0_is_8bpp ? scroll0_pixel[7:0] : scroll0_pixel[3:0])
    };

    wire [4:0] primary_layers = layer_enable & layer_opacity & layer_mask;
    wire [4:0] masked_layers = layer_enable & layer_opacity & ~layer_mask;

    wire [4:0] prioritized_layer_nx;
    wire [7:0] prioritized_pixel_nx;

    wire [4:0] masked_layer_nx;
    wire [7:0] masked_pixel_nx;

    wire [2:0] primary_resolved_priority;
    wire [2:0] masked_resolved_priority;

    vdp_layer_priority_select primary_priority_select(
        .clk(clk),

        .layer_mask(primary_layers),
        .sprite_priority(sprite_priority),

        .scroll0_pixel(scroll0_pixel),
        .scroll1_pixel(scroll1_pixel),
        .scroll2_pixel(scroll2_pixel),
        .scroll3_pixel(scroll3_pixel),
        .sprite_pixel(sprite_pixel),

        .prioritized_layer(prioritized_layer_nx),
        .prioritized_pixel(prioritized_pixel_nx),
        .resolved_priority(primary_resolved_priority)
    );

    vdp_layer_priority_select masked_priority_select(
        .clk(clk),

        .layer_mask(masked_layers),
        .sprite_priority(sprite_priority),

        .scroll0_pixel(scroll0_pixel),
        .scroll1_pixel(scroll1_pixel),
        .scroll2_pixel(scroll2_pixel),
        .scroll3_pixel(scroll3_pixel),
        .sprite_pixel(sprite_pixel),

        .prioritized_layer(masked_layer_nx),
        .prioritized_pixel(masked_pixel_nx),
        .resolved_priority(masked_resolved_priority)
    );

    // if primary layer beats masked layer, force masked layer to 0
    // this lets a higher priority alpha-over layer win over an otherwise prioritised layer
    wire force_masked_layer_off = primary_resolved_priority > masked_resolved_priority;

    always @(posedge clk) begin
        prioritized_layer <= prioritized_layer_nx;
        prioritized_pixel <= prioritized_pixel_nx;

        prioritized_masked_layer <= force_masked_layer_off ? 0 : masked_layer_nx;
        prioritized_masked_pixel <= masked_pixel_nx;
    end 

endmodule
