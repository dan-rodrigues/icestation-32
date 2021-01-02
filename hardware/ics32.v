// ics32.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "bus_arbiter.vh"
`include "clocks.vh"

module ics32 #(
    parameter integer CLK_1X_FREQ = `CLK_1X_WIDESCREEN,
    parameter integer CLK_2X_FREQ = `CLK_2X_WIDESCREEN,
    parameter [0:0] USE_VEXRISCV = 1,
    parameter [0:0] ENABLE_WIDESCREEN = 1,
    parameter [0:0] ENABLE_FAST_CPU = 0,
    parameter integer RESET_DURATION_EXPONENT = 2,
    parameter [0:0] ENABLE_BOOTLOADER = 1,
    parameter integer BOOTLOADER_SIZE = 256,
    parameter ADPCM_STEP_LUT_PATH = "adpcm_step_lut.hex",
    parameter [0:0] YM2151_PMOD = 1,
`ifdef BOOTLOADER
    parameter BOOTLOADER_PATH = `BOOTLOADER
`else
    parameter BOOTLOADER_PATH = "boot.hex"
`endif
) (
    input clk_1x,
    input clk_2x,
    input pll_locked,

    output reset_1x,
    output reset_2x,

    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,

    output vga_hsync,
    output vga_vsync,
    output vga_de,

    output [7:0] led,

    output pad_latch,
    output pad_clk,
    input [1:0] pad_data,

    input user_button,

    output [1:0] flash_clk_ddr,
    output flash_csn,
    output [3:0] flash_in,
    output [3:0] flash_in_en,
    input [3:0] flash_out,

    // YM PMOD test

    output ym_pmod_clk,
    output ym_pmod_shift_clk,
    output ym_pmod_shift_out,
    output ym_pmod_shift_load,

    input ym_pmod_dac_clk,
    input ym_pmod_dac_so,
    input ym_pmod_dac_sh1,
    input ym_pmod_dac_sh2,

    // Original outputs 
    output [15:0] audio_output_l,
    output [15:0] audio_output_r,
    output audio_output_valid
);
    // --- Bootloader ---

    localparam BOOTLOADER_ADDRESS_WIDTH = $clog2(BOOTLOADER_SIZE);

    reg [31:0] bootloader [0:BOOTLOADER_SIZE - 1];

    reg [31:0] bootloader_read_data;

    initial begin
        $readmemh(BOOTLOADER_PATH, bootloader);
    end

    always @(posedge cpu_clk) begin
        bootloader_read_data <= bootloader[cpu_address_1x[BOOTLOADER_ADDRESS_WIDTH + 1:2]];
    end

    // --- LEDs ---

    // LEDs are used to track some 2151 state below
    // --- DSP math support ---

    reg [15:0] dsp_mult_a, dsp_mult_b;
    reg [31:0] dsp_result;

    // The dsp_mult_a/b assignments can't be in nested if statements to infer the MAC16 FFs
    // Otherwise, SB_DFFs are spent on this

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

    reset_generator #(
        .DURATION_EXPONENT(RESET_DURATION_EXPONENT)
    ) reset_generator (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .pll_locked(pll_locked),

        .reset_1x(reset_1x),
        .reset_2x(reset_2x)
    );

    // --- Clock Assignment ---

    wire cpu_clk, vdp_clk;
    wire cpu_reset, vdp_reset;

    generate
        if (!ENABLE_FAST_CPU) begin
            assign cpu_clk = clk_1x;
            assign vdp_clk = clk_2x;

            assign cpu_reset = reset_1x;
            assign vdp_reset = reset_2x;
        end else begin
            assign cpu_clk = clk_2x;
            assign vdp_clk = clk_2x;

            assign cpu_reset = reset_2x;
            assign vdp_reset = reset_2x;
        end
    endgenerate

    // --- Address deccoder ---

    wire vdp_en, vdp_write_en;
    wire audio_ctrl_en, audio_ctrl_write_en;
    wire status_en, status_write_en;
    wire flash_read_en;
    wire dsp_en, dsp_write_en;
    wire pad_en, pad_write_en;
    wire cop_ram_write_en;
    wire flash_ctrl_en, flash_ctrl_write_en;

    wire [3:0] cpu_wstrb_decoder;

    address_decoder #(
        .REGISTERED_INPUTS(!ENABLE_FAST_CPU)
    ) decoder (
        .clk(vdp_clk),
        .reset(vdp_reset),

        .cpu_address(cpu_address),
        .cpu_mem_valid(cpu_mem_valid),
        .cpu_wstrb(cpu_wstrb),
        .cpu_wstrb_decoder(cpu_wstrb_decoder),

        .audio_ctrl_en(audio_ctrl_en),
        .audio_ctrl_write_en(audio_ctrl_write_en),

        .vdp_en(vdp_en),
        .vdp_write_en(vdp_write_en),

        .status_en(status_en),
        .status_write_en(status_write_en),

        .dsp_en(dsp_en),
        .dsp_write_en(dsp_write_en),

        .pad_en(pad_en),
        .pad_write_en(pad_write_en),

        .cop_ram_write_en(cop_ram_write_en),

        .flash_read_en(flash_read_en),

        .flash_ctrl_en(flash_ctrl_en),
        .flash_ctrl_write_en(flash_ctrl_write_en),

        // Unused (handled by 1x decoder)
        .cpu_ram_en(),
        .cpu_ram_write_en(),
        .bootloader_en()
    );

    wire active_display;
    assign vga_de = active_display;

    // --- Copper RAM ---

    wire [10:0] cop_ram_write_address = {cpu_address[11:2], cpu_wstrb_decoder[2]};
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

    // --- CPU 1x memory decoder / arbiter ---

    wire bootloader_en;
    wire cpu_ram_en, cpu_ram_write_en;

    address_decoder decoder_1x(
        .clk(cpu_clk),
        .reset(cpu_reset),

        .cpu_address(cpu_address_1x),
        .cpu_mem_valid(cpu_mem_valid_1x),
        .cpu_wstrb(cpu_wstrb_1x),

        .cpu_ram_en(cpu_ram_en),
        .cpu_ram_write_en(cpu_ram_write_en),

        .bootloader_en(bootloader_en),

        // Unused outputs (handled by 2x decoder)
        .cpu_wstrb_decoder(),
        .vdp_en(),
        .audio_ctrl_en(),
        .audio_ctrl_write_en(),
        .status_en(),
        .status_write_en(),
        .flash_read_en(),
        .dsp_write_en(),
        .pad_en(),
        .pad_write_en(),
        .cop_ram_write_en(),
        .flash_ctrl_en()
    );

    wire [31:0] cpu_read_data_1x_arbiter;
    wire cpu_mem_ready_1x_arbiter;

    bus_arbiter #(
        .SUPPORT_2X_CLK(0),
        .READ_SOURCES(`BA_CPU_RAM | `BA_BOOT)
    ) bus_arbiter_1x (
        .clk(cpu_clk),

        // Inputs

        .cpu_address(cpu_address_1x),
        .cpu_write_data(cpu_write_data_1x),
        .cpu_wstrb(cpu_wstrb_1x),

        .bootloader_en(bootloader_en),
        .cpu_ram_en(cpu_ram_en),
        .vdp_en(0),
        .flash_read_en(0),
        .dsp_en(0),
        .status_en(0),
        .pad_en(0),
        .cop_en(0),
        .flash_ctrl_en(0),
        .audio_ctrl_en(0),

        .flash_read_ready(0),
        .vdp_ready(0),
        .audio_ready(0),

        .bootloader_read_data(bootloader_read_data),
        .cpu_ram_read_data(cpu_ram_read_data),
        .flash_read_data(0),
        .dsp_read_data(0),
        .vdp_read_data(0),
        .pad_read_data(0),
        .flash_ctrl_read_data(0),
        .audio_cpu_read_data(0),

        // Outputs

        .cpu_mem_ready(cpu_mem_ready_1x_arbiter),
        .cpu_read_data(cpu_read_data_1x_arbiter)
    );

    // --- 1x <-> 2x clock sync (if required) ---

    wire [31:0] cpu_read_data_2x_source;
    wire cpu_mem_ready_2x_source;
    wire cpu_access_1x = bootloader_en || cpu_ram_en;

    assign cpu_read_data_1x = cpu_access_1x ? cpu_read_data_1x_arbiter : cpu_read_data_2x_source;
    assign cpu_mem_ready_1x = cpu_access_1x ? cpu_mem_ready_1x_arbiter : cpu_mem_ready_2x_source;

    generate
        if (!ENABLE_FAST_CPU) begin
            wire [31:0] cpu_read_data_2x_sync;
            wire cpu_mem_ready_2x_sync;

            assign cpu_read_data_2x_source = cpu_read_data_2x_sync;
            assign cpu_mem_ready_2x_source = cpu_mem_ready_2x_sync;

            cpu_peripheral_sync cpu_peripheral_sync(
                .clk_1x(clk_1x),
                .clk_2x(clk_2x),

                // 1x inputs
                .cpu_address(cpu_address_1x),
                .cpu_wstrb(cpu_wstrb_1x),
                .cpu_write_data(cpu_write_data_1x),
                .cpu_mem_valid(cpu_mem_valid_1x),

                // 2x inputs
                .cpu_mem_ready(cpu_mem_ready),
                .cpu_read_data(cpu_read_data),

                // 1x outputs (back to CPU)
                .cpu_read_data_1x(cpu_read_data_2x_sync),
                .cpu_mem_ready_1x(cpu_mem_ready_2x_sync),

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

            assign cpu_read_data_2x_source = cpu_read_data;
            assign cpu_mem_ready_2x_source = cpu_mem_ready;
        end
    endgenerate

    // --- VDP ---

    wire vdp_active_frame_ended;

    wire [6:0] vdp_write_address = {cpu_address[15:2], cpu_wstrb_decoder[2]};

    wire vdp_read_en = vdp_en && !vdp_write_en;

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
        .cop_ram_read_data(cop_ram_read_data),

        .frame_ended()
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

    // --- YM2151 Audio (experimental replacement of ADPCM core) ---

    wire audio_ym_write = !cpu_address[3] && audio_ctrl_write_en;
    wire audio_prescaler_write = cpu_address[3] && audio_ctrl_write_en;

    reg audio_ctrl_en_r;
    wire audio_ctrl_ready = audio_ctrl_en && !audio_ctrl_en_r;

    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            audio_ctrl_en_r <= 0;
        end else begin
            audio_ctrl_en_r <= audio_ctrl_en;
        end
    end

    // Prescaler defined by software:

    reg [31:0] ym_prescaler;

    always @(posedge cpu_clk) begin
        if (audio_prescaler_write) begin
            ym_prescaler <= cpu_write_data;
        end
    end

    reg [32:0] ym_prescaler_fraction;
    reg ym_prescaler_tick;

    // jt51 uses a clock enable so it doesn't need to be multiplied (1x)
    // Real YM2151 is given an actual clock signal so it must toggle twice in a given period (2x)

    localparam YM_PRESCALER_MULITPLIER = YM2151_PMOD ? 2 : 1;

    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            ym_prescaler_tick <= 0;
            ym_prescaler_fraction <= 0;
        end else begin
            ym_prescaler_tick <= 0;
            ym_prescaler_fraction <= ym_prescaler_fraction + {1'b0, ym_prescaler * YM_PRESCALER_MULITPLIER};

            if (ym_prescaler_fraction[32]) begin
                ym_prescaler_tick <= 1;
                ym_prescaler_fraction[32] <= 0;
            end
        end
    end

    reg ym_cen, ym_cen_p1;
    reg ym_cen_p1_toggle;

    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            ym_cen <= 0;
            ym_cen_p1 <= 0;
            ym_cen_p1_toggle <= 0;
        end else begin
            ym_cen <= 0;
            ym_cen_p1 <= 0;

            if (ym_prescaler_tick) begin
                // 3.58MHz clock enable
                ym_cen <= 1;

                // 1.79MHz clock enable
                ym_cen_p1 <= ym_cen_p1_toggle;
                ym_cen_p1_toggle <= !ym_cen_p1_toggle;
            end
        end
    end

    // YM control:

    reg audio_ym_write_r;
    wire ym_write_needed = audio_ym_write && !audio_ym_write_r;

    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            audio_ym_write_r <= 0;
        end else begin
            audio_ym_write_r <= audio_ym_write;
        end
    end

    // YM pending writes:

    reg [7:0] ym_write_data;
    reg ym_write_address;

    always @(posedge cpu_clk) begin
        if (ym_write_needed) begin
            ym_write_data <= cpu_write_data[7:0];
            ym_write_address <= cpu_address[2];
        end
    end

    // YM sample output (55KHz~, depends on prescaler)

    assign audio_output_l = ym_xleft;
    assign audio_output_r = ym_xright;
    assign audio_output_valid = ym_output_valid && !ym_output_valid_r;

    reg ym_output_valid_r;

    always @(posedge cpu_clk) begin
        ym_output_valid_r <= ym_output_valid;
    end

    // Writes are handled independently of cen_*

    reg ym_write_en;

    always @(posedge cpu_clk) begin
        ym_write_en <= ym_write_needed;
    end


    wire [7:0] ym_read_data;

    wire [15:0] ym_xleft, ym_xright;
    wire ym_output_valid;

    generate
        if (YM2151_PMOD) begin
            // Option A: Real YM2151 in a PMOD

            reg ym_clk;

            always @(posedge cpu_clk) begin
                if (ym_prescaler_tick) begin
                    ym_clk <= !ym_clk;
                end
            end

            assign ym_pmod_clk = ym_clk;

            wire dbg_dac_clk_rose;

            // LEDs:

            // 0: Audio sample counter (assuming DAC is actually doing something useful)

            reg [15:0] audio_output_counter;
            assign led[0] = audio_output_counter[15];

            always @(posedge cpu_clk) begin
                if (audio_output_valid) begin
                    audio_output_counter <= audio_output_counter + 1;
                end
            end

            // 1: YM2151 DAC clock input

            reg [19:0] dac_clk_in_counter;
            assign led[1] = dac_clk_in_counter[19];

            always @(posedge cpu_clk) begin
                if (dbg_dac_clk_rose) begin
                    dac_clk_in_counter <= dac_clk_in_counter + 1;
                end
            end

            ym2151_pmod_interface ym2151_pmod_interface(
                .clk(cpu_clk),
                .ym_clk(ym_clk),
                .reset(cpu_reset),

                .wr_n(!ym_write_en),
                .a0(ym_write_address),
                .din(ym_write_data),
                .busy(ym_read_data[7]),

                // PMOD I/O

                .pmod_shift_clk(ym_pmod_shift_clk),
                .pmod_shift_out(ym_pmod_shift_out),
                .pmod_shift_load(ym_pmod_shift_load),

                .pmod_dac_clk(ym_pmod_dac_clk),
                .pmod_dac_so(ym_pmod_dac_so),
                .pmod_dac_sh1(ym_pmod_dac_sh1),
                .pmod_dac_sh2(ym_pmod_dac_sh2),

                // Audio output

                .audio_valid(ym_output_valid),
                .audio_left(audio_output_l),
                .audio_right(audio_output_r),

                // Test

                .dbg_dac_clk_rose(dbg_dac_clk_rose)
            );
        end else begin
            // Option B: YM2151 compatible core:

            assign ym_pmod_clk = 0;
            assign ym_pmod_shift_clk = 0;
            assign ym_pmod_shift_out = 0;
            assign ym_pmod_shift_load = 0;

            jt51 jt51(
                .clk(cpu_clk),
                .rst(cpu_reset),
                .cen(ym_cen),
                .cen_p1(ym_cen_p1),

                .cs_n(!ym_write_en),
                .wr_n(!ym_write_en),
                .a0(ym_write_address),
                .din(ym_write_data),
                .dout(ym_read_data),

                .irq_n(),

                .sample(ym_output_valid),
                .xleft(ym_xleft),
                .xright(ym_xright)
            );
        end
    endgenerate

    /* verilator public_module */

    // --- CPU RAM ---

    wire [31:0] cpu_ram_read_data;

    cpu_ram cpu_ram(
        .clk(cpu_clk),

        .address(cpu_address_1x[15:2]),
        .write_en(cpu_ram_write_en),
        .cs(cpu_ram_en),
        .wstrb(cpu_wstrb_1x),
        .write_data(cpu_write_data_1x),

        .read_data(cpu_ram_read_data)
    );

    // --- Gamepad IO ---

    reg [1:0] pad_ctrl;

    assign pad_latch = pad_ctrl[0];
    assign pad_clk = pad_ctrl[1];

    always @(posedge vdp_clk) begin
        if (pad_write_en) begin
            pad_ctrl <= cpu_write_data[1:0];
        end
    end

    // --- Bus arbiter ---

    wire [31:0] cpu_address;
    wire cpu_mem_valid;
    wire [3:0] cpu_wstrb;
    wire [31:0] cpu_write_data;
    wire [31:0] cpu_read_data;
    wire cpu_mem_ready;

    bus_arbiter #(
        .SUPPORT_2X_CLK(!ENABLE_FAST_CPU),
        .READ_SOURCES(`BA_VDP | `BA_FLASH | `BA_DSP | `BA_PAD | `BA_FLASH_CTRL | `BA_AUDIO)
    ) bus_arbiter (
        .clk(vdp_clk),

        // Inputs

        .cpu_address(cpu_address),
        .cpu_write_data(cpu_write_data),
        .cpu_wstrb(cpu_wstrb),

        .bootloader_en(0),
        .cpu_ram_en(0),
        .vdp_en(vdp_en),
        .flash_read_en(flash_read_en),
        .dsp_en(dsp_en),
        .status_en(status_en),
        .pad_en(pad_en),
        .cop_en(cop_ram_write_en),
        .flash_ctrl_en(flash_ctrl_en),
        .audio_ctrl_en(audio_ctrl_en),

        .flash_read_ready(flash_read_ready),
        .vdp_ready(vdp_ready),
        .audio_ready(audio_ctrl_ready),

        .bootloader_read_data(0),
        .cpu_ram_read_data(0),
        .flash_read_data(flash_read_data),
        .dsp_read_data(dsp_result),
        .vdp_read_data(vdp_read_data),
        .pad_read_data({user_button, pad_data}),
        .flash_ctrl_read_data(flash_ctrl_read_data),
        .audio_cpu_read_data(ym_read_data),

        // Outputs

        .cpu_mem_ready(cpu_mem_ready),
        .cpu_read_data(cpu_read_data)
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

    localparam CPU_RESET_PC = ENABLE_BOOTLOADER ? 32'h60000 : 32'h00000;

    generate
        if (USE_VEXRISCV) begin
            vexriscv_shared_bus vex_shared_bus(
                .clk(cpu_clk),
                .reset(cpu_reset),

                .mem_ready(cpu_mem_ready_1x),
                .mem_valid(cpu_mem_valid_1x),
                .mem_addr(cpu_address_1x),
                .mem_rdata(cpu_read_data_1x),
                .mem_wdata(cpu_write_data_1x),
                .mem_wstrb(cpu_wstrb_1x)
            );
        end else begin
            picorv32 #(
                .ENABLE_TRACE(0),

                // Register file gets inferred as BRAMs so using rv32e has little practical gain
                .ENABLE_REGS_16_31(1),

                // MMIO DSP is used instead of the included PCPI implementation
                .ENABLE_FAST_MUL(0),

                .PROGADDR_RESET(CPU_RESET_PC),
                // SP defined by software
                // .STACKADDR(32'h0001_0000),
                
                // Greatly helps shift speed but still an optional extra that could be removed
                .BARREL_SHIFTER(1),

                // Moderate savings and not really expecting trouble with aligned C code
                .CATCH_MISALIGN(0),
                .CATCH_ILLINSN(0),

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
        end
    endgenerate
    
    // verilator lint_restore

    // --- Flash IO ---

    assign flash_clk_ddr = flash_ctrl_active ? {2{flash_ctrl_clk}} : {1'b0, flash_dma_clk_en};
    wire flash_dma_clk_en;

    assign flash_in = flash_ctrl_active ? flash_ctrl_in : flash_dma_in;
    assign flash_in_en = flash_ctrl_active ? flash_ctrl_in_en : flash_dma_in_en;

    assign flash_csn = flash_ctrl_active ? flash_ctrl_csn : flash_dma_csn;

    // --- Flash arbiter ---

    wire flash_read_ready;
    wire [31:0] flash_read_data;

    wire flash_dma_clk, flash_dma_csn;
    wire [3:0] flash_dma_in_en;
    wire [3:0] flash_dma_in;

    flash_arbiter flash_arbiter(
        .clk(vdp_clk),
        .reset(vdp_reset),

        // Reader A: CPU

        .read_address_a({cpu_address[23:2], 2'b00}),
        .read_en_a(flash_read_en),
        .ready_a(flash_read_ready),

        // 32bit reads (full size)
        .size_a(1),

        // Reader B: None, previously ADPCM core

        .read_address_b(0),
        .read_en_b(0),
        .ready_b(),
        
        // 16bit reads
        .size_b(0),

        // Flash read data

        .read_data(flash_read_data),

        // Flash interface

        .flash_clk_en(flash_dma_clk_en),
        .flash_csn(flash_dma_csn),
        .flash_in_en(flash_dma_in_en),
        .flash_in(flash_dma_in),

        .flash_out(flash_out)
    );

    // --- Flash CPU control ---

    reg flash_ctrl_active;

    reg [3:0] flash_ctrl_in;
    reg [3:0] flash_ctrl_in_en;
    reg flash_ctrl_clk;
    reg flash_ctrl_csn;

    wire flash_ctrl_active_data = cpu_write_data[15];
    wire [3:0] flash_ctrl_in_data = cpu_write_data[3:0];
    wire [3:0] flash_ctrl_in_en_data = cpu_write_data[7:4];
    wire flash_ctrl_clk_data = cpu_write_data[8];
    wire flash_ctrl_csn_data = cpu_write_data[9];

    // It's expected that flash_out is registered in the parent module (SB_IO reg for iCE40)
    wire [3:0] flash_ctrl_read_data = flash_out;

    always @(posedge vdp_clk) begin
        if (vdp_reset) begin
            flash_ctrl_clk <= 0;
            flash_ctrl_in_en <= 0;
        end

        if (flash_ctrl_write_en) begin
            flash_ctrl_in <= flash_ctrl_in_data;
            flash_ctrl_in_en <= flash_ctrl_in_en_data;
            flash_ctrl_clk <= flash_ctrl_clk_data;
            flash_ctrl_csn <= flash_ctrl_csn_data;
        end
    end

    always @(posedge vdp_clk) begin
        if (vdp_reset) begin
            flash_ctrl_active <= 0;
        end else if (flash_ctrl_write_en) begin
            flash_ctrl_active <= flash_ctrl_active_data;
        end
    end

endmodule
