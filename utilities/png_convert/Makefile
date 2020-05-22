CXX = g++
CFLAGS = -std=c++17 -Os -I../common -I./lodepng -I./intermediate
BIN = ics-png-convert

SOURCES = main.cpp lodepng/lodepng.cpp lodepng/lodepng_util.cpp intermediate/Palette.cpp intermediate/Tiles.cpp

$(BIN): $(SOURCES)
	$(CXX) $(CFLAGS) $^ -o $@

