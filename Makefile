INCLUDE ?= -I $(VBCC)/m68k-amigaos/ndk-include/
VBCC ?= /opt/amiga
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_FLAGS := -Fhunk -kick1hunks -quiet -m68060 -nosym -showcrit -I $(VBCC)/m68k-amigaos/ndk-include/ -I $(VBCC)/m68k-amigaos/include/

GCC ?= $(VBCC)/bin/m68k-amigaos-gcc
STRIP ?= $(VBCC)/bin/m68k-amigaos-strip

CFLAGS := -O2 -g -noixemul -m68020 -mregparm=4 -fomit-frame-pointer -DPLAYSID

SOURCE   := playsid.asm
INCLUDES := playsid_libdefs.i

TARGET   := playsid.library test_blaster
LISTFILE := playsid.txt

.PHONY: all clean

all: $(TARGET)

clean:
	rm -f $(TARGET) $(LISTFILE) playsid.map test_blaster.map *.o *.sym

playsid.o: playsid.asm playsid_libdefs.i external.asm Makefile
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -Iresid-68k

sidblast.o: sidblast.c Makefile
	$(GCC) -c $< -o $@ $(CFLAGS)

playsid.library.sym: playsid.o sidblast.o | Makefile
	$(GCC) -m68020 -nostdlib -g -Wl,-Map,playsid.map,--cref $^ -o $@

playsid.library: playsid.library.sym
	$(STRIP) $^ -o $@

test_blaster: test_blaster.c sidblast.c
	$(GCC) -O2 -g -noixemul -m68020 --omit-frame-pointer -Wl,-Map,test_blaster.map,--cref $^ -o $@
