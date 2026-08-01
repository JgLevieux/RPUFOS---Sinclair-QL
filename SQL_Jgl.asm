	even
	include "macros.asm"
	even
; =============================================================================
BARE_METAL			equ		1

;TIMER_MODE			equ		1

	ifd BARE_METAL
DOUBLE_BUFFERING	equ		1
	else
;CLEAR_SCREEN_FRAME	equ		1
	endif
;CLEAR_SCREEN_FRAME	equ		1

	ifd TIMER_MODE
;CLEAR_SCREEN_COLOR	equ		$AAFFAAFF
CLEAR_SCREEN_COLOR	equ		$00550055
	else
CLEAR_SCREEN_COLOR	equ		0
	endif

;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000

; =============================================================================

Start:
			; Remove QDOS, mainly for double buffering as second screen adress contain QDOS data (and  code ?)
			ifd BARE_METAL
                trap    #0              ; Call QDOS for Superviseur mode
                ori.w   #$0700,sr       ; All hardware interrupt off.
				
			; Set my own stack
				lea		TopOfStack(pc),a0
				move.l	a0,sp
			endif

				DBGENABLE
				;DBGBREAK

				lea     NbLoop(pc),a0
                move.l  #0,(a0)

			; Setup double buffering & first clear
				move.b	#ScreenMode01,$18063
			ifd DOUBLE_BUFFERING				
				move.l	#$28000,a0
				bsr     ClearScreen
			endif
			
				move.l	#$20000,a0
				bsr     ClearScreen

				lea		ScreenBase(pc),a0
				move.l	#$20000,(a0)

MainLoop:
			; WaitVBlank
				bsr		WaitVBlank
				
			ifd TIMER_MODE
				move.b	#ScreenMode01,$18063			; Display screen 1
			endif

				bsr		SwapBuffer

				bsr 	ReadKeyboard

				btst	#Keyboard01_ESC,1(a1)
				beq.s	.NoESC
				DBGBREAK
.NoESC:

				lea     NbLoop(pc),a0
				add.l	#1,(a0)
				move.l	(a0),d6

				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Enter,d4		; Press space to move while tracing
				beq.s	.nobreakpoint
				DBGBREAK
				
				bsr			SoundTest
				
.nobreakpoint:
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				bsr     ClearScreen

				bsr		ScrollTest

				bsr		DrawVblTimer

			ifd TIMER_MODE
				DisplayOffForProfiling
			endif
				bra		MainLoop

                rts

				
ScrollTest:
				lea		ScreenBase(pc),a6
				move.l	(a6),a6
				add.l	#128/2-128/2/2,a6

				lea     NbLoop(pc),a1
				move.l	(a1),d0
				and.l	#255,d0
				lsl.l	#1,d0

				lea		SinTable256(pc),a5
				moveq	#0,d7

				lea		Demo01(pc),a0
				;DBGBREAK
				
			rept 128
				add.w	#2,d0
				and.w	#255,d0
				moveq	#0,d7
				move.w	(a5,d0.w),d7
				ext.l	d7
				asr.l	#3,d7			; -32 to 32
				move.l	d7,d6
				and.l	#$FFFFFFFE,d7
				move.l	a6,a4
				add.l	d7,a6

				and.l	#3,d6
				asl.l	#7,d6
				asl.l	#6,d6
				add.l	d6,a0
				
			
				movem.l	(a0),d1-d3/a1-a2
				movem.l	d1-d3/a1-a2,(a6)

				movem.l	5*4(a0),d1-d3/a1-a2
				movem.l	d1-d3/a1-a2,5*4(a6)

				movem.l	5*4*2(a0),d1-d3/a1-a3
				movem.l	d1-d3/a1-a2,5*4*2(a6)
				
				sub.l	d6,a0
				move.l	a4,a6
				lea		128(a6),a6
				lea		64(a0),a0
			endr
    
    			;movem.l d0-d7/a1-a6,-(sp)


				rts

;=============================================================================
	even
	include "controls.asm"
	even
	include "sound.asm"
	even
	include "random.asm"
	even
	include "unzx0_68000.asm"
	even
	include "PlotPixel.asm"
	even
	include "sinus.asm"
;=============================================================================
	even

;=============================================================================
; Swap buffer for double buffering
;=============================================================================
SwapBuffer:
			; Double buffering
			ifd DOUBLE_BUFFERING				
				lea		ScreenBase(pc),a0
				lea		BufferNum(pc),a1
				move.l	(a0),d0
				cmp.l	#$20000,d0
				beq.s	.swapscreen1
				
				move.l	#$20000,(a0)					; Draw in screen 1
				move.b	#ScreenMode02,$18063			; Display screen 2
				lea		ScreenBaseFront(pc),a0
				move.l	#$28000,(a0)
				move.w	#0,(a1)
				
				bra.s	.swapscreen2
.swapscreen1:
				move.l	#$28000,(a0)					; Draw in screen 2
				move.b	#ScreenMode01,$18063			; Display screen 1
				lea		ScreenBaseFront(pc),a0
				move.l	#$20000,(a0)
				move.w	#1,(a1)
.swapscreen2:
			endif
				rts
				
;=============================================================================
; DisplayText - !! no shifting, no mask, no clipping !!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = text address
; Output : -
; Destroy :
;		d0, d1, d2, d5, d6
;		a0, a1
;=============================================================================
DisplayText:
				move.l	a0,a6				; save text adr
				move.l	d0,d5				; save coords
				move.l	d1,d6
.loop:
				moveq	#0,d2
				move.b	(a6)+,d2			; get char
				beq.s	.endoftext
				cmp.b	#32,d2
				beq.s	.next				; space

				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				lea		Font(pc),a1
				sub.b	#33,d2				; sub first char (start with "!")
				lsl.l	#5,d2				; *32 : 4 bytes (2 words for 8 pixels) * 8 lines
				add.l	d2,a1
				move.l	d5,d0
				move.l	d6,d1
				move.l	a1,a2
				bsr		DisplaySprite8x8

				lea		ScreenBaseFront(pc),a0
				move.l	(a0),a0
				move.l	a2,a1
				move.l	d5,d0
				move.l	d6,d1
				bsr		DisplaySprite8x8
				
.next:
				add.l	#8,d5				; next char 8 pixels to the right
				
				bra.s	.loop

.endoftext:
				rts

;=============================================================================
; Number to Ascii (00-99)
; Input : -
;		d0.w = number
;		a0 = text address to fill
; Destroy :
;		d0, d1, d2, d5, d6
;		a0, a1
;=============================================================================
NumberToAscii_00:
				moveq	#0,d1
.ten:
				add.w	#1,d1
				sub.w	#10,d0
				bge.s	.ten

				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,0(a0)
				add.w	#10,d0

				add.b	#"0",d0
				move.b	d0,1(a0)
				rts

;=============================================================================
; Number to Ascii (000000-999999)
; Input : -
;		d0.l = number
;		a0 = text address to fill
; Destroy :
;		d0, d1, d2, d5, d6
;		a0, a1
;=============================================================================
NumberToAscii_000000:
				moveq	#0,d1
.l000000:
				add.w	#1,d1
				sub.l	#1000000,d0
				bge.s	.l000000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,0(a0)
				add.l	#1000000,d0

				moveq	#0,d1
.l00000:
				add.w	#1,d1
				sub.l	#100000,d0
				bge.s	.l00000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,1(a0)
				add.l	#100000,d0

				moveq	#0,d1
.l0000:
				add.w	#1,d1
				sub.l	#10000,d0
				bge.s	.l0000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,2(a0)
				add.l	#10000,d0

				moveq	#0,d1
.l000:
				add.w	#1,d1
				sub.l	#1000,d0
				bge.s	.l000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,3(a0)
				add.l	#1000,d0

				moveq	#0,d1
.l00:
				add.w	#1,d1
				sub.l	#100,d0
				bge.s	.l00
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,4(a0)
				add.l	#100,d0

				moveq	#0,d1
.l0:
				add.w	#1,d1
				sub.l	#10,d0
				bge.s	.l0
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,5(a0)
				add.l	#10,d0

				add.b	#"0",d0
				move.b	d0,6(a0)
				rts

;=============================================================================
; Display a sprite, 16x16 with mask & shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1, d2, d3
;		a0, a1, a2
;
; TODO : 
;	- optimiser avec du .b/.w (255 max pour les coord)
;=============================================================================
DisplaySprite16x16MaskedShifted:
				;DBGBREAK
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				and.l	#3,d3			; keep 2 bits for shifting (0-3)
				move.l	d3,d2		
				move.l	d3,d1
				lsl.l	#2,d3			; *4
				lsl.l	#8,d3			; *256
				add.l	d1,d1			; *2
				lsl.l	#8,d1			; *256
				lsl.l	#6,d2			; *64
				add.l	d3,d2			;
				add.l	d1,d2			; *1600

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		160*5(a2),a2		; a2 = mask

				move.w  #118,d1
                
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
					
					adda.w  d1,a0
			endr
				
	if 0
		rept 16	; lines
			rept 5 ; words
				move.w	(a0),d0			; Get the pixels on the screen
				and.w	(a2)+,d0		; Apply sprite mask
				or.w	(a1)+,d0		; Apply sprite color
				move.w	d0,(a0)+		; Write final pixel
			endr
		
				lea		118(a0),a0
		endr
	endif
				rts

	
;=============================================================================
; Display a sprite, 8x8 with mask & shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1, d2, d3
;		a0, a1, a2
;
; TODO : 
;	- optimiser avec du .b/.w (255 max pour les coord)
;=============================================================================
DisplaySprite8x8MaskedShifted:
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				and.l	#3,d3			; keep 2 bits for shifting (0-3)
				move.l	d3,d2		
				lsl.l	#6,d3			; *64
				lsl.l	#5,d2			; *32
				add.l	d3,d2			; *96

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		48(a2),a2		; a2 = mask
			
				move.w  #122,d1
                
			rept 8  ; lines
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+
					
					move.w  (a0),d0
					and.w   (a2)+,d0
					or.w    (a1)+,d0
					move.w  d0,(a0)+
					
					adda.w  d1,a0
			endr
				rts
				
;=============================================================================
; Clean a sprite, 8x8 with shifting, !!! no clipping !!!
; Get "originals" pixels into the Qlix background
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = screen to copy
; Output : -
; Destroy :
;		d0, d1
;		a0, a1
;
; TODO : 
;	- optimiser avec du .b/.w (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
CleanSprite8x8Shifted:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d0,d1			; +y screen +x screen
				add.l	d1,a0			; dest adr
				add.l	d1,a1			; source adr
						
		rept 8	; lines
				move.l	(a1)+,(a0)+
				move.w	(a1)+,(a0)+

				lea		122(a0),a0
				lea		122(a1),a1
		endr
				rts

;=============================================================================
; Save background for a sprite, 8x8 with shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = backup buffer
; Output : -
; Destroy :
;		d0, d1
;		a0, a1
;=============================================================================
SaveSprite8x8Shifted:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d0,d1			; +y screen +x screen
				add.l	d1,a0			; dest adr
						
		rept 7	; lines
				move.l	(a0)+,(a1)+
				move.w	(a0)+,(a1)+
				lea		122(a0),a0
		endr
				move.l	(a0)+,(a1)+
				move.w	(a0)+,(a1)+
				rts
				
;=============================================================================
; Draw on the background from saved buffer, 8x8 with shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = backup buffer
; Output : -
; Destroy :
;		d0, d1
;		a0, a1
;=============================================================================
BackSprite8x8Shifted:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d0,d1			; +y screen +x screen
				add.l	d1,a0			; dest adr
						
		rept 7	; lines
				move.l	(a1)+,(a0)+
				move.w	(a1)+,(a0)+
				lea		122(a0),a0
		endr
				move.l	(a1)+,(a0)+
				move.w	(a1)+,(a0)+
				rts


;=============================================================================
; Save background, 32x32 (align to a word)
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = backup buffer
; Output : -
; Destroy :
;		d0, d1
;		a0, a1
;=============================================================================
Save32x32:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d0,d1			; +y screen +x screen
				add.l	d1,a0			; dest adr
						
		rept 31	; lines
				move.l	(a0)+,(a1)+
				move.l	(a0)+,(a1)+
				move.l	(a0)+,(a1)+
				move.l	(a0)+,(a1)+
				lea		128-4*4(a0),a0
		endr
				move.l	(a0)+,(a1)+
				move.l	(a0)+,(a1)+
				move.l	(a0)+,(a1)+
				move.l	(a0)+,(a1)+
				rts

;=============================================================================
; Save background, 32x32 (align to a word)
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = backup buffer
; Output : -
; Destroy :
;		d0, d1
;		a0, a1
;=============================================================================
Back32x32:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d0,d1			; +y screen +x screen
				add.l	d1,a0			; dest adr
						
		rept 31	; lines
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				lea		128-4*4(a0),a0
		endr
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				rts
				
;=============================================================================
; Display a sprite, 8x8 no mask, no shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
DisplaySprite8x8:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen

				move.l  (a1)+,(a0)
				move.l  (a1)+,128(a0)
				move.l  (a1)+,256(a0)
				move.l  (a1)+,384(a0)
				move.l  (a1)+,512(a0)
				move.l  (a1)+,640(a0)
				move.l  (a1)+,768(a0)
				move.l  (a1)+,896(a0)

				rts

DisplaySprite16x16:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen

				move.w	#120,d0
		rept 16	; lines
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				
				add.w	d0,a0
		endr
				rts

; =============================================================================
; Clear 8x8 (3 words for shifting), !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
; Output : -
; Destroy :
;		d0, d1
;		a0
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fi de rept
; =============================================================================
ClearSprite8x8MaskedShifted:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
		rept 8	; lines
				clr.l	(a0)+
				clr.w	(a0)+
				lea		122(a0),a0
		endr
				rts

; =============================================================================
; Clear 8x8  !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
; Output : -
; Destroy :
;		d0, d1
;		a0
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fi de rept
; =============================================================================
ClearSprite8x8:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				moveq   #0,d0
                move.l  d0,(a0)
                move.l  d0,128(a0)
                move.l  d0,256(a0)
                move.l  d0,384(a0)
                move.l  d0,512(a0)
                move.l  d0,640(a0)
                move.l  d0,768(a0)
                move.l  d0,896(a0)

				rts

ClearSprite16x16:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				moveq   #0,d0
                move.w  #120,d1
		rept 16
				move.l  d0,(a0)+
				move.l  d0,(a0)+
				adda.w  d1,a0
		endr

				rts

; =============================================================================
; Wait Vertical Blank
; Input : -
; Output : -
; Destroy : d0
; =============================================================================
WaitVBlank:
				moveq	#0,d1
				moveq	#1,d2
				move.b	#1<<3,$18021   ; ack frame interrupt
.wait:
				add.l	d2,d1
				btst    #3,$18021		; ...and wait for the next VBL
				beq.s   .wait                   ; (bit 3 only: bits 7..5 always move)

				lea		VBlankTimer(pc),a0
				move.l	d1,(a0)
				rts

DrawVblTimer:
				lea		VBlankTimer(pc),a0
				move.l	(a0),d0				; max 1260 mesured with debugger
				lsr.l	#5,d0

				cmp.l	#1,d0
				bge.s	.check_sup
				move.l	#1,d0
				bra.s	.finborne

.check_sup:
				cmp.l	#40,d0
				ble.s	.finborne
				move.l	#40,d0
.finborne:

				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				add.l	#128*255,a0

				move.l	#41,d1
				sub.l	d0,d1
				sub.l	#1,d1
				sub.l	#1,d0
.DrawLoop:
				move.w	#$AAFF,(a0)+
				dbra	d1,.DrawLoop

.CleanLoop:
				clr.w	(a0)+
				dbra	d0,.CleanLoop

				move.w	#$0055,(a0)+ ; Last pixel to see the end
				move.w	#$0055,(a0)+ ; Last pixel to see the end
				move.w	#$0055,(a0)+ ; Last pixel to see the end
				move.w	#$0055,(a0)+ ; Last pixel to see the end
				rts


; =============================================================================
; Clear screen
; a0 - Screen adr
; =============================================================================
ClearScreen:
                moveq   #0,d0
                move.l  d0,d1
                move.l  d0,d2
                move.l  d0,d3
                move.l  d0,d4
                move.l  d0,d5
                move.l  d0,d6
				suba.l  a1,a1

                add.l	#32*1024,a0			; End of screen
                moveq   #64-1,d7
.loop_clear:
			rept 16
                movem.l d0-d6/a1,-(a0)      ; 32 bytes * 16
			endr
                dbf     d7,.loop_clear      ; 64 loop

                rts
				
; =============================================================================
;  ZONE DE DONNÉES / VARIABLES
; =============================================================================
				even
ScreenBase:					dc.l	$20000
ScreenBaseFront:			dc.l	$28000
	even
VBlankTimer:				dc.l	0
	even
BufferNum:					dc.w	0
	even
NbLoop:						dc.l	0
	even
							dcb.b	2048,0
TopOfStack:
	even
Font:						incbin 		"Data\Font8x8.bin"
	even
;LogoRetroProg:				incbin 		"Data\logo.bin.zx0"
	even
Demo01:						incbin 		"Data\Demo01.bin"
	even
	even

