################################################################################
# argp-standalone-1.4.1/Makefile
#
# Simple Makefile for argp-standalone
#
# Copyright (C) 2025 Richard Elwell
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
################################################################################

# Compiler, archiver, etc., come from environment
CC ?= gcc
AR ?= ar
ARFLAGS ?= rcs

# Compiler flags come from environment
CFLAGS ?= -O2 -fPIC

# Source files
SRC = argp-ba.c argp-eexst.c argp-fmtstream.c argp-help.c argp-parse.c argp-pv.c argp-pvh.c
OBJ = $(SRC:.c=.o)

# Headers
HDR = argp.h argp-fmtstream.h argp-namefrob.h

# Static library
LIB = libargp.a

# Test program
TEST_SRC = argp-test.c
TEST_BIN = argp-test

# Default target: build library and test
all: $(LIB) $(TEST_BIN)

# Compile object files
%.o: %.c $(HDR)
	$(CC) $(CFLAGS) -c $< -o $@

# Create static library
$(LIB): $(OBJ)
	$(AR) $(ARFLAGS) $@ $(OBJ)

# Build test program linked with static library
$(TEST_BIN): $(TEST_SRC) $(LIB)
	$(CC) $(CFLAGS) $< -L. -largp -o $@

# Install into sysroot prefix
install: $(LIB)
	mkdir -p $(PREFIX)/lib $(PREFIX)/include
	cp -pf $(LIB) $(PREFIX)/lib/
	cp -pf $(HDR) $(PREFIX)/include/

# Clean everything
clean:
	rm -f $(OBJ) $(LIB) $(TEST_BIN)

