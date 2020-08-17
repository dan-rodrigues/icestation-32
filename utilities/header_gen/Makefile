CXX = g++
CFLAGS = -std=c++17 -Os -I../common
BIN = header_gen

SOURCES = main.cpp
HEADERS = ../common/DataHeader.hpp

$(BIN): $(SOURCES) $(HEADERS)
	$(CXX) $(CFLAGS) main.cpp -o $@

