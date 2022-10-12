INCLUDE = -I$(HOME)/A/Asm/Include 
INCLUDE ?= -I $(VBCC)/m68k-amigaos/ndk-include/
VBCC ?= /opt/amiga
VASM ?= $(VBCC)/bin/vasmm68k_mot
VASM_FLAGS := -Fhunkexe -kick1hunks -quiet -m68030 -nosym -no-opt $(INCLUDE)

SOURCE   = playsid.asm 
INCLUDES := playsid_libdefs.i 

TARGET   := playsid.library
TARGET14 := playsid.library-14bit

.PHONY: all clean

all: $(TARGET) $(TARGET14)

clean:
	rm $(TARGET) $(TARGET14)

$(TARGET) : $(SOURCE) $(INCLUDES) Makefile
	$(VASM) $< -o $@ $(VASM_FLAGS) -Iresid-68k

$(TARGET14) : $(SOURCE) $(INCLUDES) Makefile 
	$(VASM) $< -o $@ $(VASM_FLAGS) -Iresid-68k -DENABLE_14BIT=1
