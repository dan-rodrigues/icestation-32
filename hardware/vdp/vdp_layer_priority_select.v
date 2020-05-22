// vdp_layer_priority_select.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "layer_encoding.vh"

module vdp_layer_priority_select(
    input [4:0] layer_mask,

    input [7:0] scroll0_pixel,
    input [7:0] scroll1_pixel,
    input [7:0] scroll2_pixel,
    input [7:0] scroll3_pixel,

    input [1:0] sprite_priority,
    input [7:0] sprite_pixel,

    output reg [4:0] prioritized_layer,
    output reg [7:0] prioritized_pixel,
    output reg [1:0] resolved_priority
);
    wire sprite_opaque = layer_mask[LAYER_SPRITES];

    always @* begin
        prioritized_layer = 0;
        resolved_priority = 0;

        // each one of these conditions fits into a single 4LUT so it's not as bad as it might look
        // i.e. for the first one
        // layer_mask[0] & !sprite_opaque & !sprite_priority[0] & !sprite_priority[1]

        if (layer_mask[0]) begin
            prioritized_layer = (!sprite_opaque || sprite_priority < 3) ? LAYER_SCROLL0_OHE : LAYER_SPRITES_OHE;
            // TODO: confirm the below
            // this is probably wrong considering the priority score of a sprite that appears above s0
            resolved_priority = 3;
        end else if (layer_mask[1]) begin
            prioritized_layer = (!sprite_opaque || sprite_priority < 2) ? LAYER_SCROLL1_OHE : LAYER_SPRITES_OHE;
            resolved_priority = 2;
        end else if (layer_mask[2]) begin
            prioritized_layer = (!sprite_opaque || sprite_priority < 1) ? LAYER_SCROLL2_OHE : LAYER_SPRITES_OHE;
            resolved_priority = 1;
        end else if (layer_mask[3]) begin
            prioritized_layer = !sprite_opaque ? LAYER_SCROLL3_OHE : LAYER_SPRITES_OHE;
            resolved_priority = 0;
        end else if (sprite_opaque) begin
            prioritized_layer = LAYER_SPRITES_OHE;
            resolved_priority = sprite_priority;
        end

        // the 0 at the end of this ternary is required to default to color 0 when no others are on screen
        prioritized_pixel =
            prioritized_layer[0] ? scroll0_pixel :
            prioritized_layer[1] ? scroll1_pixel :
            prioritized_layer[2] ? scroll2_pixel :
            prioritized_layer[3] ? scroll3_pixel :
            sprite_opaque ? sprite_pixel : 0;
    end

endmodule
