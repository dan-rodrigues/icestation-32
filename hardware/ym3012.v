// ym3012.v
//
// Copyright (C) 2021 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

// Documentation by Tatsuyuki Satoh was used to write this

module ym3012(
	input clk,
	input clk_en,

	input ic_n,

	input so,
	input sh1,
	input sh2,

	output reg signed [15:0] left, 
	output reg signed [15:0] right, 
	output output_valid
);
	assign output_valid = clk_en && ic_n && sh2_fell;

	reg [12:0] shift_in;

	reg sh1_r, sh2_r;
	wire sh1_fell = !sh1 && sh1_r;
	wire sh2_fell = !sh2 && sh2_r;

	reg [2:0] exp_l, exp_r;

	always @(posedge clk) begin
		if (clk_en) begin
			sh1_r <= sh1;
			sh2_r <= sh2;
		end
	end

	wire [2:0] exp = shift_in[12:10];
	wire [15:0] preshifted_level = {!shift_in[9], shift_in[8:0], 6'b000000};

	always @(posedge clk) begin
		if (clk_en) begin
			if (!ic_n) begin
				left <= 0;
				right <= 0;
			end else if (sh1_fell) begin
				exp_l <= exp;
				left <= preshifted_level;
			end else if (sh2_fell) begin
				exp_r <= exp;
				right <= preshifted_level;
			end

			if (exp_l < 7) begin
				exp_l <= exp_l + 1;
				left <= left >>> 1;
			end

			if (exp_r < 7) begin
				exp_r <= exp_r + 1;
				right <= right >>> 1;
			end
		end
	end

	always @(posedge clk) begin
		if (clk_en) begin
			if (!ic_n) begin
				shift_in <= 0;
			end else begin
				shift_in <= {so, shift_in[12:1]};
			end
		end
	end

endmodule
