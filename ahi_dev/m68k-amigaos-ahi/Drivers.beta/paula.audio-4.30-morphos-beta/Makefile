CFLAGS = -Wall -O2 -mcpu=603e -mmultiple -fomit-frame-pointer -DUSE_INLINE_STDARG -D__MORPHOS__ -D__MORPHOS_DIRECTCALL -I/gg/morphos/aboxinclude/os-include -I/gg/morphos/aboxinclude/include -I/gg/morphos/include
CC = ppc-morphos-gcc
LD = ppc-morphos-ld
STRIP = ppc-morphos-strip
RM = rm -f

SRCS = paula_audio.c
OBJS = $(SRCS:.c=.o)

.PHONY: all install clean

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

all: paula.audio.elf

paula_audio.o: paula_audio.c paula_audio.h

paula.audio.elf: $(OBJS)
	$(LD) $< -lsyscall -lmemblock -lstring -o $@.db
	$(STRIP) --strip-unneeded --remove-section .comment $@.db -o $@

install: paula.audio.elf
	mkdir -p /sys/devs/ahi
	cp paula.audio.elf /sys/devs/ahi/

clean:
	-$(RM) $(OBJS) paula.audio.elf

