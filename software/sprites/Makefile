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

PNG = crystal-32-ia.png
PNG_CONVERTER_DIR = ../../utilities/png_convert/
PNG_CONVERTER = $(PNG_CONVERTER_DIR)ics-png-convert

$(PNG_CONVERTER):
	$(MAKE) -C $(PNG_CONVERTER_DIR)

tiles.h palette.h: $(PNG) $(PNG_CONVERTER)
	$(PNG_CONVERTER) $(PNG)

