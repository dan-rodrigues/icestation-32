// vdp_layer_priority_select.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "layer_encoding.vh"

module vdp_layer_priority_select(
    input clk,

    input [4:0] layer_mask,

    input [7:0] scroll0_pixel,
    input [7:0] scroll1_pixel,
    input [7:0] scroll2_pixel,
    input [7:0] scroll3_pixel,

    input [1:0] sprite_priority,
    input [7:0] sprite_pixel,

    output reg [4:0] prioritized_layer,
    output reg [7:0] prioritized_pixel,
    output reg [2:0] resolved_priority
);
    wire sprite_opaque_r = layer_mask_r[`LAYER_SPRITES];

    // 1a: Register inputs for output (2.)

    reg [7:0] scroll_pixel_r [0:3];
    reg [7:0] sprite_pixel_r;
    reg [1:0] sprite_priority_r;
    reg [4:0] layer_mask_r;

    always @(posedge clk) begin
        scroll_pixel_r[0] <= scroll0_pixel;
        scroll_pixel_r[1] <= scroll1_pixel;
        scroll_pixel_r[2] <= scroll2_pixel;
        scroll_pixel_r[3] <= scroll3_pixel;

        sprite_pixel_r <= sprite_pixel;
        sprite_priority_r <= sprite_priority;

        layer_mask_r <= layer_mask;
    end

    // 1b: Determine priority of layers / sprites

    wire [2:0] sprite_priority_score = {sprite_priority_r, 1'b1};
    wire [2:0] layer_priority_score = {layer_encoded_priority, 1'b0};
    reg [1:0] layer_encoded_priority;
    reg [3:0] layer_prioritized_ohe;

    always @(posedge clk) begin
        // if (layer_mask[3]) begin...
        layer_encoded_priority <= 0;
        layer_prioritized_ohe <= `LAYER_SCROLL3_OHE; 

        if (layer_mask[2]) begin
            layer_encoded_priority <= 1;
            layer_prioritized_ohe <= `LAYER_SCROLL2_OHE;
        end
        if (layer_mask[1]) begin
            layer_encoded_priority <= 2;
            layer_prioritized_ohe <= `LAYER_SCROLL1_OHE;
        end
        if (layer_mask[0]) begin
            layer_encoded_priority <= 3;
            layer_prioritized_ohe <= `LAYER_SCROLL0_OHE;
        end
    end

    // 2a: Use above priorities to select the topmost pixel

    always @* begin
        if (sprite_opaque_r && (sprite_priority_score > layer_priority_score)) begin
            prioritized_layer = `LAYER_SPRITES_OHE;
            resolved_priority = sprite_priority_score;
        end else if (|layer_mask_r[3:0]) begin
            prioritized_layer = layer_prioritized_ohe;
            resolved_priority = layer_priority_score;
        end else begin
            prioritized_layer = 0;
            resolved_priority = 0;
        end
    end

    // 2b: Output pixel according to topmost pixel using the outputs from above 

    always @* begin
        // 0 at the end of this ternary is required to default to color 0 when no others are on screen
        prioritized_pixel =
            prioritized_layer[0] ? scroll_pixel_r[0] :
            prioritized_layer[1] ? scroll_pixel_r[1] :
            prioritized_layer[2] ? scroll_pixel_r[2] :
            prioritized_layer[3] ? scroll_pixel_r[3] :
            sprite_opaque_r ? sprite_pixel_r : 0;
    end

endmodule
