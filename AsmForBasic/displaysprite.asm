; d1 = x (mulitple of 4)
; d2 = y
; d3 = sprite adr
; d4 = x sprite size (multiple of 4)
; d5 = y sprite size

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
DisplaySpriteMasked:
				move.l	#$20000,a0
				move.l	d1,d4

			; Screen adr
				lsr.l	#2,d1			; /4, 4 pixels per word.
				add.l	d1,d1			; *2
				lsl.l	#7,d2			; y*128
				add.l	d2,a0			; +y screen
				add.l	d1,a0			; +x screen
						
			; Sprite adr (mask)
				move.l	d3,a1			; Sprite adress
				move.l	d4,d6
				lsr.l	#1,d6
				mulu	d5,d6			; X/2*Y : sprite size, for the mask adress
				move.l	a1,a2
				add.l	d6,a2			; a2 = mask adress

				move.w  #118,d2
                
				sub.l	#1,d5
.LoopY:
				move.l	d4,d7
				lsr.l	#1,d7			; X/2
				sub.l	#1,d7
				move.l	#128,d1			; To add at the end of the line
.LoopX:
				move.l  (a0),d0
				and.l   (a2)+,d0
				or.l    (a1)+,d0
				move.l  d0,(a0)+
				sub.l	#2,d1			; 2 words less to add at the end of the line
				dbra	d7,.LoopX
				
				add.l	d1,a0
				dbra	d5,.LoopY

                movem.l (sp)+,d1-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
				rts
				
				