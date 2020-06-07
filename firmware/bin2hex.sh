#!/bin/sh
hexdump -v -e '1/4 "%08x" "\n"' "$1"

