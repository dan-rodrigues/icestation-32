`default_nettype none

module spram_wrapper(
    input clk,

    input [13:0] address,
    input [15:0] wdata,
    input we,
    input oe,

    output [15:0] rdata
);
    SB_SPRAM256KA ram (
        .ADDRESS(address),
        .DATAIN(wdata),
        .MASKWREN(4'b1111),
        .WREN(we),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata)
    );

endmodule

// copied from cells_sim.v

module SB_SPRAM256KA (
        input [13:0] ADDRESS,
        input [15:0] DATAIN,
        input [3:0] MASKWREN,
        input WREN, CHIPSELECT, CLOCK, STANDBY, SLEEP, POWEROFF,
        output reg [15:0] DATAOUT
);
        reg [15:0] mem [0:16383];
        wire off = SLEEP || !POWEROFF;
        integer i;

        always @(negedge POWEROFF) begin
                for (i = 0; i <= 16383; i = i+1)
                        mem[i] = 'bx;
        end

        always @(posedge CLOCK, posedge off) begin
                if (off) begin
                        DATAOUT <= 0;
                end else
                if (STANDBY) begin
                        DATAOUT <= 'bx;
                end else
                if (CHIPSELECT) begin
                        if (!WREN) begin
                                DATAOUT <= mem[ADDRESS];
                        end else begin
                                // if (MASKWREN[0]) mem[ADDRESS][ 3: 0] = DATAIN[ 3: 0];
                                // if (MASKWREN[1]) mem[ADDRESS][ 7: 4] = DATAIN[ 7: 4];
                                // if (MASKWREN[2]) mem[ADDRESS][11: 8] = DATAIN[11: 8];
                                // if (MASKWREN[3]) mem[ADDRESS][15:12] = DATAIN[15:12];
                                if (MASKWREN[0]) mem[ADDRESS][ 3: 0] <= DATAIN[ 3: 0];
                                if (MASKWREN[1]) mem[ADDRESS][ 7: 4] <= DATAIN[ 7: 4];
                                if (MASKWREN[2]) mem[ADDRESS][11: 8] <= DATAIN[11: 8];
                                if (MASKWREN[3]) mem[ADDRESS][15:12] <= DATAIN[15:12];
                                DATAOUT <= 'bx;
                        end
                end
        end

endmodule
