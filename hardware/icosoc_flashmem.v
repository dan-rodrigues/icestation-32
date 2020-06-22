// this is a modified version of icosoc_flashmem.v
// https://github.com/cliffordwolf/icotools/blob/master/icosoc/common/icosoc_flashmem.v

// changes from the original: quick and dirty DSPI
// this is mainly useful for testing both SPI/DSPI/QSPI modes against the WIP c++ sim model
// eventually this module can just be rewritten

module icosoc_flashmem #(
    parameter ENABLE_QSPI = 1,
    parameter ASSUME_QPI = 0,
    parameter ASSUME_CRM = 1
) (
    input clk,
    input resetn,
    input continue_reading,

    input valid,
    output reg ready,
    input [23:0] addr,
    output reg [31:0] rdata,

    output reg flash_dma_clk_en,
    output reg flash_csn,
    output reg [3:0] flash_in,
    output reg [3:0] flash_in_en,
    input [3:0] flash_out
);
    localparam IO_CYCLES = ENABLE_QSPI ? 2 : 8;
    localparam READ_CMD = ENABLE_QSPI ? 8'heb : 8'h03;
    localparam INITIAL_STATE = ASSUME_CRM ? 1 : 0;
    localparam EXTRA_DUMMY_CLOCKS = ASSUME_QPI ? 0 : 4;

    reg [7:0] buffer;
    reg [3:0] xfer_cnt;
    reg [3:0] state;

    reg sending_cmd;
    reg sending;

    reg [3:0] oe_count;
    wire oe_nx = oe_count && sending;

    reg [3:0] xfer_cnt_r;
    wire first_xfer = xfer_cnt && xfer_cnt_r;

    always @(posedge clk) begin
        ready <= 0;

        if (!resetn || !valid || (ready && !continue_reading)) begin
            xfer_cnt_r <= 0;
            flash_csn <= 1;
            xfer_cnt <= 0;
            state <= INITIAL_STATE;

            flash_dma_clk_en <= 0;
            flash_in_en <= 0;
            flash_in <= 0;
            sending_cmd <= 0;
            sending <= 0;
            oe_count <= 0;
        end else begin
            flash_csn <= 0;
            xfer_cnt_r <= xfer_cnt;

            if (xfer_cnt) begin
                // !!!
                flash_dma_clk_en <= 1;

                if (first_xfer) begin
                    if (sending_cmd) begin
                        flash_in[0] <= buffer[7];
                        flash_in_en <= 4'b0001;
                        buffer <= {buffer, flash_in[1]};
                        xfer_cnt <= xfer_cnt - 1;

                        // if (0) begin
                        //     flash_in[0] <= buffer[7];
                        //     flash_in_en <= 4'b0001;
                        //     // flash_clk <= 0;
                        // end else begin
                        //     // flash_clk <= 1;
                        //     buffer <= {buffer, flash_in[1]};
                        //     xfer_cnt <= xfer_cnt - 1;
                        // end
                    end else begin
                        flash_in <= (ENABLE_QSPI ? buffer[7:4] : {3'b0, buffer[7]});
                        flash_in_en <= (ENABLE_QSPI ? {4{oe_nx}} : {3'b000, oe_nx});
                        oe_count <= |oe_count ? oe_count - 1 : 0;

                        // flash_clk <= 1;
                        buffer <= (ENABLE_QSPI ? {buffer, flash_out} : {buffer, flash_out[1]});
                        xfer_cnt <= xfer_cnt - 1;

                        // if (0) begin
                        //     // flash_clk <= 0;
                        //     flash_in <= (ENABLE_QSPI ? buffer[7:4] : {3'b0, buffer[7]});
                        //     flash_in_en <= (ENABLE_QSPI ? {4{oe_nx}} : {3'b000, oe_nx});

                        //     oe_count <= |oe_count ? oe_count - 1 : 0;
                        // end else begin
                        //     // flash_clk <= 1;
                        //     buffer <= (ENABLE_QSPI ? {buffer, flash_out} : {buffer, flash_out[1]});
                        //     xfer_cnt <= xfer_cnt - 1;
                        // end
                    end
                end

                // ...
                flash_dma_clk_en <= xfer_cnt != 1;
            end else begin
                // !!!
                // flash_dma_clk_en <= 0;

                case (state)
                    0: begin
                        // to be eliminated with CRM
                        buffer <= READ_CMD;
                        xfer_cnt <= 8;
                        state <= 1;
                        sending_cmd <= 1;
                        oe_count <= 8;
                        sending <= 1;
                    end
                    1: begin
                        buffer <= addr[23:16];
                        xfer_cnt <= IO_CYCLES;
                        state <= 2;
                        sending_cmd <= 0;
                        oe_count <= IO_CYCLES;
                        sending <= 1;
                    end
                    2: begin
                        buffer <= addr[15:8];
                        xfer_cnt <= IO_CYCLES;
                        state <= 3;
                        sending_cmd <= 0;
                        oe_count <= IO_CYCLES;
                        sending <= 1;
                    end
                    3: begin
                        buffer <= addr[7:0];
                        xfer_cnt <= IO_CYCLES;
                        state <= ENABLE_QSPI ? 4 : 5;
                        sending_cmd <= 0;
                        oe_count <= IO_CYCLES;
                        sending <= 1;
                    end
                    4: begin
                        buffer <= ASSUME_CRM ? 8'h20 : 0; // M7-0
                        xfer_cnt <= 2 + EXTRA_DUMMY_CLOCKS;
                        state <= 5;
                        sending_cmd <= 0;
                        oe_count <= ENABLE_QSPI ? 1 : 3;
                        sending <= 1;
                    end
                    5: begin
                        buffer <= 0; // receiving first byte
                        xfer_cnt <= IO_CYCLES;
                        state <= 6;
                        sending_cmd <= 0;
                        sending <= 0;
                    end
                    6: begin
                        rdata[7:0] <= buffer;
                        xfer_cnt <= IO_CYCLES;
                        state <= 7;
                        sending_cmd <= 0;
                        sending <= 0;
                    end
                    7: begin
                        rdata[15:8] <= buffer;
                        xfer_cnt <= IO_CYCLES;
                        state <= 8;
                        sending_cmd <= 0;
                        sending <= 0;
                    end
                    8: begin
                        rdata[23:16] <= buffer;
                        xfer_cnt <= IO_CYCLES;
                        state <= 9;
                        sending_cmd <= 0;
                    end
                    9: begin
                        rdata[31:24] <= buffer;
                        sending_cmd <= 0;
                        sending <= 0;
                        ready <= 1;

                        if (continue_reading) begin
                            xfer_cnt <= IO_CYCLES;
                            state <= 6;
                        end
                    end
                endcase
            end
        end
    end
endmodule

