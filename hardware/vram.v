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
    // maybe
    wire [15:0] low, high;
    // assign read_data = {high, low};

    // the included yosys cells_sim implementation does not play nice with either yosys/cxxrtl
`ifdef VERILATOR
    reg [15:0] ram0 [0:32767];
    reg [15:0] ram1 [0:32767];

    reg [15:0] read_even, read_odd;
    assign read_data = {read_odd, read_even};

    always @(posedge clk) begin
        if (even_write_en) begin
            ram0[even_address] <= write_data[15:0];
        end
        if (odd_write_en) begin
            ram1[odd_address] <= write_data[31:16];
        end

        read_even <= ram0[even_address];
        read_odd <= ram1[odd_address];
    end

`else
    SB_SPRAM256KA ram0 (
        .ADDRESS(even_address),
        .DATAIN(write_data[15:0]),
        .MASKWREN(4'b1111),
        .WREN(even_write_en),
        .CHIPSELECT(1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(low)
    );

    SB_SPRAM256KA ram1 (
        .ADDRESS(odd_address),
        .DATAIN(write_data[31:16]),
        .MASKWREN(4'b1111),
        .WREN(odd_write_en),
        .CHIPSELECT(1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(high)
    );
`endif

endmodule
