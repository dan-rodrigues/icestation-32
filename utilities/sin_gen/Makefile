CXX = g++
CFLAGS = -std=c++17 -Os -I../common
BIN = ics-sin-gen

MAIN = main.cpp
HEADERS = ../common/DataHeader.hpp

$(BIN): $(MAIN) $(HEADERS)
	$(CXX) $(CFLAGS) $(MAIN) -o $@

