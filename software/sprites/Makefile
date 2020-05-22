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
	tiles.h \
	palette.h \
	sin_table.h

include ../common/common.mk

PNG = crystal-32-ia.png
PNG_CONVERTER_DIR = ../../utilities/png_convert/
PNG_CONVERTER = $(PNG_CONVERTER_DIR)ics-png-convert

SIN_TABLE_GEN_DIR = ../../utilities/sin_gen/
SIN_TABLE_GEN = $(SIN_TABLE_GEN_DIR)ics-sin-gen

$(PNG_CONVERTER):
	$(MAKE) -C $(PNG_CONVERTER_DIR)

$(SIN_TABLE_GEN):
	$(MAKE) -C $(SIN_TABLE_GEN_DIR)

tiles.h palette.h: $(PNG) $(PNG_CONVERTER)
	$(PNG_CONVERTER) $(PNG)

sin_table.h: $(SIN_TABLE_GEN)
	$(SIN_TABLE_GEN) sin_table.h
