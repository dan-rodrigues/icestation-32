// File ../../../../usb11_phy_vhdl/usb_tx_phy.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

//======================================================================================--
//          Verilog to VHDL conversion by Martin Neumann martin@neumnns-mail.de         --
//                                                                                      --
//          ///////////////////////////////////////////////////////////////////         --
//          //                                                               //         --
//          //  USB 1.1 PHY                                                  //         --
//          //  TX                                                           //         --
//          //                                                               //         --
//          //                                                               //         --
//          //  Author: Rudolf Usselmann                                     //         --
//          //          rudi@asics.ws                                        //         --
//          //                                                               //         --
//          //                                                               //         --
//          //  Downloaded from: http://www.opencores.org/cores/usb_phy/     //         --
//          //                                                               //         --
//          ///////////////////////////////////////////////////////////////////         --
//          //                                                               //         --
//          //  Copyright (C) 2000-2002 Rudolf Usselmann                     //         --
//          //                          www.asics.ws                         //         --
//          //                          rudi@asics.ws                        //         --
//          //                                                               //         --
//          //  This source file may be used and distributed without         //         --
//          //  restriction provided that this copyright statement is not    //         --
//          //  removed from the file and that any derivative work contains  //         --
//          //  the original copyright notice and the associated disclaimer. //         --
//          //                                                               //         --
//          //      THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY      //         --
//          //  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED    //         --
//          //  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS    //         --
//          //  FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR       //         --
//          //  OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,          //         --
//          //  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES     //         --
//          //  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE    //         --
//          //  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR         //         --
//          //  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF   //         --
//          //  LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT   //         --
//          //  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT   //         --
//          //  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE          //         --
//          //  POSSIBILITY OF SUCH DAMAGE.                                  //         --
//          //                                                               //         --
//          ///////////////////////////////////////////////////////////////////         --
//======================================================================================--
//                                                                                      --
// Change history                                                                       --
// +-------+-----------+-------+------------------------------------------------------+ --
// | Vers. | Date      | Autor | Comment                                              | --
// +-------+-----------+-------+------------------------------------------------------+ --
// |  2.1  |20 Jul 2019| EMARD | LineCtrl_i: 0: Data TX, 1: KEEPALIVE/RESUME/RESET    | --
// |       |           |       | DataOut_i(1 downto 0)="00": KEEPALIVE (2 clk of SE0) | --
// |       |           |       | DataOut_i(1 downto 0)="01": RESUME (20ms of K)       | --
// |       |           |       | DataOut_i(1 downto 0)="11": RESET (20ms of SE0)      | --
// |  2.0  | 3 Jul 2016|  MN   | Changed eop logic due to USB spec violation          | --
// |  1.1  |23 Apr 2011|  MN   | Added missing 'rst' in process sensitivity lists     | --
// |       |           |       | Added ELSE constructs in next_state process to       | --
// |       |           |       |   prevent an undesired latch implementation.         | --
// |  1.0  |04 Feb 2011|  MN   | Initial version                                      | --
//======================================================================================--
// no timescale needed

module usb_tx_phy(
input wire clk,
input wire rst,
input wire fs_ce,
input wire phy_mode,
output reg txdp,
output reg txdn,
output reg txoe,
input wire LineCtrl_i,
input wire [7:0] DataOut_i,
input wire TxValid_i,
output reg TxReady_o
);

// HIGH level for differential IO mode (else single-ended)
// Transciever Interface
// UTMI Interface
// 0: Data TX, 1: LineCtrl
// TX byte or LineCtrl mode



reg [7:0] hold_reg;
reg ld_data;
wire ld_data_d;
wire ld_sop_d;
reg R_LineCtrl_i;
reg R_long_i;
reg R_busreset_i;
reg [15:0] bit_cnt;  // 20ms long @ 6MHz: (15 downto 0)
wire sft_done_e;
wire any_eop_state;
wire append_eop;
wire se_state;
reg data_xmit;
reg [7:0] hold_reg_d;
reg [2:0] one_cnt;
reg sd_bs_o;
reg sd_nrzi_o;
reg sd_raw_o;
reg sft_done;
reg sft_done_r;
reg [3:0] state;
wire stuff;
reg tx_ip;
reg tx_ip_sync;
reg txoe_r1; reg txoe_r2;
wire S_long;
parameter IDLE_STATE = 4'b0000;
parameter SOP_STATE = 4'b0001;
parameter DATA_STATE = 4'b0010;
parameter WAIT_STATE = 4'b0011;
parameter EOP0_STATE = 4'b1000;
parameter EOP1_STATE = 4'b1001;
parameter EOP2_STATE = 4'b1010;
parameter EOP3_STATE = 4'b1011;
parameter EOP4_STATE = 4'b1100;
parameter EOP5_STATE = 4'b1101;

  //======================================================================================--
  // Misc Logic                                                                         --
  //======================================================================================--
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      TxReady_o <= 1'b0;
    end else begin
      TxReady_o <= (ld_data_d | (R_LineCtrl_i & any_eop_state)) & TxValid_i;
    end
  end

  always @(posedge clk) begin
    ld_data <= ld_data_d;
  end

  //======================================================================================--
  // Transmit in progress indicator                                                     --
  //======================================================================================--
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      tx_ip <= 1'b0;
    end else begin
      if(ld_sop_d == 1'b1) begin
        tx_ip <= 1'b1;
      end
      else if(append_eop == 1'b1) begin
        tx_ip <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if(rst == 1'b0) begin
      tx_ip_sync <= 1'b0;
    end else begin
      if(fs_ce == 1'b1) begin
        tx_ip_sync <= tx_ip;
      end
    end
  end

  // data_xmit helps us to catch cases where TxValid drops due to
  // packet END and then gets re-asserted as a new packet starts.
  // We might not see this because we are still transmitting.
  // data_xmit should solve those cases ...
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      data_xmit <= 1'b0;
    end else begin
      if(TxValid_i == 1'b1 && tx_ip == 1'b0) begin
        data_xmit <= 1'b1;
      end
      else if(TxValid_i == 1'b0) begin
        data_xmit <= 1'b0;
      end
    end
  end

  //======================================================================================--
  // Shift Register                                                                     --
  //======================================================================================--
  always @(posedge clk) begin
      //IF rising_edge(clk) THEN
    if(rst == 1'b0) begin
      bit_cnt <= {16{1'b0}};
    end else begin
      if(tx_ip_sync == 1'b0) begin
        bit_cnt <= {16{1'b0}};
      end
      else if(fs_ce == 1'b1 && stuff == 1'b0) begin
        bit_cnt <= bit_cnt + 1;
      end
    end
  end

  always @(posedge clk) begin
    if(tx_ip_sync == 1'b0) begin
      sd_raw_o <= 1'b0;
    end
    else begin
      sd_raw_o <= hold_reg_d[bit_cnt[2:0]];
    end
  end

  always @(posedge clk) begin
    if(rst == 1'b0) begin
      sft_done <= 1'b0;
      sft_done_r <= 1'b0;
    end else begin
      if(bit_cnt[(15)] == (R_LineCtrl_i & R_long_i) && bit_cnt[2:0] == 3'b111) begin
        sft_done <=  ~stuff;
      end
      else begin
        sft_done <= 1'b0;
      end
      sft_done_r <= sft_done;
    end
  end

  assign sft_done_e = sft_done &  ~sft_done_r;
  // Out Data Hold Register
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      hold_reg <= 8'h00;
      hold_reg_d <= 8'h00;
    end else begin
      if(ld_sop_d == 1'b1) begin
        hold_reg <= 8'h80;
      end
      else if(ld_data == 1'b1) begin
        hold_reg <= DataOut_i;
      end
      hold_reg_d <= hold_reg;
    end
  end

  //======================================================================================--
  // Bit Stuffer                                                                        --
  //======================================================================================--
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      one_cnt <= 3'b000;
    end else begin
      if(tx_ip_sync == 1'b0) begin
        one_cnt <= 3'b000;
      end
      else if(fs_ce == 1'b1) begin
        if(sd_raw_o == 1'b0 || stuff == 1'b1) begin
          one_cnt <= 3'b000;
        end
        else begin
          one_cnt <= one_cnt + 1;
        end
      end
    end
  end

  assign stuff = one_cnt == 3'b110 ? 1'b1 : 1'b0;
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      sd_bs_o <= 1'b0;
    end else begin
      if(fs_ce == 1'b1) begin
        if(tx_ip_sync == 1'b0) begin
          sd_bs_o <= 1'b0;
        end
        else begin
          if(stuff == 1'b1) begin
            sd_bs_o <= 1'b0;
          end
          else begin
            sd_bs_o <= sd_raw_o;
          end
        end
      end
    end
  end

  //======================================================================================--
  // NRZI Encoder                                                                       --
  //======================================================================================--
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      sd_nrzi_o <= 1'b1;
    end else begin
      if(tx_ip_sync == 1'b0 || txoe_r1 == 1'b0 || R_LineCtrl_i == 1'b1) begin
        if(R_LineCtrl_i == 1'b1) begin
          sd_nrzi_o <= S_long;
        end
        else begin
          sd_nrzi_o <= 1'b1;
        end
      end
      else if(fs_ce == 1'b1) begin
        if(sd_bs_o == 1'b1) begin
          sd_nrzi_o <= sd_nrzi_o;
        end
        else begin
          sd_nrzi_o <=  ~sd_nrzi_o;
        end
      end
    end
  end

  //======================================================================================--
  // Output Enable Logic                                                                --
  //======================================================================================--
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      txoe_r1 <= 1'b0;
      txoe_r2 <= 1'b0;
      txoe <= 1'b1;
    end else begin
      if(fs_ce == 1'b1) begin
        txoe_r1 <= tx_ip_sync;
        txoe_r2 <= txoe_r1;
        txoe <=  ~(txoe_r1 | txoe_r2);
      end
    end
  end

  //======================================================================================--
  // Output Registers                                                                   --
  //======================================================================================--
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      txdp <= 1'b1;
      txdn <= 1'b0;
    end else begin
      if(fs_ce == 1'b1) begin
        if(phy_mode == 1'b1) begin
          txdp <=  ~se_state & sd_nrzi_o;
          txdn <=  ~se_state &  ~sd_nrzi_o;
        end
        else begin
          txdp <= sd_nrzi_o;
          txdn <= se_state;
        end
      end
    end
  end

  //======================================================================================--
  // Tx Statemashine                                                                    --
  //======================================================================================--
  assign any_eop_state = state[3];
  always @(posedge clk) begin
    if(rst == 1'b0) begin
      state <= IDLE_STATE;
    end else begin
      if(any_eop_state == 1'b0) begin
        case(state)
        IDLE_STATE : begin
          if(TxValid_i == 1'b1) begin
            R_LineCtrl_i <= LineCtrl_i;
            R_long_i <= DataOut_i[0];
            R_busreset_i <= DataOut_i[1];
            //                               IF DataOut_i(0) = '0' THEN
            //                                 state <= EOP1_STATE; -- fast but txready_o wrong
            //                               ELSE
            state <= SOP_STATE;
            //                               END IF;
          end
        end
        SOP_STATE : begin
          if(sft_done_e == 1'b1) begin
            state <= DATA_STATE;
          end
        end
        DATA_STATE : begin
          if(data_xmit == 1'b0 && sft_done_e == 1'b1) begin
            if(one_cnt == 3'b101 && hold_reg_d[7] == 1'b1) begin
              state <= EOP0_STATE;
            end
            else begin
              state <= EOP1_STATE;
            end
          end
        end
        WAIT_STATE : begin
          if(fs_ce == 1'b1) begin
            state <= IDLE_STATE;
          end
        end
        default : begin
          state <= IDLE_STATE;
        end
        endcase
      end
      else begin
        if(fs_ce == 1'b1) begin
          if(state == EOP5_STATE) begin
            state <= WAIT_STATE;
          end
          else begin
            state <= (state) + 1;
          end
        end
      end
    end
  end

  assign append_eop = (state[3:2] == 2'b11) ? 1'b1 : 1'b0;
  // EOP4_STATE OR EOP5_STATE
  assign se_state = append_eop == 1'b1 || (state != WAIT_STATE && R_LineCtrl_i == 1'b1 && R_long_i == 1'b1 && R_busreset_i == 1'b1) ? 1'b1 : 1'b0;
  assign ld_sop_d = state == IDLE_STATE ? TxValid_i : 1'b0;
  assign ld_data_d = state == SOP_STATE || (state == DATA_STATE && data_xmit == 1'b1) ? sft_done_e : 1'b0;
  assign S_long = state != WAIT_STATE && R_long_i == 1'b1 ? 1'b0 : 1'b1;

endmodule
