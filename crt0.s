;--------------------------------------------------------------------------
;  crt0.s - Generic crt0.s for a Z80
;
;  Copyright (C) 2000, Michael Hope
;
;  This library is free software; you can redistribute it and/or modify it
;  under the terms of the GNU General Public License as published by the
;  Free Software Foundation; either version 2, or (at your option) any
;  later version.
;
;  This library is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License 
;  along with this library; see the file COPYING. If not, write to the
;  Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
;   MA 02110-1301, USA.
;
;  As a special exception, if you link this library with other files,
;  some of which are compiled with SDCC, to produce an executable,
;  this library does not by itself cause the resulting executable to
;  be covered by the GNU General Public License. This exception does
;  not however invalidate any other reasons why the executable file
;   might be covered by the GNU General Public License.
;--------------------------------------------------------------------------

	.module crt0
	.globl	_main

	.include	"serial_defs.s"

	.area	_HEADER (ABS)
	;; Reset vector
	.org 	0x00

	rst	0x38
	rst	0x38
	rst	0x38

	.org	0x08
puts::
	ld	a, (hl)
	or	a
	ret	z
	ld	c, a
	rst	0x20
	inc	hl
	jr	puts

	.org	0x10
getchar:
	in	a, (ace_lsr)
	rrca
	jr	nc, getchar
	in	a, (ace_rbr)
	ld	c, a
	jr	putchar

	.org	0x20
putchar:
	in	a, (ace_lsr)
	bit	ace_thre, a
	jr	z, putchar
	jr	putchar_2
	.org	0x04
putchar_2:
	ld	a, c
	out	(ace_thr), a
	ret

	.area	__init (ABS)
	.org 	0x38
init:
	;; Set stack pointer directly above top of memory.
	ld	sp, #0x0000
	jp	_main

	;; Ordering of segments for the linker.
	.area	_HOME
	.area	_CODE
	.area	_INITIALIZER
	.area   _GSINIT
	.area   _GSFINAL

	.area	_DATA
	.area	_INITIALIZED
	.area	_BSEG
	.area   _BSS
	.area   _HEAP
