# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


TARGETS=	z80seed.ihx

CODELOC ?=	0x0038
DATALOC ?=	0xfe00

AS=		sdcc-sdasz80
CC=		sdcc-sdcc

CFLAGS=		-mz80
LDFLAGS=	-mz80 --code-loc $(CODELOC) --data-loc $(DATALOC) --no-std-crt0
LDLIBS=		


all:		$(TARGETS)


%.ihx : %.rel
		$(CC) $(LDFLAGS) $(LDLIBS) $^ --out-fmt-ihx -o $@

%.s19 : %.rel
		$(CC) $(LDFLAGS) $(LDLIBS) $^ --out-fmt-s19 -o $@

%.rel : %.s
		$(AS) $(ASFLAGS) -losp $@ $<

%.rel : %.c
		$(CC) $(CFLAGS) -c $<


clean:
		$(RM) $(TARGETS) *.rel *.asm *.lst *.map *.noi *.sym *.lk
