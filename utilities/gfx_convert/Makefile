CXX = g++
CFLAGS = -std=c++17 -Os -I../common -I./lodepng -I./intermediate
BIN = gfx_convert

SOURCES = main.cpp lodepng/lodepng.cpp \
	lodepng/lodepng_util.cpp \
	intermediate/Palette.cpp \
	intermediate/Tiles.cpp \
	intermediate/Image.cpp \
	intermediate/Map.cpp \

$(BIN): $(SOURCES)
	$(CXX) $(CFLAGS) $^ -o $@

