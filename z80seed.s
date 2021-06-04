	.module	z80seed

	.include	"serial_defs.s"

	.area	_DATA
buffer:
	.blkb	4

	.area	_HEADER (ABS)
	;; Reset vector
	.org 	0x00

	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38

	.org	0x08
puts:
	ld	a, (hl)
	or	a
	ret	z
	ld	c, a
	rst	0x18
	inc	hl
	jr	puts

	.org	0x10
getchar:
	in	a, (ace_lsr)
	rrca
	jr	nc, getchar
	in	a, (ace_rbr)
	ld	c, a

	.org	0x18
putchar:
	in	a, (ace_lsr)
	bit	ace_thre, a
	jr	z, putchar
	ld	a, c
	out	(ace_thr), a
	ret

ldr_str:
	.ascii	/\nLDR /
	.db	0x00

	.org	0x28
readbytes:
	call	getxdigit
	ret	c
	rlca
	rlca
	rlca
	rlca
	push	hl
	ld	h, a
	call	getxdigit
	ld	c, h
	jr	readbytes_2

	.area	_CODE
init:
	;; Set stack pointer directly above top of memory.
	ld	sp, #0x0000

	;; Initialize serial: 9600 Baud, 8N1

	ld	a, #1 << ace_dlab | #1 << ace_wsl1 | #1 << ace_wsl0
	out	(ace_lcr), a
	ld	a, #<ace_divisor
	out	(ace_dll), a
	ld	a, #>ace_divisor
	out	(ace_dlm), a
	ld	a, #1 << ace_wsl1 | #1 << ace_wsl0
	out	(ace_lcr), a
	ld	a, #'\n
	out	(ace_thr), a

prompt:
	ld	hl, #ldr_str
	rst	0x08
	ld	bc, #6 << 8 | <'.
1$:
	in	a, (ace_lsr)
	rrca
	jr	c, writemem
	dec	hl
	ld	a, h
	or	l
	jr	nz, 1$
	rst	0x18
	djnz	1$
	call	0x7c00
	rst	0x38

readbytes_2:
	pop	hl
	ret	c
	add	c
	ld	(de), a
	add	l
	ld	l, a
	inc	de
	djnz	readbytes
	xor	a
	ret

writemem:
	ld	de, #buffer
	xor	a
	ld	l, a
1$:
	rst	0x10
	cp	#'\r
	jr	z, 1$
	cp	#'\n
	jr	z, 1$
	cp	#':
	jr	nz, error
	ld	b, #4
	rst	0x28
	jr	c, error
	ld	a, l
	ld	hl, #buffer
	ld	b,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	h,(hl)
	ld	l, a
	ld	a, h
	srl	a
	ld	c, #'m
	jr	nz, ihx_error
	add	b
	jr	z, 3$
	rst	0x28
	jr	c, error
3$:
	ld	de, #buffer
	inc	b
	rst	0x28
	jr	c, error
	; verify checksum
	ld	a, l
	or	a
	ld	c, #'c
	jr	nz, ihx_error
4$:
	; expect line to end
	rst	0x10
	cp	#'\r
	jr	z, 5$
	cp	#'\n
	jr	z, 5$
	ld	c, #'t
	jr	ihx_error
5$:
	dec	h
	jr	nz, writemem

	ld	c, #'*
	rst	0x18
	ld	c, #'\n
	rst	0x18
	call	0x8000
	rst	0x38

ihx_error:
	rst	0x18

error:
	ld	c, #'\n
	rst	0x18
	ld	c, #'?
	rst	0x18
	rst	0x38

getxdigit:
	rst	0x10
	sub	#0x30
	ret	c
	cp	#0x0a
	ccf
	ret	nc
	res	5, a
	cp	#0x11
	ret	c
	add	#0xe9
	ret	c
	sub	#0xf0
	ret
