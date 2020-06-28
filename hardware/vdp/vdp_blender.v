// vdp_blender.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module vdp_blender(
    input clk,

    input source_layer_enabled,
    input [15:0] source_color,

    input [15:0] dest_color,

    output reg [15:0] output_color
);
    reg [31:0] output_source;
    reg [31:0] output_dest;

    reg [31:0] mult_source, mult_source_alpha;
    reg [31:0] mult_dest, mult_dest_alpha;

    wire [3:0] alpha_source = source_color[15:12];
    wire [3:0] alpha_dest = dest_color[15:12];

    // sum the output including 1 bit of fraction
    // it's more accurate to sum using all fraction bits but doing this saves a bunch of slices
    // there is also diminishing returns in perceived accuracy since the fraction MSB is most important

    wire [3:0] blended_r = (output_source[23:19] + output_dest[23:19] + 1) >> 1;
    wire [3:0] blended_g = (output_source[15:11] + output_dest[15:11] + 1) >> 1;
    wire [3:0] blended_b = (output_source[7:3] + output_dest[7:3] + 1) >> 1;

    // BRAM table for scaled alpha values

    // address:
    // ddddsssss
    // d: dest alpha
    // s: source alpha

    // output:
    // ------DD DDDSSSSS
    // S: source alpha multiplier
    // D: dest alpha multiplier

    reg [15:0] alpha_lut [0:255];

    reg [7:0] alpha_lut_address;
    reg [15:0] alpha_lut_output;

    wire [4:0] alpha_lut_source_output = alpha_lut_output[4:0];
    wire [4:0] alpha_lut_dest_output = alpha_lut_output[9:5];

`ifndef ALPHA_LUT
    genvar var_source_alpha, var_dest_alpha;

    generate
        for (var_dest_alpha = 0; var_dest_alpha < 16; var_dest_alpha = var_dest_alpha + 1) begin: gen_vda
            for (var_source_alpha = 0; var_source_alpha < 16; var_source_alpha = var_source_alpha + 1) begin: gen_vsa

                integer mapped_source_alpha, mapped_dest_alpha;
                integer lut_index = (var_dest_alpha << 4) + var_source_alpha;

                initial begin
                    mapped_source_alpha = (var_source_alpha > 0 ? var_source_alpha + 1 : 0);
                    mapped_dest_alpha = (var_dest_alpha > 0 ? var_dest_alpha + 1 : 0);
                    mapped_dest_alpha = ((16 - mapped_source_alpha) * mapped_dest_alpha) / 16;

                    // this causes an assertion in yosys when using this with cxxrtl
                    // issue with context on the root cause:
                    // https://github.com/YosysHQ/yosys/issues/2129
                    alpha_lut[lut_index] = mapped_source_alpha | (mapped_dest_alpha << 5);
                end
            end
        end
    endgenerate
`else
    initial begin
        $readmemh(`ALPHA_LUT, alpha_lut);
    end
`endif

    always @(posedge clk) begin
        alpha_lut_output <= alpha_lut[alpha_lut_address];
    end

    // need to add 2 cycles of pipeline delay to allow LUT lookup

    wire source_visible = (alpha_source != 0) && source_layer_enabled;
    wire source_visible_d;

    delay_ff #(
        .DELAY(1),
        .WIDTH(1)
    ) source_visible_dm (
        .clk(clk),
        .in(source_visible),
        .out(source_visible_d)
    );

    wire [11:0] output_source_color_d;

    delay_ff #(
        .DELAY(2),
        .WIDTH(12)
    ) output_source_color_dm (
        .clk(clk),
        .in(source_color[11:0]),
        .out(output_source_color_d)
    );

    wire [11:0] output_dest_color_d;

    delay_ff #(
        .DELAY(2),
        .WIDTH(12)
    ) output_dest_color_dm (
        .clk(clk),
        .in(dest_color[11:0]),
        .out(output_dest_color_d)
    );

    always @(posedge clk) begin
        // force address to 0 if dest not opaque
        alpha_lut_address <= {alpha_dest, source_visible_d ? alpha_source : 4'b0000};

        mult_source <= {
            4'b0000, color_r(output_source_color_d),
            4'b0000, color_g(output_source_color_d),
            4'b0000, color_b(output_source_color_d)
        };

        mult_source_alpha <= alpha_lut_source_output;

        mult_dest <= {
            4'b0000, color_r(output_dest_color_d),
            4'b0000, color_g(output_dest_color_d),
            4'b0000, color_b(output_dest_color_d)
        };

        mult_dest_alpha <= alpha_lut_dest_output;

        output_source <= mult_source * mult_source_alpha;
        output_dest <= mult_dest * mult_dest_alpha;

        output_color <= {blended_r, blended_g, blended_b};
    end

    // convenience functions to extract a certain color component

    function [3:0] color_b;
        input [15:0] argb16;
        begin
            color_b = argb16[3:0];
        end
    endfunction

    function [3:0] color_g;
        input [15:0] argb16;
        begin
            color_g = argb16[7:4];
        end
    endfunction

    function [3:0] color_r;
        input [15:0] argb16;
        begin
            color_r = argb16[11:8];
        end
    endfunction

    function [3:0] color_a;
        input [15:0] argb16;
        begin
            color_a = argb16[15:12];
        end
    endfunction

endmodule
