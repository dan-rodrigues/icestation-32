// This module provides HDMI suitable output from VGA-like input
// Original repo: https://github.com/emard/ulx3s_zx_spectrum/blob/master/src/hdmi.v

module hdmi_encoder(
  input  wire pixel_clk,
  input  wire pixel_clk_x5,
  input  wire [7:0] red, green, blue,
  input  wire vde, hsync, vsync,
  output wire [3:0] gpdi_dp, gpdi_dn
);

  // 10b8b TMDS encoding of RGB and Sync
  //
  wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
  TMDS_encoder encode_R(.clk(pixel_clk), .VD(red  ), .CD(2'b00)        , .VDE(vde), .TMDS(TMDS_red));
  TMDS_encoder encode_G(.clk(pixel_clk), .VD(green), .CD(2'b00)        , .VDE(vde), .TMDS(TMDS_green));
  TMDS_encoder encode_B(.clk(pixel_clk), .VD(blue ), .CD({vsync,hsync}), .VDE(vde), .TMDS(TMDS_blue));

  // shift out 10 bits each pix clock (2 DDR bits at a 5x rate)
  //
  reg [2:0] ctr_mod5 = 0;
  reg shift_ld = 0;

  always @(posedge pixel_clk_x5)
  begin
    shift_ld <= (ctr_mod5==4'd4);
    ctr_mod5 <= (ctr_mod5==4'd4) ? 4'd0 : ctr_mod5 + 4'd1;
  end
  
  reg [9:0] shift_R = 0, shift_G = 0, shift_B = 0, shift_C = 0;

  always @(posedge pixel_clk_x5)
  begin
    shift_R <= shift_ld ? TMDS_red   : shift_R[9:2];
    shift_G <= shift_ld ? TMDS_green : shift_G[9:2];
    shift_B <= shift_ld ? TMDS_blue  : shift_B[9:2];	
    shift_C <= shift_ld ? 10'h3e0    : shift_C[9:2];
  end

`ifdef __ICARUS__
  // (pseudo-) differential DDR driver (pure verilog version)
  //
  assign gpdi_dp[3] = pixel_clk_x5 ? shift_C[0] : shift_C[1];
  assign gpdi_dp[2] = pixel_clk_x5 ? shift_R[0] : shift_R[1];
  assign gpdi_dp[1] = pixel_clk_x5 ? shift_G[0] : shift_G[1];
  assign gpdi_dp[0] = pixel_clk_x5 ? shift_B[0] : shift_B[1];

  assign gpdi_dn = ~ gpdi_dp;
`else
  // (pseudo-) differential DDR driver (ECP5 synthesis version)
  //*
  ODDRX1F ddr3p( .Q(gpdi_dp[3]), .SCLK(pixel_clk_x5), .D0(shift_C[0]),  .D1(shift_C[1]),  .RST(0) );
  ODDRX1F ddr2p( .Q(gpdi_dp[2]), .SCLK(pixel_clk_x5), .D0(shift_R[0]),  .D1(shift_R[1]),  .RST(0) );
  ODDRX1F ddr1p( .Q(gpdi_dp[1]), .SCLK(pixel_clk_x5), .D0(shift_G[0]),  .D1(shift_G[1]),  .RST(0) );
  ODDRX1F ddr0p( .Q(gpdi_dp[0]), .SCLK(pixel_clk_x5), .D0(shift_B[0]),  .D1(shift_B[1]),  .RST(0) );

  ODDRX1F ddr3n( .Q(gpdi_dn[3]), .SCLK(pixel_clk_x5), .D0(~shift_C[0]), .D1(~shift_C[1]), .RST(0) );
  ODDRX1F ddr2n( .Q(gpdi_dn[2]), .SCLK(pixel_clk_x5), .D0(~shift_R[0]), .D1(~shift_R[1]), .RST(0) );
  ODDRX1F ddr1n( .Q(gpdi_dn[1]), .SCLK(pixel_clk_x5), .D0(~shift_G[0]), .D1(~shift_G[1]), .RST(0) );
  ODDRX1F ddr0n( .Q(gpdi_dn[0]), .SCLK(pixel_clk_x5), .D0(~shift_B[0]), .D1(~shift_B[1]), .RST(0) );
`endif

endmodule


// DVI-D 10b8b TMDS encoder module
//
module TMDS_encoder(
  input clk,       // pix clock
  input [7:0] VD,  // video data (red, green or blue)
  input [1:0] CD,  // control data
  input VDE,       // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
  output reg [9:0] TMDS = 0
);

  reg  [3:0] dc_bias = 0;

  // compute data word
  wire [3:0] ones = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
  wire       XNOR = (ones>4'd4) || (ones==4'd4 && VD[0]==1'b0);
  wire [8:0] dw;
  assign dw[8] = ~XNOR;
  assign dw[7] = dw[6] ^ VD[7] ^ XNOR;
  assign dw[6] = dw[5] ^ VD[6] ^ XNOR;
  assign dw[5] = dw[4] ^ VD[5] ^ XNOR;
  assign dw[4] = dw[3] ^ VD[4] ^ XNOR;
  assign dw[3] = dw[2] ^ VD[3] ^ XNOR;
  assign dw[2] = dw[1] ^ VD[2] ^ XNOR;
  assign dw[1] = dw[0] ^ VD[1] ^ XNOR;
  assign dw[0] = VD[0];

  // calculate 1/0 disparity & invert as needed to minimize dc bias
  wire [3:0] dw_disp = dw[0] + dw[1] + dw[2] + dw[3] + dw[4] + dw[5] + dw[6] + dw[7] + 4'b1100;
  wire       sign_eq = (dw_disp[3] == dc_bias[3]);
  
  wire [3:0] delta  = dw_disp - ({dw[8] ^ ~sign_eq} & ~(dw_disp==0 || dc_bias==0));
  wire       inv_dw = (dw_disp==0 || dc_bias==0) ? ~dw[8] : sign_eq;
  
  wire [3:0] dc_bias_d = inv_dw ? dc_bias - delta : dc_bias + delta;
  
  // set output signals
  wire [9:0] TMDS_data = { inv_dw, dw[8], dw[7:0] ^ {8{inv_dw}} };
  wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100)
                               : (CD[0] ? 10'b0010101011 : 10'b1101010100);

  always @(posedge clk) TMDS    <= VDE ? TMDS_data : TMDS_code;
  always @(posedge clk) dc_bias <= VDE ? dc_bias_d : 0;

endmodule

