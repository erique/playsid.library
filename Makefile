INCLUDE ?= -I $(VBCC)/m68k-amigaos/ndk-include/
VBCC ?= /opt/amiga
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_FLAGS := -Fhunk -kick1hunks -quiet -m68060 -nosym -showcrit -I $(VBCC)/m68k-amigaos/ndk-include/ -I $(VBCC)/m68k-amigaos/include/

GCC ?= $(VBCC)/bin/m68k-amigaos-gcc
STRIP ?= $(VBCC)/bin/m68k-amigaos-strip
OBJCOPY ?= $(VBCC)/bin/m68k-amigaos-objcopy

CFLAGS := -O2 -g -noixemul -m68020 -mregparm=4 -fomit-frame-pointer -DPLAYSID

SOURCE   := playsid.asm
INCLUDES := playsid_libdefs.i external.asm resid-68k/resid-68k.s resid-68k/resid-68k.i

TARGET   := playsid.library test_blaster
# test_blaster
LISTFILE := playsid.txt

##
## Generate a C header / ASM include file with the current git hash
##

SHELL=bash	# this relies on bash.. 
GIT_HEADER?=git.gen.h
GIT_INCLUDE?=git.gen.i
GIT :=$(shell git describe --always)# can't use '--dirty' because playsid.library 
GIT_DEFINE:='\#define GIT "$(GIT)"'
OLD_DEFINE:='$(shell [[ -e $(GIT_HEADER) ]] && cat $(GIT_HEADER) || echo "nothing")'
GIT_MACRO :='$(shell echo -e 'GIT\tMACRO\r\tdc.b "$(GIT)"\r\tENDM')'
OLD_MACRO :='$(shell [[ -e $(GIT_INCLUDE) ]] && cat $(GIT_INCLUDE) || echo "nothing")'
$(info GIT = $(GIT))
$(shell [[ $(OLD_DEFINE) != $(GIT_DEFINE) ]] && echo -e $(GIT_DEFINE) > $(GIT_HEADER))
$(shell [[ $(OLD_MACRO) != $(GIT_MACRO) ]] && echo -e $(GIT_MACRO) > $(GIT_INCLUDE))

.PHONY: all clean

all: $(TARGET)

clean:
	rm -f $(TARGET) $(LISTFILE) playsid.map test_blaster.map *.o *.sym $(GIT_HEADER) $(GIT_INCLUDE)

playsid.o: playsid.asm $(INCLUDES) $(GIT_INCLUDE) Makefile
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -Iresid-68k
	$(OBJCOPY) --rename-section reSID_data=.data $@

sid.o: sid.c $(GIT_HEADER) Makefile
	$(GCC) -c $< -o $@ $(CFLAGS) -Wall -Os

sidblast.o: sidblast.c $(GIT_HEADER) Makefile
	$(GCC) -c $< -o $@ $(CFLAGS)

usbsid.o: usbsid.c $(GIT_HEADER) Makefile
	$(GCC) -c $< -o $@ $(CFLAGS) -Wall -Wno-pointer-sign

playsid.library.sym: playsid.o sid.o sidblast.o usbsid.o
	$(GCC) -m68020 -nostdlib -g -Wl,-Map,playsid.map,--cref $^ -o $@

playsid.library: playsid.library.sym
	$(STRIP) $^ -o $@

test_blaster: test_blaster.c sid.c sidblast.c usbsid.c $(GIT_HEADER)
	$(GCC) -O2 -noixemul -m68020 --omit-frame-pointer -Wl,-Map,test_blaster.map,--cref $^ -o $@
