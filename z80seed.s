	.module	z80seed

	.include	"serial_defs.s"

	.area	_DATA
buffer:
	.blkb	4

	.area	_HEADER (ABS)
	.org 	0x00

	; This is FF and can be overwritten in the ROM.
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38
	rst	0x38

	; Write the null terminated string at HL to the serial interface.
	; modifies: AF, C, HL
	.org	0x08
puts:
	ld	a, (hl)
	or	a
	ret	z
	ld	c, a
	rst	0x18
	inc	hl
	jr	puts

	; Read one character from serial interface and store it to A.
	; modifies: AF, C
	.org	0x10
getchar:
	in	a, (ace_lsr)
	rrca
	jr	nc, getchar
	in	a, (ace_rbr)
	ld	c, a
	; Fall through to putchar for remote echo.

	; Write the character in C to the serial interface.
	; modifies: AF
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

	; Read B hex bytes from the serial interface and store them at DE.
	; Add each byte to L for a checksum.
	; Clear carry flag on success, set carry flag on invalid data.
	; modifies: AF, BC, DE, L
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
	; Continue in code segment due to space limitation.


	; Code location should be 0x0038.
	.area	_CODE
init:
	; Set stack pointer directly above top of memory.
	ld	sp, #0x0000

	; Return to init if the called program returns.
	ld	hl, #0x0038
	push	hl

	; Initialize the serial interface.

	; 9600,8N1 @ 7.3728 MHz
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

	; Wait for input from the serial interface or timeout.
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

	; Continuation of subroutine at reset vector.
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

	; Read Intel HEX from serial and store data to memory.
writemem:
	ld	de, #buffer
	ld	l, #0
1$:
	rst	0x10
	call	check_newline
	jr	z, 1$
	cp	#':
	jr	nz, jump

	; Read byte count, address and record type.
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

	; Verfify mode, accept 00 and 01.
	ld	a, h
	srl	a
	ld	c, #'m
	jr	nz, ihx_error

	; Skip data block if byte count is zero, inherit A as zero.
	add	b
	jr	z, 3$

	; Read data bytes.
	rst	0x28
	jr	c, error
3$:
	; Read one checksum byte, inherit B as zero from previous loop.
	ld	de, #buffer
	inc	b
	rst	0x28
	jr	c, error

	; Verify checksum, expect zero after each line.
	ld	a, l
	or	a
	ld	c, #'c
	jr	nz, ihx_error

	; Expect line to end.
	rst	0x10
	ld	c, #'t
	call	check_newline
	jr	nz, ihx_error

	; Check for end of file record type.
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

	; Read hex address from serial interface and jump to it.
jump:
	cp	#'$
	jr	nz, error
	ld	b, #2
	rst	0x28
	jr	c, error
	rst	0x10
	call	check_newline
	jr	nz, error
	ex	de, hl
	dec	hl
	ld	e, (hl)
	dec	hl
	ld	d, (hl)
	ld	hl, #success_str
	rst	0x08
	ex	de, hl
	jp	(hl)

	; Read one xdigit from serial interface and store its value to A.
	; Clear carry flag on success, set carry flag on invalid input.
	; modifies: AF, C
getxdigit:
	rst	0x10
	sub	#0x30
	ret	c
	cp	#0x0a
	ccf
	ret	nc
	; Convert character to upper case.
	res	5, a
	cp	#0x11
	ret	c
	add	#0xe9
	ret	c
	sub	#0xf0
	ret

check_newline:
	cp	#'\r
	ret	z
	cp	#'\n
	ret

error_str:
	.ascii	"\n?"
	.db	0

success_str:
	.ascii	"*\n"
	.db	0
