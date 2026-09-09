
				bra		Start

	even
	include "macros.asm"
	even
	include "controls.asm"
	even
	include "Music.asm"
	even
	include "random.asm"
	even
	
; =============================================================================

;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000

IsMinverva:		dc.w	0

; =============================================================================
Start:
				DBGENABLE
			; Remove QDOS, mainly for double buffering as second screen adress contain QDOS data
                trap    #0              			; Call QDOS for Superviseur mode

			; Check if minerva is used
				moveq	#0,d0							; get rom version
				trap	#1								; get rom version trap call
				cmp.w	#$3130,d2						; check for JSROM
				lea		IsMinverva(pc),a0
				beq		.isjs
.ismin:
				move.w	#-1,(a0)						; -1 if minerva
				jmp	.cont
.isjs
				move.w	#0,(a0)							; 0 if jsrom
.cont:

			; No interrupt
				move.w	#$2700,sr

			; Set my own stack
				lea		TopOfStack(pc),a0
				move.l	a0,sp

			
			; Setup double buffering & first clear
				move.b	#ScreenMode01,$18063
				move.l	#$28000,a0
				bsr     ClearScreen
			
				move.l	#$20000,a0
				bsr     ClearScreen

				lea		ScreenBase(pc),a0
				move.l	#$20000,(a0)

			; Setup VBL interrupt (thanks to QLSys 0.01 by spkr/smfx for the sample code)
				lea		VBLRouterList(pc),a0
				lea		VBLInterrupt(pc),a1
				move.l	a1,4(a0)					; Function to be called each frame with relocation.
				
				lea		IsMinverva(pc),a2
				tst.w	(a2)
				bne.s	.InitForMinerva
				move.l	a0,$2803c					; write VBLANK pointer to JSROM location
				bra.s	.SetupIntDone
.InitForMinerva:
				move.l	a0,$3803c					; write VBLANK pointer to Minerva location
.SetupIntDone:
				move.w	#$2100,sr					; Enable interrupts for Vbl, keyboard & sound (as well as microdrive & rs232)

			; Frame counter (real display)
				lea     NbLoop(pc),a0
                move.l  #0,(a0)
				lea     NbVbl(pc),a0
                move.l  #0,(a0)

				lea		Music_Demoscene(pc),a0
				;bsr		StartMusic

				bsr		StartScrolling
			
MainLoop:
				bsr		WaitVBlank

				bsr		SwapBuffer

				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				move.l	#0,d0
				bsr		ClearScreenMinusOneLine

				bsr		DrawVblTimer
				
				bsr 	ReadKeyboard

				lea		Keyboard(pc),a1
				btst	#Keyboard01_ESC,1(a1)
				beq.s	.NoESC
				DBGBREAK
.NoESC:
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Enter,d4		; Press space to move while tracing
				beq.s	.nobreakpoint
				DBGBREAK
				
				;bsr			SoundTest
				
.nobreakpoint:
			; Loop counter
				lea     NbVbl(pc),a0
				move.l	(a0),d6

				bsr		ProcessScrolling

				bra		MainLoop

                rts


;https://jenesuis.net/images_site/jeux/msx/knightmare/
SCROLL_X_SIZE	equ		(96)
SCROLL_Y_SIZE	equ		(192)

ScrollYPos:		dc.l	8*2

ScrollMap:
		dc.b	 1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 0, 2
		dc.b	 0, 3, 0, 1, 1, 0, 3, 1, 0, 2, 0, 1
		dc.b	 1, 0, 3, 1, 0, 1, 0, 1, 0, 0, 3, 1
		dc.b	 1, 0, 0, 1, 0, 2, 1, 2, 1, 1, 0, 2
		dc.b	 4, 5, 4, 5, 9,10,11,12, 4, 5, 4, 5
		dc.b	 6, 6, 6, 6, 9,10,11,12, 6, 6, 6, 6
		dc.b	 6, 6, 6, 6, 9,10,11,12, 6, 6, 6, 6
		dc.b	 6, 6, 6, 6, 9,10,11,12, 6, 6, 6, 6
		dc.b	 7, 8, 7, 8, 9,10,11,12, 7, 8, 7, 8
		dc.b	 1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 0, 2
		dc.b	 0, 3, 0, 1, 1, 0, 3, 1, 0, 2, 0, 1
		dc.b	 1, 0, 3, 1, 0, 1, 0, 1, 0, 0, 3, 1
		dc.b	 1, 0, 0, 1, 0, 2, 1, 2, 1, 1, 0, 2
		dc.b	 1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 0, 2
		dc.b	 0, 3, 0, 1, 1, 0, 3, 1, 0, 2, 0, 1
		dc.b	 1, 0, 3, 1, 0, 1, 0, 1, 0, 0, 3, 1
		dc.b	 1, 0, 0, 1, 0, 2, 1, 2, 1, 1, 0, 2
		dc.b	 1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 0, 2
		dc.b	 0, 3, 0, 1, 1, 0, 3, 1, 0, 2, 0, 1
		dc.b	 1, 0, 3, 1, 0, 1, 0, 1, 0, 0, 3, 1
		dc.b	 1, 0, 0, 1, 0, 2, 1, 2, 1, 1, 0, 2
		dc.b	 1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 0, 2
		dc.b	 0, 3, 0, 1, 1, 0, 3, 1, 0, 2, 0, 1
		dc.b	 1, 0, 3, 1, 0, 1, 0, 1, 0, 0, 3, 1
		dc.b	 1, 0, 0, 1, 0, 2, 1, 2, 1, 1, 0, 2
		dc.b	 1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 0, 2
		dc.b	 0, 3, 0, 1, 1, 0, 3, 1, 0, 2, 0, 1
		dc.b	 1, 0, 3, 1, 0, 1, 0, 1, 0, 0, 3, 1
		dc.b	 1, 0, 0, 1, 0, 2, 1, 2, 1, 1, 0, 2

;=============================================================================
; Start Logo Eko
;=============================================================================
StartScrolling:
				lea		$20000,a0
				;move.l	#$AAFFAAFF,d0
				move.l	#0,d0
				bsr		ClearScreenMinusOneLine

				lea		$28000,a0
				;move.l	#$AAFFAAFF,d0
				move.l	#0,d0
				bsr		ClearScreenMinusOneLine

				lea		BufferData(pc),a0
				lea		Tiles(pc),a1
				lea		ScrollMap(pc),a2

				move.l	#(SCROLL_Y_SIZE/8)+2-1,d7
.LoopY:
				move.l	#SCROLL_X_SIZE/8-1,d6
.LoopX:
				lea		Tiles(pc),a1
				moveq	#0,d0
				move.b	(a2)+,d0
				lsl.l	#5,d0
				add.l	d0,a1
.y set 0
			rept	8
				move.l	(a1)+,.y(a0)
.y set .y+(SCROLL_X_SIZE/2)
			endr
				lea		4(a0),a0
				dbra	d6,.LoopX
				lea		(SCROLL_X_SIZE/2)*7(a0),a0
				dbra	d7,.LoopY

				rts

;=============================================================================
; Process Scrolling
;=============================================================================
ProcessScrolling:
				lea		BufferData(pc),a0

				lea		ScreenBase(pc),a1
				move.l	(a1),a1
				add.l	#64-SCROLL_X_SIZE/4,a1
                add.l	#128*(128)-128*(SCROLL_Y_SIZE/2),a1
				
				lea		ScrollYPos(pc),a3
				lea		Keyboard(pc),a2
				btst	#Keyboard01_Up,1(a2)
				beq.s	.NoUp
				add.l	#1,(a3)
.NoUp:
				btst	#Keyboard01_Down,1(a2)
				beq.s	.NoDown
				sub.l	#1,(a3)
.NoDown:
				move.l	(a3),d0
				and.l	#7,d0
				move.l	d0,d1
				lsl.l	#4,d0
				lsl.l	#5,d1
				add.l	d0,a0
				add.l	d1,a0

.loop:
	rept SCROLL_Y_SIZE
                movem.l (a0)+,d0-d6/a2-a6
				movem.l	d0-d6/a2-a6,(a1)
				;lea		(12*4)(a1),a1

                ;movem.l (a0)+,d0-d3
				;movem.l	d0-d3,(a1)

				lea		(128)(a1),a1
	endr

				rts

;=============================================================================
; Swap buffer for double buffering
;=============================================================================
SwapBuffer:
				move.w	DoSwapBuffer(pc),d0
				beq.s	.swapscreen2

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
				rts

DeactivateSwapBuffer:
				lea		DoSwapBuffer(pc),a1
				move.w	#0,(a1)

				lea		BufferNum(pc),a1
				move.w	#0,(a1)

				lea		ScreenBase(pc),a0
				move.l	#$20000,(a0)
				lea		ScreenBaseFront(pc),a0
				move.l	#$28000,(a0)

				move.b	#ScreenMode01,$18063			; Display screen 1
				rts
				
ActivateSwapBuffer:
				lea		DoSwapBuffer(pc),a1
				move.w	#1,(a1)
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
; Display a sprite, 32x32 with mask , !!! no clipping !!!
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
DisplaySprite32x32Masked:
				;DBGBREAK
				
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				move.l	a1,a2
				lea		512(a2),a2		; a2 = mask

				move.w  #128-32/2,d1
                
			rept 32  ; lines
				rept 4
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+
				endr
					adda.w  d1,a0
			endr
				rts

DisplaySprite32x32:
				;DBGBREAK
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				move.l	a1,a2
				lea		512(a2),a2		; a2 = mask

				move.w  #128-32/2,d1
                
			rept 32  ; lines
				rept 4
					move.l  (a1)+,(a0)+
				endr
					adda.w  d1,a0
			endr
				rts

;=============================================================================
; Display a sprite, 8x8 no mask, no shifting, no clipping
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1, a1
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

.y set 0
			rept 8
				move.l  (a1)+,.y(a0)
.y set .y+128
			endr

				rts

;=============================================================================
	even
VblTimeUsed:				dc.l	0					; How many time we wait during the last VBL
VblNbFrameLastLoop:			dc.l	0					; How many VBL int furing the previous process
VblNbFrameLastLoopSaved:	dc.l	0					; Save for debug display

NbLoop:						dc.l	0					; Num of the current frame displayed
NbVbl:						dc.l	0					; Nb Vbl (50 FPS) triggered (for real time counter)

VblLastLoop:				dc.l	0					; Num of the last frame that triggered a Vbl for the main process
VblInt:						dc.l	0					; 0 if we must wait, 1 if vbl int occurs

VBLRouterList:				dc.l	0,VBLInterrupt		; !!! Must be relocated !!!
	even
	dcb.l	14
	even
;=============================================================================
VBLInterrupt:
				movem.l d0-a6,-(sp)
				bsr		PlayMusic
				
			; Clean unused stuff around function ptr for clearer screen
				lea		$28000,a0
				moveq	#0,d0
				move.l	d0,$2C(a0)
				move.l	d0,$2C+4(a0)
				
				;DBGBREAK
			; Stop possible flash bit activated by VblInt function adress
				moveq	#0,d1
				move.w	$3C+2(a0),d0
				btst	#16,d0
				beq.s	.F3
				bset	#16,d1
.F3:
				btst	#14,d0
				beq.s	.F2
				bset	#14,d1
.F2:
				btst	#12,d0
				beq.s	.F1
				bset	#12,d1
.F1:
				btst	#10,d0
				beq.s	.F0
				bset	#10,d1
.F0:
				move.w	d1,$3C+4(a0)
				
			; Vbl counter
				lea		VblNbFrameLastLoop(pc),a0
				add.l	#1,(a0)
				lea		NbVbl(pc),a0
				add.l	#1,(a0)

			; Check if we have finished the process of the current display
				lea     NbLoop(pc),a0
				move.l	(a0),d0							; Current num frame
				lea		VblLastLoop(pc),a1
				move.l	(a1),d1							; Last loop num frame
				cmp.l	d0,d1
				beq.s	.DoNotTriggerVblForMainLoop		; While it's the same we do not trigger VBL for the main loop
				
				move.l	(a0),(a1)						; We save last num frame

				lea		VblInt(pc),a0
				move.l	#1,(a0)							; Trigger the vbl for main process
.DoNotTriggerVblForMainLoop:

				movem.l	(sp)+,d0-a6
				rts

;=============================================================================
 ; d0.l = nb vbl (50 = 1 second)
WaitNbVBlank:
				move.l a0,-(sp)

				lea		NbVbl(pc),a0
				add.l	(a0),d0
.LoopWait:
				cmp.l	(a0),d0
				bge.s	.LoopWait

				move.l	(sp)+,a0
				rts

;=============================================================================
WaitVBlank:
				lea     NbLoop(pc),a0
				add.l	#1,(a0)						; Increase current frame, so we can have a vbl int triggered

				moveq	#0,d1
				moveq	#1,d2
				
				lea		VblInt(pc),a0
.wait:
				add.l	d2,d1
				tst.l	(a0)
				beq.s	.wait

				move.l	#0,(a0)							; Reset Vbl int for main loop.

				lea		VblTimeUsed(pc),a0
				move.l	d1,(a0)
				
				lea		VblNbFrameLastLoop(pc),a0
				lea		VblNbFrameLastLoopSaved(pc),a1
				move.l	(a0),(a1)
				move.l	#0,(a0)

				rts

;=============================================================================
DrawVblTimer:
;	DBGBREAK
				lea		VblTimeUsed(pc),a0
				move.l	(a0),d1				; max 1520 mesured with debugger
				move.l	#1520,d0
				sub.l	d1,d0
				bgt		.SupZero
				move.l	#0,d0
.SupZero:
				lsr.l	#4,d0				; 1520/32 = 48

				cmp.l	#95,d0
				ble.s	.finborne
				move.l	#95,d0
.finborne:

				move.w	#$AAFF,d7			; Time used (white) - one frame
				move.w	#$0055,d6			; Borne (blue)
				move.w	#$AA00,d5			; Time Left (green)
				
				lea		VblNbFrameLastLoopSaved(pc),a1
				cmp.l	#1,(a1)
				beq.s	.Draw
				move.w	#$00FF,d7			; Time used (magenta) - two frames
				cmp.l	#2,(a1)
				beq.s	.Draw
				move.w	#$00AA,d7			; Time used (rouge) - three frames or more
				
.Draw:
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				add.l	#128+(128-95)/2-2,a0				; middle of first line of screen (after interrupt vector)

				move.w	d6,(a0)+ ; First pixel to see the start
				move.w	d6,(a0)+ ; First pixel to see the start

				move.l	#95,d1
				lsr.l	#1,d0				; Words.
				lsr.l	#1,d1				; Words.
.DrawLoopGet:
				sub.l	#1,d1
				move.w	d7,(a0)+
				dbra	d0,.DrawLoopGet
.DrawLoopFree:
				move.w	d5,(a0)+
				dbra	d1,.DrawLoopFree

				move.w	d6,(a0)+ ; Last pixel to see the end
				move.w	d6,(a0)+ ; Last pixel to see the end
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
; Clear screen minus one line
; a0 - Screen adr
; d0 - Color
; =============================================================================
ClearScreenMinusOneLine:
                move.l  d0,d1
                move.l  d0,d2
                move.l  d0,d3
                move.l  d0,d4
                move.l  d0,d5
                move.l  d0,d6
				move.l  d0,a1

                add.l	#32*1024,a0			; End of screen
                moveq   #63-1,d7
.loop_clear:
			rept 16
                movem.l d0-d6/a1,-(a0)      ; 32 bytes * 16
			endr
                dbf     d7,.loop_clear      ; 64 loop

			rept 12
                movem.l d0-d6/a1,-(a0)      ; 32 bytes * 16
			endr
                rts

; =============================================================================
; Copy screen
; a0 - Source adr
; a1 - Dest adr
; =============================================================================
CopyScreen:
                moveq   #64-1,d7
.loop_clear:
			rept 16
                movem.l (a0)+,d0-d6/a2      	; 32 bytes * 16
                movem.l d0-d6/a2,(a1)	      	; 32 bytes * 16
				lea		32(a1),a1
			endr
                dbf     d7,.loop_clear      	; 64 loop

                rts

CopyScreenMinusOneLine:
                moveq   #63-1,d7
.loop_clear:
			rept 16
                movem.l (a0)+,d0-d6/a2      	; 32 bytes * 16
                movem.l d0-d6/a2,(a1)	      	; 32 bytes * 16
				lea		32(a1),a1
			endr
                dbf     d7,.loop_clear      	; 64 loop

			rept 12
                movem.l (a0)+,d0-d6/a2      	; 32 bytes * 16
                movem.l d0-d6/a2,(a1)	      	; 32 bytes * 16
				lea		32(a1),a1
			endr
                rts

; =============================================================================
;  ZONE DE DONNÉES / VARIABLES
; =============================================================================
	even
ScreenBase:					dc.l	$20000
ScreenBaseFront:			dc.l	$28000
	even
BufferNum:					dc.w	0
DoSwapBuffer:				dc.w	1
	even
							dcb.b	512,0
TopOfStack:
	even
Font:						incbin 		"Data\Font8x8.bin"
	even
Tiles:						incbin 		"Data\Game\Tiles.bin"
	even
BufferData:
		dcb.b				32*1024,0
