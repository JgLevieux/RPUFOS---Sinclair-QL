
				bra		Start

	even
	include "macros.asm"
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

				DBGBREAK
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
				;bsr     ClearScreen
			
				move.l	#$20000,a0
				;bsr     ClearScreen

				lea		ScreenBase(pc),a0
				move.l	#$20000,(a0)

			; Setup VBL interrupt (thanks to QLSys 0.01 by spkr/smfx for the sample code)
			DBGBREAK
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

			
MainLoop:
			; WaitVBlank
				;bsr		WaitVBlank
				;bra		MainLoop

				bsr		SwapBuffer

				bra		MainLoop
				bsr		DrawVblTimer
				
					even
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
;=============================================================================
VBLInterrupt:
				movem.l d0-a6,-(sp)
				DBGBREAK

				;bsr		PlayMusic
				
			; Clean unused stuff around function ptr for clearer screen
				lea		$28000,a0
				moveq	#0,d0
				move.l	d0,$2C(a0)
				move.l	d0,$2C+4(a0)
				
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
				lsr.l	#5,d0				; 1520/32 = 48

				cmp.l	#48,d0
				ble.s	.finborne
				move.l	#48,d0
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
				add.l	#64,a0				; middle of first line of screen (after interrupt vector)

				move.w	d6,(a0)+ ; First pixel to see the start
				move.w	d6,(a0)+ ; First pixel to see the start

				move.l	#48,d1
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
							dcb.b	64*1024,0
	even

