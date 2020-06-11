`default_nettype none

module reset_1x2x(
    input clk_12m,

    input clk_1x,
    input clk_2x,
    input reset,

    output reg reset_1x = 1,
    output reg reset_2x = 1
);
    // from pll.v

    reg clk_1x_r = 0;

    wire clk_2x_r = clk_12m;

    assign clk_1x = clk_1x_r;
    assign clk_2x = clk_2x_r;

    // may be able to get away with not having this here
    // assign locked = 1;

    // from reset generator

    always @(posedge clk_12m) begin
    // always @(posedge clk_2x_r) begin
        clk_1x_r = !clk_1x_r;
    end

    // TODO: reset generate and confirm the issue here too

    always @(posedge clk_1x) begin
        reset_1x <= reset;
    end

    always @(posedge clk_2x) begin
        reset_2x <= reset;
    end

endmodule
