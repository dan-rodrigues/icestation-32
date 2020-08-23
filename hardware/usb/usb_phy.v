// File ../../../../usb11_phy_vhdl/usb_phy.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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
// no timescale needed

module usb_phy(
input wire clk,
input wire rst,
input wire phy_tx_mode,
output wire usb_rst,
input wire rxd,
input wire rxdp,
input wire rxdn,
output wire txdp,
output wire txdn,
output wire txoe,
output wire ce_o,
output wire sync_err_o,
output wire bit_stuff_err_o,
output wire byte_err_o,
input wire LineCtrl_i,
input wire [7:0] DataOut_i,
input wire TxValid_i,
output wire TxReady_o,
output wire [7:0] DataIn_o,
output wire RxValid_o,
output wire RxActive_o,
output wire RxError_o,
output wire [1:0] LineState_o
);

parameter usb_rst_det=1'b1;
// 48 MHz
// active low
// HIGH level for differential io mode (else single-ended)
// Transciever Interface
// clk recovery debug
// RX debug interface
// UTMI Interface
// 0: normal data TX, 1: line control (for low speed usb)
// byte_to_send or LineCtrl mode (see usb_tx_phy)



//component usb_tx_phy
//port (
//  clk              : in  std_logic;
//  rst              : in  std_logic;
//  fs_ce            : in  std_logic;
//  phy_mode         : in  std_logic;
//  -- Transciever Interface
//  txdp, txdn, txoe : out std_logic;
//  -- UTMI Interface
//  DataOut_i        : in  std_logic_vector(7 downto 0);
//  TxValid_i        : in  std_logic;
//  TxReady_o        : out std_logic
//);
//end component;
//
//component usb_rx_phy
//port (
//  clk              : in  std_logic;
//  rst              : in  std_logic;
//  -- Transciever Interface
//  fs_ce            : out std_logic;
//  rxd, rxdp, rxdn  : in  std_logic;
//  -- UTMI Interface
//  DataIn_o         : out std_logic_vector(7 downto 0);
//  RxValid_o        : out std_logic;
//  RxActive_o       : out std_logic;
//  RxError_o        : out std_logic;
//  RxEn_i           : in  std_logic;
//  LineState        : out std_logic_vector(1 downto 0)
//);
//end component;
wire [1:0] LineState;
wire fs_ce;
reg [4:0] rst_cnt;
wire txoe_out;
reg usb_rst_out = 1'b0;
wire reset;

  //======================================================================================--
  // Misc Logic                                                                         --
  //======================================================================================--
  assign usb_rst = usb_rst_out;
  assign LineState_o = LineState;
  assign txoe = txoe_out;
  //======================================================================================--
  // TX Phy                                                                             --
  //======================================================================================--
  usb_tx_phy i_tx_phy(
      .clk(clk),
    .rst(rst),
    .fs_ce(fs_ce),
    .phy_mode(phy_tx_mode),
    // Transciever Interface
    .txdp(txdp),
    .txdn(txdn),
    .txoe(txoe_out),
    // UTMI Interface
    .LineCtrl_i(LineCtrl_i),
    .DataOut_i(DataOut_i),
    .TxValid_i(TxValid_i),
    .TxReady_o(TxReady_o));

  //======================================================================================--
  // RX Phy and DPLL                                                                    --
  //======================================================================================--
  assign reset =  ~rst;
  usb_rx_phy E_rx_phy_emard(
      .clk(clk),
    .reset(reset),
    .clk_recovered_edge(fs_ce),
    // Transciever Interface
    .usb_dif(rxd),
    .usb_dp(rxdp),
    .usb_dn(rxdn),
    // UTMI Interface
    .data(DataIn_o),
    .valid(RxValid_o),
    .rx_active(RxActive_o),
    .rx_en(txoe_out),
    .linestate(LineState));

  assign RxError_o = 1'b0;
  assign ce_o = fs_ce;
  //======================================================================================--
  // Generate an USB Reset if we see SE0 for at least 2.5uS                             --
  //======================================================================================--
  generate if (usb_rst_det == 1'b1) begin: usb_rst_g
      always @(posedge clk) begin
      if(rst == 1'b0) begin
        rst_cnt <= {5{1'b0}};
      end else begin
        if(LineState != 2'b00) begin
          rst_cnt <= {5{1'b0}};
        end
        else if(usb_rst_out == 1'b0 && fs_ce == 1'b1) begin
          rst_cnt <= rst_cnt + 1;
        end
      end
    end

    always @(posedge clk) begin
      if(rst_cnt == 5'b11111) begin
        usb_rst_out <= 1'b1;
      end
      else begin
        usb_rst_out <= 1'b0;
      end
    end

  end
  endgenerate

endmodule
