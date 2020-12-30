SOURCES := \
 	ics32.v \
 	picorv32.v \
	vexriscv/vexriscv_shared_bus.v \
 	cpu_ram.v \
 	vram.v \
 	address_decoder.v \
 	delay_ff.v \
 	flash_arbiter.v \
 	bus_arbiter.v \
 	reset_generator.v \
 	cpu_peripheral_sync.v \
 	flash_reader.v \
	ics_adpcm.v \
 	cop_ram.v \
 	mock_gamepad.v \
 	debouncer.v \
	dpram.v \

VDP_SOURCES := vdp/vdp.v \
	 $(addprefix vdp/vdp_, \
		scroll_pixel_generator.v \
		layer_priority_select.v \
		map_address_generator.v \
		tile_address_generator.v \
		host_interface.v \
		priority_compute.v \
		vga_timing.v \
		sprite_raster_collision.v \
	 	sprite_core.v \
	 	sprite_render.v \
	 	affine_layer.v \
	 	blender.v \
	 	copper.v \
		vram_bus_arbiter_interleaved.v \
		vram_bus_arbiter_standard.v \
	)

VEX_USE_BOOTLOADER ?= 1

VEX_RESET_BOOT = vexriscv/vexriscv_reset_60000.v
VEX_RESET_RAM = vexriscv/vexriscv_reset_00000.v

ifeq ($(VEX_USE_BOOTLOADER), 1)
VEX = $(VEX_RESET_BOOT)
else
VEX = $(VEX_RESET_RAM)
endif

ICEBREAKER_SOURCES := \
	$(addprefix icebreaker/, \
		pll_ice40.v \
		spram_256k.v \
		pdm_dac.v \
	)

USB_HID_SOURCES := \
	$(addprefix usb/, \
		usb_phy.v \
		usb_rx_phy.v \
		usb_tx_phy.v \
		usbh_crc5.v \
		usbh_crc16.v \
		usbh_host_hid.v \
		usbh_sie.v \
		gamepads/usbh_report_decoder_buffalo.v \
		gamepads/usbh_report_decoder_keypad.v \
		gamepads/usbh_report_decoder_wingman.v \
		gamepads/usb_gamepad_reader.v \
	)

ULX3S_SOURCES := \
	$(addprefix ulx3s/, \
		pll_ecp5.v \
		generated_pll_usb.v \
		generated_pll_25.v \
		generated_pll_33_75.v \
		hdmi_encoder.v \
		dacpwm.v \
		spdif_tx.v \
		esp32_spi_gamepad.v \
		ulx3s_gamepad_state.v \
		../common/spram_256k.v \
	)

JT51_SOURCES := \
	$(wildcard jt51/hdl/*.v)

ULX3S_SOURCES += $(USB_HID_SOURCES)
	
SOURCES += $(VDP_SOURCES)
SOURCES += $(JT51_SOURCES)
SOURCES += $(VEX)

