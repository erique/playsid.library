VBCC ?= /opt/amiga
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_FLAGS := -Fhunkexe -kick1hunks -quiet -m68000 -nosym -showcrit -no-opt -I $(VBCC)/m68k-amigaos/ndk-include/

SOURCE   := playsid.asm
INCLUDES := playsid_libdefs.i external.asm

TARGET   := playsid.library
LISTFILE := playsid.txt

.PHONY: all clean

all: $(TARGET)

clean:
	rm -f $(TARGET) $(LISTFILE)

$(TARGET) : $(SOURCE) $(INCLUDES) Makefile
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS)
