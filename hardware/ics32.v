// ics32.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32 #(
    parameter ENABLE_WIDESCREEN = 1,
    parameter FORCE_FAST_CPU = 0,
    parameter integer RESET_DURATION = 1 << 10,
    parameter ENABLE_IPL = 1
) (
    input clk_12m,

    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,

    output vga_hsync,
    output vga_vsync,

    output vga_clk,
    output vga_de,

    output led_r,
    output led_b,

    input btn1,
    input btn2,
    input btn3,

    output flash_sck,
    output flash_csn,
    output flash_mosi,
    input flash_miso
);
    localparam ENABLE_FAST_CPU = !ENABLE_WIDESCREEN || FORCE_FAST_CPU;

    // --- LEDs ---

    reg [1:0] status;
    assign led_r = status[0];
    assign led_b = status[1];

    always @(posedge vdp_clk) begin
        if (vdp_reset) begin
            status <= 2'b01;
        end else if (status_write_en) begin
            status <= cpu_write_data[1:0];
        end
    end

    // --- DSP math support --- (TODO extract)

    reg [15:0] dsp_mult_a, dsp_mult_b;
    reg [31:0] dsp_result;

    // the dsp_mult_a/b assignments can't be in nested if statements to infer the MAC16 FFs
    // otherwise, SB_DFFs are spent on this

    always @(posedge vdp_clk) begin
        if (dsp_write_en && !cpu_address[2]) begin
            dsp_mult_a <= cpu_write_data[15:0];
        end

        if (dsp_write_en && cpu_address[2]) begin
            dsp_mult_b <= cpu_write_data[15:0];
        end

        // signed only for now
        dsp_result <= $signed(dsp_mult_a) * $signed(dsp_mult_b);
    end

    // --- Reset generator ---

    wire reset_1x, reset_2x;

    reset_generator #(
        .DURATION(RESET_DURATION)
    ) reset_generator (
        .clk_1x(pll_clk_1x),
        .clk_2x(pll_clk_2x),
        .pll_locked(pll_locked),

        .reset_1x(reset_1x),
        .reset_2x(reset_2x)
    );

    // --- PLL (640x480 or 848x480 clock selection) ---

    wire pll_clk_1x, pll_clk_2x;
    wire pll_locked;

    pll #(
        .ENABLE_FAST_CLK(ENABLE_WIDESCREEN)
    ) pll (
        .clk_12m(clk_12m),

        .locked(pll_locked),
        .clk_1x(pll_clk_1x),
        .clk_2x(pll_clk_2x)
    );

    assign vga_clk = pll_clk_2x;

    wire cpu_clk, vdp_clk;
    wire cpu_reset, vdp_reset;

    generate
        if (!ENABLE_FAST_CPU) begin
            assign cpu_clk = pll_clk_1x;
            assign vdp_clk = pll_clk_2x;

            assign cpu_reset = reset_1x;
            assign vdp_reset = reset_2x;
        end else begin
            assign cpu_clk = pll_clk_2x;
            assign vdp_clk = pll_clk_2x;

            assign cpu_reset = reset_2x;
            assign vdp_reset = reset_2x;
        end
    endgenerate

    // --- Address deccoder ---

    wire vdp_en, vdp_write_en;
    wire cpu_ram_en_decoded, cpu_ram_write_en_decoded;
    wire status_en, status_write_en;
    wire flash_read_en;
    wire dsp_en, dsp_write_en;
    wire pad_en, pad_write_en;
    wire cop_ram_write_en;

    address_decoder #(
        .REGISTERED_INPUTS(!ENABLE_FAST_CPU)
    ) decoder (
        .clk(vdp_clk),
        .reset(vdp_reset),

        .cpu_address(cpu_address),
        .cpu_mem_valid(cpu_mem_valid),
        .cpu_wstrb(cpu_wstrb),

        .vdp_en(vdp_en),
        .vdp_write_en(vdp_write_en),

        .status_en(status_en),
        .status_write_en(status_write_en),

        .cpu_ram_en(cpu_ram_en_decoded),
        .cpu_ram_write_en(cpu_ram_write_en_decoded),

        .dsp_en(dsp_en),
        .dsp_write_en(dsp_write_en),

        .pad_en(pad_en),
        .pad_write_en(pad_write_en),

        .cop_ram_write_en(cop_ram_write_en),

        .flash_read_en(flash_read_en)
    );

    wire active_display;
    assign vga_de = active_display;

    // --- Copper RAM ---

    wire [10:0] cop_ram_write_address = {cpu_address[11:2], cpu_wstrb[2]};
    wire [15:0] cop_ram_read_data;

    wire [10:0] cop_ram_read_address;
    wire cop_ram_read_en;
    
    cop_ram cop_ram(
        .clk(vdp_clk),

        .write_address(cop_ram_write_address),
        .write_data(cpu_write_data[15:0]),
        .write_en(cop_ram_write_en),

        .read_address(cop_ram_read_address),
        .read_data(cop_ram_read_data),
        .read_en(cop_ram_read_en)
    );

    // --- 1x <-> 2x clock sync (if required) ---

    wire [23:0] cpu_address;
    wire cpu_mem_valid;
    wire [3:0] cpu_wstrb;
    wire [31:0] cpu_write_data;

    localparam CPU_NEEDS_SYNC = ENABLE_WIDESCREEN;

    generate
        if (!ENABLE_FAST_CPU) begin
            cpu_peripheral_sync cpu_peripheral_sync(
                .clk_1x(pll_clk_1x),
                .clk_2x(pll_clk_2x),

                // 1x inputs
                .cpu_address(cpu_address_1x),
                .cpu_wstrb(cpu_wstrb_1x),
                .cpu_write_data(cpu_write_data_1x),
                .cpu_mem_valid(cpu_mem_valid_1x),

                // 2x inputs
                .cpu_mem_ready(cpu_mem_ready),
                .cpu_read_data(cpu_read_data),

                // 1x outputs (back to CPU)
                .cpu_read_data_1x(cpu_read_data_1x),
                .cpu_mem_ready_1x(cpu_mem_ready_1x),

                // 2x outputs
                .cpu_wstrb_2x(cpu_wstrb),
                .cpu_write_data_2x(cpu_write_data),
                .cpu_address_2x(cpu_address),
                .cpu_mem_valid_2x(cpu_mem_valid)
            );
        end else begin
            assign cpu_wstrb = cpu_wstrb_1x;
            assign cpu_address = cpu_address_1x;
            assign cpu_write_data = cpu_write_data_1x;
            assign cpu_mem_valid = cpu_mem_valid_1x;

            assign cpu_read_data_1x = cpu_read_data;
            assign cpu_mem_ready_1x = cpu_mem_ready;
        end
    endgenerate

    // --- VDP ---

    wire vdp_active_frame_ended;
    wire vdp_target_raster_hit;

    wire [6:0] vdp_write_address = {cpu_address[15:2], cpu_wstrb[2]};

    wire vdp_read_en = vdp_en && !vdp_write_en;

    // FIXME: this isn't actually used???
    wire [15:0] vdp_read_data;
    wire vdp_ready;

    wire [13:0] vram_address_odd;
    wire [13:0] vram_address_even;

    wire vram_we_even;
    wire vram_we_odd;
    wire [15:0] vram_write_data_even;
    wire [15:0] vram_write_data_odd;

    wire [15:0] vram_read_data_even;
    wire [15:0] vram_read_data_odd;

    vdp # (
        .ENABLE_WIDESCREEN(ENABLE_WIDESCREEN)
    ) vdp (
        .clk(vdp_clk),
        .reset(vdp_reset),

        .host_address(vdp_write_address),
        .host_read_en(vdp_read_en),
        .host_write_en(vdp_write_en),
        .host_read_data(vdp_read_data),
        .host_ready(vdp_ready),
        .host_write_data(cpu_write_data[15:0]),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .r(vga_r),
        .g(vga_g),
        .b(vga_b),

        .active_display(active_display),
        .target_raster_hit(vdp_target_raster_hit),
        .active_frame_ended(vdp_active_frame_ended),
        
        .vram_address_even(vram_address_even),
        .vram_we_even(vram_we_even),
        .vram_write_data_even(vram_write_data_even),
        .vram_read_data_even(vram_read_data_even),

        .vram_address_odd(vram_address_odd),
        .vram_we_odd(vram_we_odd),
        .vram_write_data_odd(vram_write_data_odd),
        .vram_read_data_odd(vram_read_data_odd),

        .cop_ram_read_en(cop_ram_read_en),
        .cop_ram_read_address(cop_ram_read_address),
        .cop_ram_read_data(cop_ram_read_data)
    );

    vram vram(
        .clk(vdp_clk),

        .even_address(vram_address_even),
        .odd_address(vram_address_odd),
        .even_write_en(vram_we_even),
        .odd_write_en(vram_we_odd),
        .write_data({vram_write_data_odd, vram_write_data_even}),

        .read_data({vram_read_data_odd, vram_read_data_even})
    );

    // --- CPU RAM ---

    wire [31:0] cpu_ram_data_out;

    cpu_ram cpu_ram(
        .clk(vdp_clk),

        .address(cpu_ram_address),
        .write_en(cpu_ram_write_en),
        .cs(cpu_ram_cs),
        .wstrb(cpu_ram_wstrb),
        .write_data(cpu_ram_data_in),

        .read_data(cpu_ram_data_out)
    );

    // --- Gamepad reading --- (TODO, 3 buttons on breakout board for now)

    wire [1:0] pad_read_data;
    reg [1:0] pad_ctrl;

    wire pad_latch = pad_ctrl[0];
    wire pad_clk = pad_ctrl[1];

    reg pad_clk_r;

    always @(posedge vdp_clk) begin
        if (pad_write_en) begin
            pad_ctrl <= cpu_write_data[1:0];
        end
    end

    // --- Gamepad mocking using iCEBreaker buttons (temporary) ---

    reg [15:0] pad_mock_state;
    assign pad_read_data[0] = pad_mock_state[0];
    assign pad_read_data[1] = 0;

    always @(posedge vdp_clk) begin
        if (pad_latch) begin
            // left, right, B inputs respectively
            pad_mock_state <= {btn1, btn3, 5'b0, btn2};
        end

        if (pad_clk && !pad_clk_r) begin
            pad_mock_state <= {1'b0, pad_mock_state[15:1]};
        end

        pad_clk_r <= pad_clk;
    end

    // --- Bus arbiter ---

    wire [31:0] cpu_read_data;
    wire cpu_mem_ready;

    wire [31:0] cpu_ram_data_in;
    wire [14:0] cpu_ram_address;
    wire [3:0] cpu_ram_wstrb;
    wire cpu_ram_cs;
    wire cpu_ram_write_en;

    bus_arbiter #(
        .SUPPORT_2X_CLK(!ENABLE_FAST_CPU)
    ) bus_arbiter (
        .clk(vdp_clk),

        // inputs

        .cpu_address(cpu_address),
        .cpu_write_data(cpu_write_data),
        .cpu_wstrb(cpu_wstrb),

        .dma_busy(dma_busy),
        .dma_write_data(dma_write_data),
        .dma_address(dma_write_address),
        .dma_wstrb(dma_wstrb),

        .cpu_ram_en_decoded(cpu_ram_en_decoded),
        .cpu_ram_write_en_decoded(cpu_ram_write_en_decoded),
        .vdp_en(vdp_en),
        .flash_read_en(flash_read_en),
        .dsp_en(dsp_en),
        .status_en(status_en),
        .pad_en(pad_en),
        .cop_en(cop_ram_write_en),

        .flash_read_ready(flash_read_ready),
        .vdp_ready(vdp_ready),

        // outputs

        .cpu_ram_read_data(cpu_ram_data_out),
        .flash_read_data(flash_read_data),
        .dsp_read_data(dsp_result),
        .vdp_read_data(vdp_read_data),
        .pad_read_data(pad_read_data),

        .cpu_mem_ready(cpu_mem_ready),
        .cpu_read_data(cpu_read_data),

        .cpu_ram_write_data(cpu_ram_data_in),
        .cpu_ram_address(cpu_ram_address),
        .cpu_ram_wstrb(cpu_ram_wstrb),
        .cpu_ram_cs(cpu_ram_cs),
        .cpu_ram_write_en(cpu_ram_write_en)
    );

    // --- CPU ---

    wire [31:0] cpu_address_1x;
    wire [3:0] cpu_wstrb_1x;
    wire cpu_mem_valid_1x;
    wire [31:0] cpu_write_data_1x;

    wire [31:0] cpu_read_data_1x;
    wire cpu_mem_ready_1x;

    // verilator lint_save
    // verilator lint_off PINMISSING

    picorv32 #(
        .ENABLE_TRACE(0),
        // register file gets inferred as BRAMs so using rv32e has little practical gain
        .ENABLE_REGS_16_31(1),

        // MMIO DSP is used instead of the included PCPI implementation
        .ENABLE_FAST_MUL(0),

        .PROGADDR_RESET(32'h0),
        // SP defined by software
        // .STACKADDR(32'h0001_0000),
        
        // this greatly helps shfit speed but is still an optional extra that could be removed
        .TWO_STAGE_SHIFT(1),

        // huge cell savings with this enabled
        .TWO_CYCLE_ALU(1),

        // moderate savings on these and not really expecting trouble with aligned C-generated code
        .CATCH_MISALIGN(0),
        .CATCH_ILLINSN(0),

        // this seems neutral at best even with retiming?
        .TWO_CYCLE_COMPARE(0),

        // rdcycle(h) instructions are not needed
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),

        // IRQ now disabled (vdp_copper to be used instead)
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_QREGS(0),
        .ENABLE_IRQ_TIMER(0)
    ) pico (
        .clk(cpu_clk),
        .resetn(!cpu_reset),

        .mem_ready(cpu_mem_ready_1x),
        .mem_valid(cpu_mem_valid_1x),
        .mem_addr(cpu_address_1x),
        .mem_rdata(cpu_read_data_1x),
        .mem_wdata(cpu_write_data_1x),
        .mem_wstrb(cpu_wstrb_1x),

        .irq(0)
    );
    
    // verilator lint_restore

    // --- Flash interface ---

    wire [31:0] dma_write_data;
    wire [3:0] dma_wstrb;
    wire [31:0] dma_write_address;
    wire dma_busy;

    wire flash_read_ready;
    wire [31:0] flash_read_data;

    flash_dma #(
        .ENABLE_IPL(ENABLE_IPL)
    ) dma (
        .clk(vdp_clk),
        .reset(vdp_reset),

        .read_address(cpu_address[19:0]),
        .read_data(flash_read_data),
        .read_en(flash_read_en),
        .read_ready(flash_read_ready),

        .write_address(dma_write_address),
        .write_data(dma_write_data),
        .dma_busy(dma_busy),
        .wstrb(dma_wstrb),

        .flash_sck(flash_sck),
        .flash_csn(flash_csn),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso)
    );

endmodule
