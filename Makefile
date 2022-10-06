INCLUDE = -I$(HOME)/A/Asm/Include 
INCLUDE ?= -I $(VBCC)/m68k-amigaos/ndk-include/
VBCC ?= /opt/amiga
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_FLAGS := -Fhunkexe -kick1hunks -quiet -m68030 -m68881 -nosym -showcrit -no-opt $(INCLUDE)

SOURCE   := playsid.asm 
INCLUDES := playsid_libdefs.i 

TARGET   := playsid.library
LISTFILE := playsid.txt

.PHONY: all clean

all: $(TARGET) main

clean:
	rm $(TARGET) $(LISTFILE)

$(TARGET) : $(SOURCE) $(INCLUDES) Makefile ../resid-68k/resid-68k.s
	$(VASM) $< -o $@ -L $(LISTFILE) $(VASM_FLAGS) -I../resid-68k
	cp $@ ../HippoPlayer/

main: main.s
	$(VASM) $< -o $@ $(VASM_FLAGS)
