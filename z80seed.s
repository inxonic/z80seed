	.module	main

	.include	"serial_defs.s"

	.area	_ldr_str (ABS)
	.org	0x1a
ldr_str:
	.ascii	/\nLDR /
	.db	0x00

	.area	_readbytes (ABS)
	.org	0x28
readbytes:
	push	bc
	call	getxbyte
	pop	bc
	ret	nc
	ld	(de), a
	add	l
	ld	l, a
	inc	de
	djnz	readbytes
	scf
	ret

	.area	_DATA
buffer:
	.blkb	4

	.area	_CODE
_main::
	; Initialize serial: 9600 Baud, 8N1

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
	rst	0x20
	djnz	1$
	call	0x7c00
	rst	0x38

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
	jr	nc, error
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
	jr	z, 2$
	ld	c, #'m
	rst	0x20
	jr	error
2$:
	xor	a
	add	b
	jr	z, 3$
	rst	0x28
	jr	nc, error
3$:
	ld	de, #buffer
	ld	b, #1
	rst	0x28
	jr	nc, error
	; verify checksum
	ld	a, l
	or	a
	jr	z, 4$
	ld	c, #'c
	rst	0x20
	jr	error
4$:
	; expect line to end
	rst	0x10
	cp	#'\r
	jr	z, 5$
	cp	#'\n
	jr	z, 5$
	ld	c, #'t
	rst	0x20
	jr	error
5$:
	dec	h
	jr	nz, writemem

	ld	c, #'*
	rst	0x20
	ld	c, #'\n
	rst	0x20
	call	0x8000
	rst	0x38

error:
	ld	c, #'\n
	rst	0x20
	ld	c, #'?
	rst	0x20
	jr	prompt

	; read one hex byte from the serial interface and store it to A
	; carry flag is set on success, else return output of getxdigit
	; modifies: A, F, B, C
getxbyte:
	call	getxdigit
	cp	#0x10
	ret	nc
	rlca
	rlca
	rlca
	rlca
	ld	b, a
	call	getxdigit
	cp	#0x10
	ret	nc
	add	b
	scf
	ret

	; read one xdigit from the serial interface and store it
	; to the lower nibble in A upper nibble is 0 on success
	; return 0x10 on invalid input and 0xff on EOT (ASCII 0x04)
	; modifies: A, F, C
getxdigit:
	rst	0x10
	sub	#0x30
	jr	c, getxdigit_err
	cp	#0x0a
	ret	c
	res	5, a
	cp	#0x11
	jr	c, getxdigit_err
	sub	#7
	cp	#0x10
	ret	c
getxdigit_err:
	ld	a, #0x10
	ret
