module SB_IO (
	inout  PACKAGE_PIN,
	input  LATCH_INPUT_VALUE,
	input  CLOCK_ENABLE,
	input  INPUT_CLK,
	input  OUTPUT_CLK,
	input  OUTPUT_ENABLE,
	input  D_OUT_0,
	input  D_OUT_1,
	output D_IN_0,
	output D_IN_1
);
	parameter [5:0] PIN_TYPE = 6'b000000;
	parameter [0:0] PULLUP = 1'b0;
	parameter [0:0] NEG_TRIGGER = 1'b0;
	parameter IO_STANDARD = "SB_LVCMOS";

`ifndef BLACKBOX
	reg dout, din_0, din_1;
	reg din_q_0, din_q_1;
	reg dout_q_0, dout_q_1;
	reg outena_q;

	// IO tile generates a constant 1'b1 internally if global_cen is not connected
	wire clken_pulled = CLOCK_ENABLE; /* || CLOCK_ENABLE === 1'bz;*/
	reg  clken_pulled_ri;
	reg  clken_pulled_ro;

	generate if (!NEG_TRIGGER) begin
		always @(posedge INPUT_CLK)                       clken_pulled_ri <= clken_pulled;
		always @(posedge INPUT_CLK)  if (clken_pulled)    din_q_0         <= PACKAGE_PIN;
		always @(negedge INPUT_CLK)  if (clken_pulled_ri) din_q_1         <= PACKAGE_PIN;
		always @(posedge OUTPUT_CLK)                      clken_pulled_ro <= clken_pulled;
		always @(posedge OUTPUT_CLK) if (clken_pulled)    dout_q_0        <= D_OUT_0;
		always @(negedge OUTPUT_CLK) if (clken_pulled_ro) dout_q_1        <= D_OUT_1;
		always @(posedge OUTPUT_CLK) if (clken_pulled)    outena_q        <= OUTPUT_ENABLE;
	end else begin
		always @(negedge INPUT_CLK)                       clken_pulled_ri <= clken_pulled;
		always @(negedge INPUT_CLK)  if (clken_pulled)    din_q_0         <= PACKAGE_PIN;
		always @(posedge INPUT_CLK)  if (clken_pulled_ri) din_q_1         <= PACKAGE_PIN;
		always @(negedge OUTPUT_CLK)                      clken_pulled_ro <= clken_pulled;
		always @(negedge OUTPUT_CLK) if (clken_pulled)    dout_q_0        <= D_OUT_0;
		always @(posedge OUTPUT_CLK) if (clken_pulled_ro) dout_q_1        <= D_OUT_1;
		always @(negedge OUTPUT_CLK) if (clken_pulled)    outena_q        <= OUTPUT_ENABLE;
	end endgenerate

	always @* begin
		if (!PIN_TYPE[1] || !LATCH_INPUT_VALUE)
			din_0 = PIN_TYPE[0] ? PACKAGE_PIN : din_q_0;
		din_1 = din_q_1;
	end

	// work around simulation glitches on dout in DDR mode
	// is this still bneeded?
	// reg outclk_delayed_1;
	// reg outclk_delayed_2;
	// always @* outclk_delayed_1 <= OUTPUT_CLK;
	// always @* outclk_delayed_2 <= outclk_delayed_1;
	// always @* outclk_delayed_1 <= OUTPUT_CLK;
	// always @* outclk_delayed_2 <= outclk_delayed_1;

	wire outclk_delayed_1 = OUTPUT_CLK;
	wire outclk_delayed_2 = OUTPUT_CLK;

	always @* begin
		if (PIN_TYPE[3])
			dout = PIN_TYPE[2] ? !dout_q_0 : D_OUT_0;
		else
			dout = (outclk_delayed_2 ^ NEG_TRIGGER) || PIN_TYPE[2] ? dout_q_0 : dout_q_1;
	end

	assign D_IN_0 = din_0, D_IN_1 = din_1;

	generate
		if (PIN_TYPE[5:4] == 2'b01) assign PACKAGE_PIN = dout;
		if (PIN_TYPE[5:4] == 2'b10) assign PACKAGE_PIN = OUTPUT_ENABLE ? dout : 0;
		if (PIN_TYPE[5:4] == 2'b11) assign PACKAGE_PIN = outena_q ? dout : 0;
	endgenerate
`endif
`ifdef TIMING
specify
	(INPUT_CLK => D_IN_0) = (0:0:0, 0:0:0);
	(INPUT_CLK => D_IN_1) = (0:0:0, 0:0:0);
	(PACKAGE_PIN => D_IN_0) = (0:0:0, 0:0:0);
	(OUTPUT_CLK => PACKAGE_PIN) = (0:0:0, 0:0:0);
	(D_OUT_0 => PACKAGE_PIN) = (0:0:0, 0:0:0);
	(OUTPUT_ENABLE => PACKAGE_PIN) = (0:0:0, 0:0:0);

	$setuphold(posedge OUTPUT_CLK, posedge D_OUT_0, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, negedge D_OUT_0, 0:0:0, 0:0:0);
	$setuphold(negedge OUTPUT_CLK, posedge D_OUT_1, 0:0:0, 0:0:0);
	$setuphold(negedge OUTPUT_CLK, negedge D_OUT_1, 0:0:0, 0:0:0);
	$setuphold(negedge OUTPUT_CLK, posedge D_OUT_0, 0:0:0, 0:0:0);
	$setuphold(negedge OUTPUT_CLK, negedge D_OUT_0, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, posedge D_OUT_1, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, negedge D_OUT_1, 0:0:0, 0:0:0);
	$setuphold(posedge INPUT_CLK, posedge CLOCK_ENABLE, 0:0:0, 0:0:0);
	$setuphold(posedge INPUT_CLK, negedge CLOCK_ENABLE, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, posedge CLOCK_ENABLE, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, negedge CLOCK_ENABLE, 0:0:0, 0:0:0);
	$setuphold(posedge INPUT_CLK, posedge PACKAGE_PIN, 0:0:0, 0:0:0);
	$setuphold(posedge INPUT_CLK, negedge PACKAGE_PIN, 0:0:0, 0:0:0);
	$setuphold(negedge INPUT_CLK, posedge PACKAGE_PIN, 0:0:0, 0:0:0);
	$setuphold(negedge INPUT_CLK, negedge PACKAGE_PIN, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, posedge OUTPUT_ENABLE, 0:0:0, 0:0:0);
	$setuphold(posedge OUTPUT_CLK, negedge OUTPUT_ENABLE, 0:0:0, 0:0:0);
	$setuphold(negedge OUTPUT_CLK, posedge OUTPUT_ENABLE, 0:0:0, 0:0:0);
	$setuphold(negedge OUTPUT_CLK, negedge OUTPUT_ENABLE, 0:0:0, 0:0:0);
endspecify
`endif
endmodule

