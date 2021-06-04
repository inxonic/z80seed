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
	.ascii	"\nLDR "
	.db	0x00

	.org	0x28
readbytes:
	call	getxdigit
	ret	c
	rlca
	rlca
	rlca
	rlca
	ld	c, a
	push	bc
	call	getxdigit
	pop	bc
	jr	readbytes_2

	.area	_CODE
init:
	;; Set stack pointer directly above top of memory.
	ld	sp, #0x0000
	ld	hl, #0x0038
	push	hl

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
	jp	0x7c00

readbytes_2:
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
	ld	l, #0
1$:
	rst	0x10
	call	check_newline
	jr	z, 1$
	cp	#':
	jr	nz, jump
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

	; expect line to end
	rst	0x10
	ld	c, #'t
	call	check_newline
	jr	nz, ihx_error
	dec	h
	jr	nz, writemem

	ld	hl, #success_str
	rst	0x08
	rst	0x38

ihx_error:
	rst	0x18

error:
	ld	hl, #error_str
	rst	0x08
	jp	prompt

jump:
	cp	#'$
	jr	nz, error
	ld	b, #2
	rst	0x28
	jr	c, error
	rst	0x10
	call	check_newline
	jr	nz, error
	rst	0x18
	ex	de, hl
	dec	hl
	ld	e, (hl)
	dec	hl
	ld	d, (hl)
	ld	hl, #success_str
	rst	0x08
	ex	de, hl
	jp	(hl)

check_newline:
	cp	#'\r
	ret	z
	cp	#'\n
	ret

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

error_str:
	.ascii	"\n?"
	.db	0

success_str:
	.ascii	"*\n"
	.db	0
