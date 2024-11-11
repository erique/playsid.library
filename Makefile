INCLUDE ?= -I $(VBCC)/m68k-amigaos/ndk-include/
VBCC ?= /opt/amiga
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_FLAGS := -Fhunk -kick1hunks -quiet -m68060 -nosym -showcrit -I $(VBCC)/m68k-amigaos/ndk-include/ -I ahi

GCC ?= $(VBCC)/bin/m68k-amigaos-gcc
STRIP ?= $(VBCC)/bin/m68k-amigaos-strip
CFLAGS := -O2 -g -noixemul -m68060 --omit-frame-pointer -DPLAYSID

SOURCE   = playsid.asm 
INCLUDES := playsid_libdefs.i 

TARGET   := playsid.library test_blaster
LISTFILE := playsid.txt

.PHONY: all clean

all: $(TARGET)

clean:
	rm -f $(TARGET) $(LISTFILE) playsid.map test_blaster.map *.o

playsid.o: playsid.asm playsid_libdefs.i external.asm Makefile
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -Iresid-68k

serial_sidblast.o: serial_sidblast.s Makefile
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS)

sidblast.o: sidblast.c | Makefile
	$(GCC) -c $< -o $@ -L $(CFLAGS)

playsid.library: playsid.o serial_sidblast.o | Makefile
	$(GCC) -m68060 -nostdlib -g -Wl,-Map,playsid.map,--cref $^ -o $@
	$(STRIP) $@

test_blaster: test_blaster.c serial_sidblast.o
	$(GCC) -O2 -g -noixemul -m68060 --omit-frame-pointer -Wl,-Map,test_blaster.map,--cref $^ -o $@
