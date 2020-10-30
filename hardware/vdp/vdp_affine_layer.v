// vdp_affine_layer.v
//
// Copyright (C) 2020 Dan Rodrigues
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_affine_layer #(
    parameter VRAM_READ_LATENCY = 3
) (
    input clk,

    // Source x/y, derived from current raster position

    input [9:0] x,
    input [8:0] y,

    // Translation vectors

    input signed [15:0] pretranslate_x,
    input signed [15:0] pretranslate_y,

    input signed [15:0] translate_x,
    input signed [15:0] translate_y,

    // 2x2 matrix

    input signed [15:0] a,
    input signed [15:0] b,
    input signed [15:0] c,
    input signed [15:0] d,

    // VRAM interface

    output [13:0] vram_even_address,
    input [15:0] vram_even_data,

    output [13:0] vram_odd_address,
    input [15:0] vram_odd_data,

    // Output X cycles later

    output reg [7:0] output_pixel
);
    // 1. transform input xy

    reg [25:0] xt_full, yt_full;

    wire signed [15:0] pretranslated_x = {{6{1'b0}}, x} + pretranslate_x;
    wire signed [15:0] pretranslated_y = {{7{1'b0}}, y} + pretranslate_y;

    // counting LC usage with yosys shows that actual LC FFs aren't spent
    // these are "absorbed" into the SB_MAC16 adder as part of inferred mulitply-add
    reg signed [25:0] translate_x_r, translate_y_r;

    always @(posedge clk) begin
        translate_x_r <= (translate_x << 10) + (1 << 9);
        translate_y_r <= (translate_y << 10) + (1 << 9);
    end

    // infer 2x SB_MAC16 multiply-add and another 2x for just multiply
    always @(posedge clk) begin
        xt_full <= pretranslated_x * a + (pretranslated_y * b + translate_x_r);
        yt_full <= pretranslated_x * c + (pretranslated_y * d + translate_y_r);
    end

    wire [15:0] xt = xt_full >> 10;
    wire [15:0] yt = yt_full >> 10;

    // 2. derive vram lookup address from transformed x/y

    // are we in the defined 1024x1024 region?
    // apparently super nes games can choose to render a placeholder map char for out of bounds region
    wire out_of_bounds = xt[15:10] || yt[15:10];
    wire out_of_bounds_d;

    delay_ff #(
        .DELAY(VRAM_READ_LATENCY * 2)
    ) out_of_bounds_delay (
        .clk(clk),
        .in(out_of_bounds),
        .out(out_of_bounds_d)
    );

    wire [6:0] map_x = xt >> 3;
    wire [6:0] map_y = yt >> 3;

    wire [2:0] char_x = xt;
    wire [2:0] char_y = yt;

    wire [13:0] vram_map_address = {map_y, map_x};

    // resolved map address
    assign vram_even_address = vram_map_address[13:1];

    // delay to perform byte select within the map word

    wire map_x_d;

    delay_ff #(
        .DELAY(VRAM_READ_LATENCY)
    ) map_x_delay (
        .clk(clk),
        .in(map_x[0]),
        .out(map_x_d)
    );

    // delay to perform char fetch using the fetched map word

    delay_ff #(
        .WIDTH(6),
        .DELAY(VRAM_READ_LATENCY)
    ) char_xy_delay (
        .clk(clk),
        .in({char_y, char_x}),
        .out({char_y_d, char_x_d})
    );

    // 3. fetch char data using previously fetched map

    wire char_pixel_select_d;

    delay_ff #(
        // *2 because +1 fetch for the map, +1 fetch for the pixel
        .DELAY(VRAM_READ_LATENCY * 2)
    ) char_pixel_select_delay (
        .clk(clk),
        .in(char_x[0]),
        .out(char_pixel_select_d)
    );

    wire [2:0] char_x_d, char_y_d;

    // char address based on pixel coordinate within char

    wire [7:0] vram_map_fetch_selected = map_x_d ? vram_even_data[15:8] : vram_even_data[7:0];
    wire [7:0] char_id = vram_map_fetch_selected;
    wire [13:0] char_address = {char_id, char_y_d, char_x_d};

    // resolved pixel address
    assign vram_odd_address = char_address[13:1];

    // 4. output the fetched pixel

    wire [7:0] selected_pixel = char_pixel_select_d ? vram_odd_data[15:8] : vram_odd_data[7:0];

    always @(posedge clk) begin
        output_pixel <= out_of_bounds_d ? 0 : selected_pixel;
    end

endmodule
