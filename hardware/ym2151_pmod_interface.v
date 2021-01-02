// ym2151_pmod_interface.v
//
// Copyright (C) 2021 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ym2151_pmod_interface(
	input clk,
	input ym_clk,
	input reset,

	// YM2151 I/O

	input a0,
	input [7:0] din,
	input wr_n,

	output busy,

	// PMOD I/O

	output pmod_shift_clk,
	output reg pmod_shift_out,
	output reg pmod_shift_load,

	// YM3012 input

	input pmod_dac_clk,
	input pmod_dac_so,
	input pmod_dac_sh1,
	input pmod_dac_sh2,

	// Audio output

	output reg audio_valid,
	output reg signed [15:0] audio_left,
	output reg signed [15:0] audio_right,

	// Test

	output reg dbg_dac_clk_rose
);
	// It's possible to use a faster, separate clock for the shift register output
	// The 2151 clock is slow but adequate here and also breadboard friendly

	assign pmod_shift_clk = ym_clk;

	reg ym_clk_r;

	wire ym_clk_rose = ym_clk && !ym_clk_r;
	wire ym_clk_fell = !ym_clk && ym_clk_r;

	always @(posedge clk) begin
		ym_clk_r <= ym_clk;
	end

	// Write handling:

	reg wr_n_r;
	wire wr_n_rose = wr_n && !wr_n_r;
	wire wr_n_fell = !wr_n && wr_n_r;

	reg [7:0] din_r;
	reg a0_r;

	always @(posedge clk) begin
		wr_n_r <= wr_n;

		din_r <= din;
		a0_r <= a0;
	end

	// FIXME: can tune this according to how slow the YM clock is
	localparam BUSY_INTERVAL = 96;

	reg [$clog2(BUSY_INTERVAL):0] busy_counter;

	assign busy = (busy_counter > 0) || write_begun || wr_n_fell || !wr_n_r;

	always @(posedge clk) begin
		if (reset) begin
			busy_counter <= 0;
		end else if (write_begun) begin
			busy_counter <= BUSY_INTERVAL;
		end else if (ym_clk_rose && (busy_counter > 0)) begin
			busy_counter <= busy_counter - 1;
		end
	end

	// Shift register write FSM:

	localparam [2:0]
		STATE_ADDRESS_SETUP = 0,
		STATE_REG_WRITE = 1,
		STATE_REG_WRITE_HOLD = 2,
		STATE_WRITING = 4,
		STATE_IDLE = 5;

	reg [2:0] state;
	reg [2:0] next_state;

	reg write_begun;
	reg shift_needs_load;

	reg [7:0] din_write;
	reg a0_write;

	reg [7:0] reg_address_pending_write;
	reg [7:0] reg_data_pending_write;
	reg reg_address_writing;

	reg a0_shift;
	reg [7:0] din_shift;
	reg cs_n_shift;
	reg wr_n_shift;
	reg ic_n_shift;

	always @(posedge clk) begin
		if (reset) begin
			write_begun <= 0;
			shift_needs_load <= 0;

			ic_n_shift <= 0;
			state <= STATE_ADDRESS_SETUP;
		end else begin
			write_begun <= 0;
			shift_needs_load <= 0;

			case (state)
				STATE_IDLE: begin
					if (wr_n_rose) begin
						if (a0) begin
							a0_write <= 0;
							din_write <= reg_address_pending_write;
							reg_data_pending_write <= din_r;

							reg_address_writing <= 1;
							write_begun <= 1;

							state <= STATE_ADDRESS_SETUP;
						end else begin
							reg_address_pending_write <= din_r;
						end
					end
				end
				STATE_ADDRESS_SETUP: begin
					a0_shift <= a0_write;
					cs_n_shift <= 1;
					wr_n_shift <= 1;
					din_shift <= din_write;

					shift_needs_load <= 1;
					state <= STATE_WRITING;
					next_state <= STATE_REG_WRITE;
				end
				STATE_REG_WRITE: begin
					a0_shift <= a0_write;
					cs_n_shift <= 0;
					wr_n_shift <= 0;
					din_shift <= din_write;

					shift_needs_load <= 1;
					state <= STATE_WRITING;
					next_state <= STATE_REG_WRITE_HOLD;
				end
				STATE_REG_WRITE_HOLD: begin
					a0_shift <= a0_write;
					cs_n_shift <= 1;
					wr_n_shift <= 1;
					din_shift <= din_write;

					if (reg_address_writing) begin
						// Reg address will be written, write data next
						reg_address_writing <= 0;
						a0_write <= 1;
						din_write <= reg_data_pending_write;

						next_state <= STATE_ADDRESS_SETUP;
					end else begin
						// Reg address and data will be both written
						next_state <= STATE_IDLE;

						// The /IC input is only asserted on reset
						ic_n_shift <= 1;
					end

					shift_needs_load <= 1;
					state <= STATE_WRITING;
				end
				STATE_WRITING: begin
					if (shift_completed) begin
						state <= next_state;
					end
				end
			endcase
		end
	end

	// Output shift register:

	// External shift reg is clocked on posedge
	// Output here is shifted on negedge

	localparam SHIFT_BITS = 14;
	localparam SHIFT_MSB = SHIFT_BITS - 1;

	reg [SHIFT_MSB:0] shift;
	assign pmod_shift_out = shift[SHIFT_MSB];

	reg [3:0] shift_count;
	reg shift_completed;
	reg shift_awaiting_posedge;
	reg shifting;

	wire volume_clk = 0;
	wire volume_up_down = 0;

	wire [SHIFT_MSB:0] shift_preload = {
		volume_up_down, volume_clk,
		ic_n_shift, wr_n_shift, cs_n_shift, a0_shift, din_shift
	};

	always @(posedge clk) begin
		if (reset) begin
			shift_completed <= 0;
			pmod_shift_load <= 0;
			shift_awaiting_posedge <= 0;
			shifting <= 0;
		end else begin
			shift_completed <= 0;
			pmod_shift_load <= 0;

			if (shift_needs_load) begin
				shift <= shift_preload;
				shift_count <= 0;
				shifting <= 1;

				shift_awaiting_posedge <= 1;
			end else if (shifting && shift_awaiting_posedge) begin
				if (ym_clk_rose) begin
					shift_awaiting_posedge <= 0;
				end
			end else if (shifting && ym_clk_fell) begin
				shift <= shift << 1;

				if (shift_count == SHIFT_MSB) begin
					shift_completed <= 1;
					pmod_shift_load <= 1;
					shifting <= 0;
				end

				shift_count <= shift_count + 1;
			end
		end
	end

	// --- YM3012 ---

	// Clock enable (based on DAC input)

	reg [2:0] dac_clk_r;
	wire dac_clk_rose = dac_clk_r[2] && !dac_clk_r[1];
	wire dac_clk_fell = !dac_clk_r[2] && dac_clk_r[1];

	always @(posedge clk) begin
		dac_clk_r <= {dac_clk_r[1:0], pmod_dac_clk};
	end

	// Sample inputs:

	reg [2:0] so_r, sh1_r, sh2_r;
	wire dac_so_sync = so_r[2];
	wire dac_sh1_sync = sh1_r[2];
	wire dac_sh2_sync = sh2_r[2];

	always @(posedge clk) begin
		so_r <= {so_r[1:0], pmod_dac_so};
		sh1_r <= {sh1_r[1:0], pmod_dac_sh1};
		sh2_r <= {sh2_r[1:0], pmod_dac_sh2};
	end

	ym3012 ym3012(
		.clk(clk),
		.clk_en(dac_clk_rose),

		.ic_n(ic_n_shift),

		.so(dac_so_sync),
		.sh1(dac_sh1_sync),
		.sh2(dac_sh2_sync),

		.output_valid(audio_valid),
		.left(audio_left),
		.right(audio_right)
	);

	// Testing only:

	always @(posedge clk) begin
		dbg_dac_clk_rose <= dac_clk_rose;
	end

endmodule
