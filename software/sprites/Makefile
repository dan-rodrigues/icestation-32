SOURCES = \
	main.c \
	../common/vectors.S \
	../common/start.S \
	../lib/vdp.c \
	../lib/math_util.c \
	../common/font.c \

HEADERS = \
	../common/font.h \
	../common/font8x8_basic.h \
	../lib/vdp.h \
	../lib/math_util.h \
	tiles.h \
	palette.h

include ../common/common.mk

# Ensure utility dependencies are up to date

PNG_CONVERTER_DIR = ../../utilities/png_convert/
PNG_CONVERTER = $(PNG_CONVERTER_DIR)ics-png-convert

pre-build:
	@$(MAKE) -C $(PNG_CONVERTER_DIR)

main-build: pre-build
	@$(MAKE) --no-print-directory $(BIN)

.PHONY: main-build

.DEFAULT_GOAL := main-build

###

PNG = crystal-32-ia.png

tiles.h palette.h: $(PNG) $(PNG_CONVERTER)
	$(PNG_CONVERTER) -f png $(PNG)

