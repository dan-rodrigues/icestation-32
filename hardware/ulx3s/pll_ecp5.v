// pll_ecp5.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module pll_ecp5 #(
    parameter ENABLE_FAST_CLK = 1
) (
    input clk_25m,

    output locked,
    output clk_1x,
    output clk_2x,
    output clk_10x
);
    generate
        if (ENABLE_FAST_CLK) begin
            generated_pll_33_75 generated_pll(
                .clkin(clk_25m),
                .clkout0(clk_10x),
                .clkout3(clk_1x),
                .clkout2(clk_2x),
                .locked(locked)
            );
        end else begin
            generated_pll_25 generated_pll(
                .clkin(clk_25m),
                .clkout0(clk_10x),
                .clkout3(clk_1x),
                .clkout2(clk_2x),
                .locked(locked)
            );
        end
    endgenerate

endmodule
