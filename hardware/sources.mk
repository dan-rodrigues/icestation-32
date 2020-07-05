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
 	cop_ram.v \
 	flash_reader.v

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

ICEBREAKER_SRCS := \
	$(addprefix icebreaker/, \
		pll_ice40.v \
	)
	
SOURCES +=  $(VDP_SOURCES)
SOURCES += $(VEX)

