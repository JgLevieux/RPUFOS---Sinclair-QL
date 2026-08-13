
	even
RandomSeed:		dc.l	$12345678
	even

GetRandom:
			movem.l d1/a0,-(sp)

			lea		RandomSeed(pc),a0
			move.l	(a0),d0
			beq.s	.fix_zero

			move.l	d0,d1
			lsl.l	#8,d1              ; Shift left 13 bits
			lsl.l	#5,d1              ; Shift left 13 bits
			eor.l	d1,d0
			move.l	d0,d1
			lsr.l	#8,d1             ; Shift right 17 bits
			lsr.l	#8,d1             ; Shift right 17 bits
			lsr.l	#1,d1             ; Shift right 17 bits
			eor.l	d1,d0
			move.l	d0,d1
			lsl.l	#5,d1              ; Shift left 5 bits
			eor.l	d1,d0
			
			move.l	d0,(a0)             ; Save new seed
			movem.l (sp)+,d1/a0
			rts

.fix_zero:
			move.l	#$deadbeef,d0       ; Fallback if seed hits zero
			move.l	d0,(a0)
			movem.l (sp)+,d1/a0
			rts
