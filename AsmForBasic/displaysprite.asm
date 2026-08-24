; d1 = x (mulitple of 4)
; d2 = y
; d3 = sprite adr
; d4 = x sprite size (multiple of 4)
; d5 = y sprite size

;210 MODE 8
;220 SCALE 256, 0, 0
;230 PAPER #1, 5
;240 CLS #1

;300 sprite16x16=RESPR(256)
;301 LBYTES mdv1_16x16_bin,sprite16x16

;302 sprite24x24=RESPR(576)
;303 LBYTES mdv1_24x24_bin,sprite24x24

;304 sprite32x32=RESPR(1024)
;305 LBYTES mdv1_32x32_bin,sprite32x32

;306 sprite48x48=RESPR(2304)
;307 LBYTES mdv1_48x48_bin,sprite48x48

;308 sprite64x64=RESPR(4096)
;309 LBYTES mdv1_64x64_bin,sprite64x64

;350 displaysprite=RESPR(512)
;360 REM LBYTES mdv1_displaysprite_bin,displaysprite
;370 LBYTES mdv1_displaysprite_bin,displaysprite
;400 CALL displaysprite, 64, 64, sprite16x16, 16, 16
;410 CALL displaysprite, 64, 64+16, sprite24x24, 24, 24
;420 CALL displaysprite, 64, 64+16+24, sprite32x32, 32, 32
;430 CALL displaysprite, 64, 64+16+24+32, sprite48x48, 48, 48
;440 CALL displaysprite, 64, 64+16+24+32+48, sprite64x64, 64, 64


                movem.l d1-d7/a0-a2,-(sp)
DisplaySpriteMasked:
				move.l	#$20000,a0

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

				sub.l	#1,d5
.LoopY:
				move.l	d4,d7
				lsr.l	#2,d7			; X/4 : 4 pixels at a time for each loop (with words)
				sub.l	#1,d7
				move.l	#128,d1			; To add at the end of the line
.LoopX:
				move.w  (a0),d0
				and.w   (a2)+,d0
				or.w    (a1)+,d0
				move.w  d0,(a0)+
				sub.l	#2,d1			; 2 words less to add at the end of the line
				dbra	d7,.LoopX
				
				add.l	d1,a0
				dbra	d5,.LoopY

                movem.l (sp)+,d1-d7/a0-a2

				moveq	#0,d0   			; Return no error to Basic
				rts
				
				