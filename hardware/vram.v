`default_nettype none

// 64kbyte split into independently addressable 2x 32kbyte 16bit blocks

module vram(
    input clk,

    input [13:0] even_address,
    input [13:0] odd_address,
    input even_write_en,
    input odd_write_en,
    input [31:0] write_data,

    output [31:0] read_data
);
    spram_256k vram_0 (
        .clk(clk),
        .address(even_address),
        .write_data(write_data[15:0]),
        .mask(4'b1111),
        .write_en(even_write_en),
        .cs(1),
        .read_data(read_data[15:0])
    );

    spram_256k vram_1 (
        .clk(clk),
        .address(odd_address),
        .write_data(write_data[31:16]),
        .mask(4'b1111),
        .write_en(odd_write_en),
        .cs(1),
        .read_data(read_data[31:16])
    );

endmodule
