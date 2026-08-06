; d1 = x
; d2 = y
; d3 = sprite

;210 MODE 8
;220 SCALE 256, 0, 0

;300 sprite=RESPR(1280)
;310 LBYTES mdv1_ghostred_bin,sprite

;350 displaysprite16x16=RESPR(512)
;370 LBYTES win1_displaysprite16x16_bin,displaysprite16x16
;380 CALL displaysprite16x16, 60, 64, sprite
;381 CALL displaysprite16x16, 61, 64+16*1, sprite
;382 CALL displaysprite16x16, 62, 64+16*2, sprite
;383 CALL displaysprite16x16, 63, 64+16*3, sprite

                movem.l d1-d7/a0-a1,-(sp)
DisplaySprite16x16MaskedShifted:
				move.l	#$20000,a0
				move.l	d3,a1			; Sprite
				move.l	d1,d4
				lsr.l	#2,d1			; /4, 4 pixels per word.
				add.l	d1,d1			; *2
				lsl.l	#7,d2			; y*128
				add.l	d2,a0			; +y screen
				add.l	d1,a0			; +x screen
						
				and.l	#3,d4			; keep 2 bits for shifting (0-3)
				move.l	d4,d2
				lsl.l	#6,d4			; *64
				lsl.l	#8,d2			; *256
				add.l	d4,d2			; = *320

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		160(a2),a2		; a2 = mask

				move.w  #118,d2
                
			rept 16  ; lines
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+
					
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+

					move.w  (a0),d0
					and.w   (a2)+,d0
					or.w    (a1)+,d0
					move.w  d0,(a0)+
					
					adda.w  d2,a0
			endr

                movem.l (sp)+,d1-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
				rts
				
				