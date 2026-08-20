
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
	include "unzx0_68000.asm"
	even
	include "PlotPixel.asm"
	even
	include "3D.asm"
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
				bsr		StartMusic

				bsr		StartLogoEko

				;bsr		StartLogoRetroProg
				;bsr		StartFireEffect
				;bsr		StartBobShading
				;bsr			StartPlasma
				;bsr		StartOutro
				;bsr		StartCharaFalling
				;bsr		Start3D
				;bsr			StartTextAnimation
			
MainLoop:
				bsr		WaitVBlank

				bsr		SwapBuffer

				;bsr		DrawVblTimer
				
				;bsr 	ReadKeyboard

				btst	#Keyboard01_ESC,1(a1)
				beq.s	.NoESC
				DBGBREAK
.NoESC:
				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Enter,d4		; Press space to move while tracing
				beq.s	.nobreakpoint
				DBGBREAK
				
				;bsr			SoundTest
				
.nobreakpoint:
			; Loop counter
				lea     NbVbl(pc),a0
				move.l	(a0),d6

				lea		DemoStatus(pc),a0
				move.l	(a0),d0
				
				cmp.l	#STATUS_DEMO_LOGO_EKO,d0
				beq.s	.CaseLogoEko
				
				cmp.l	#STATUS_DEMO_LOGO_RETRO_PROG,d0
				beq.s	.CaseLogoRetroProg

				cmp.l	#STATUS_DEMO_PLASMA_EFFECT,d0
				beq.s   .CasePlasma

				cmp.l	#STATUS_DEMO_BOB_SHADING,d0
				beq.s   .CaseBobShading

				cmp.l	#STATUS_DEMO_FIRE,d0
				beq.s   .CaseFire

				cmp.l	#STATUS_DEMO_OUTRO_01,d0
				beq.s   .CaseOutro01

				cmp.l	#STATUS_DEMO_OUTRO_02,d0
				beq.s   .CaseOutro02
				
				cmp.l	#STATUS_DEMO_OUTRO_FALLING,d0
				beq.s   .CaseOutroFalling

				cmp.l	#STATUS_DEMO_OUTRO_3D,d0
				beq.s   .CaseOutro3D
				
				cmp.l	#STATUS_DEMO_TEXT_ANIM,d0
				beq.s	.CaseTextAnimation
				
				bra.s   .EndSwitch

.CaseLogoEko:
				bsr		ProcessLogoEko
				bra.s   .EndSwitch
				
.CaseLogoRetroProg:
				bsr		ProcessEraseScreen
				bsr		StartPlasma
				bra.s   .EndSwitch

.CasePlasma:
				bsr		PlasmaEffect
				bra.s   .EndSwitch
				
.CaseBobShading:
				bsr		ProcessBobShading
				bra.s   .EndSwitch

.CaseFire:
				bsr		ProcessFireEffect
				bra.s   .EndSwitch
				
.CaseOutro01:
				cmp.l	#150,d6
				bmi		.NotEndCaseOutro01
				move.l	#STATUS_DEMO_OUTRO_02,(a0)

.NotEndCaseOutro01:
				bsr		OutroAroundEffect
				bra.s   .EndSwitch
				
.CaseOutro02:
				bsr		OutroAroundEffect
				bsr		ReplaceOutroImage
				bra.s   .EndSwitch
				
.CaseOutroFalling:
				bsr		CharaFalling
				bsr		DrawRedLine
				bra.s   .EndSwitch

.CaseOutro3D:
				cmp.l	#800,d6
				bmi		.NotEndOutro3D
				bsr		StartTextAnimation
				bra.s   .EndSwitch

.NotEndOutro3D:
				bsr		DrawRedLine
				bsr		Draw3D
				bra.s   .EndSwitch

.CaseTextAnimation:
				bsr		DisplayTextAnim
				bra.s   .EndSwitch
				nop
.EndSwitch:

				bra		MainLoop

                rts

					even

;=============================================================================
; Demo var
;=============================================================================
STATUS_DEMO_OUTRO_01			equ			1
STATUS_DEMO_OUTRO_02			equ			2
STATUS_DEMO_OUTRO_FALLING		equ			3
STATUS_DEMO_PLASMA_EFFECT  		equ			4
STATUS_DEMO_OUTRO_3D			equ			5
STATUS_DEMO_LOGO_EKO			equ			6
STATUS_DEMO_LOGO_RETRO_PROG		equ			7
STATUS_DEMO_BOB_SHADING			equ			8
STATUS_DEMO_FIRE				equ			9
STATUS_DEMO_TEXT_ANIM			equ			10

	even
DemoStatus:			dc.l	STATUS_DEMO_OUTRO_01

;=============================================================================
; Process Erase Screen
;=============================================================================
	macro SquareStepOne
				move.l	d0,128*0(\1)
.y set 1
			rept 6
				and.w	d1,128*.y(\1)
				and.w	d4,128*.y+2(\1)
.y set .y+1
			endr
				move.l	d0,128*7(\1)
	endm

	macro SquareStepTwo
				move.l	d0,128*1(\1)
.y set 2
			rept 4
				and.w	d2,128*.y(\1)
				and.w	d3,128*.y+2(\1)
.y set .y+1
			endr
				move.l	d0,128*6(\1)
	endm

	macro SquareStepThree
				move.l	d0,128*2(\1)
.y set 3
			rept 2
				and.w	d2,128*.y(\1)
				and.w	d3,128*.y+2(\1)
.y set .y+1
			endr
				move.l	d0,128*5(\1)
	endm

	macro SquareStepFour
				move.l	d0,128*3(\1)
				move.l	d0,128*4(\1)
	endm
;=============================================================================
ProcessEraseScreen:

; Create offset table
				move.l	#128,d0
				lea		BufferData(pc),a0
				move.l	#32-1,d7
.CreateOffsetTableY:
				move.l	#32-1,d6
.CreateOffsetTableX:

				move.w	d0,(a0)+
				add.l	#4,d0
				dbra	d6,.CreateOffsetTableX

				cmp.l	#31,d7					; First line ?
				bne.s	.NotFirstLine
				sub.l	#128,d0
.NotFirstLine:
				add.l	#128*7,d0
				dbra	d7,.CreateOffsetTableY

; Randomize square
				lea		BufferData(pc),a0
				move.l	#32*32-1,d7
.RandomizeLoop:
				bsr		GetRandom
				and.w	#$3FF,d0
				add.w	d0,d0
				move.w	d0,d2
				bsr		GetRandom
				and.w	#$3FF,d0
				add.w	d0,d0
				move.w	(a0,d0.w),d3
				move.w	(a0,d2.w),d4
				move.w	d4,(a0,d0.w)
				move.w	d3,(a0,d2.w)
				dbra	d7,.RandomizeLoop
				
; Erase 32 square at a time
				lea		$20000,a2
				lea		$28000,a3

				moveq	#0,d0
				move.w	#$3F3F,d1
				move.w	#$CFCF,d2
				move.w	#$F3F3,d3
				move.w	#$FCFC,d4

ERASE_NB_SQUARE_SAME_TIME	equ		512

				lea		BufferData(pc),a0
				move.l	#(1024/ERASE_NB_SQUARE_SAME_TIME)-1,d7		; Nb lines (square of 8)
.LoopLine:
				move.l	#ERASE_NB_SQUARE_SAME_TIME-1,d6
.LoopStepOne:
				move.l	a2,a4
				move.l	a3,a5
				add.w	(a0),a4
				add.w	(a0)+,a5
				SquareStepOne <a4>
				SquareStepOne <a5>
				dbra	d6,.LoopStepOne

				sub.l	#ERASE_NB_SQUARE_SAME_TIME*2,a0
				move.l	#ERASE_NB_SQUARE_SAME_TIME-1,d6
.LoopStepTwo:
				move.l	a2,a4
				move.l	a3,a5
				add.w	(a0),a4
				add.w	(a0)+,a5
				SquareStepTwo <a4>
				SquareStepTwo <a5>
				dbra	d6,.LoopStepTwo

				sub.l	#ERASE_NB_SQUARE_SAME_TIME*2,a0
				move.l	#ERASE_NB_SQUARE_SAME_TIME-1,d6
.LoopStepThree:
				move.l	a2,a4
				move.l	a3,a5
				add.w	(a0),a4
				add.w	(a0)+,a5
				SquareStepThree <a4>
				SquareStepThree <a5>
				dbra	d6,.LoopStepThree

				sub.l	#ERASE_NB_SQUARE_SAME_TIME*2,a0
				move.l	#ERASE_NB_SQUARE_SAME_TIME-1,d6
.LoopStepFour:
				move.l	a2,a4
				move.l	a3,a5
				add.w	(a0),a4
				add.w	(a0)+,a5
				SquareStepFour <a4>
				SquareStepFour <a5>
				dbra	d6,.LoopStepFour

				;move.l	#5,d0
				;bsr		WaitNbVBlank
				;moveq	#0,d0

				dbra	d7,.LoopLine

				rts
				
;=============================================================================
; Start Logo Eko
;=============================================================================
StartLogoEko:
				lea		$20000,a0
				move.l	#$AAFFAAFF,d0
				move.l	#0,d0
				bsr		ClearScreenMinusOneLine

				lea		$28000,a0
				move.l	#$AAFFAAFF,d0
				move.l	#0,d0
				bsr		ClearScreenMinusOneLine

				lea		LogoEko(pc),a0
				lea		$20000+128*(128-150/2),a1
				bsr		zx0_decompress

				lea		LogoEko(pc),a0
				lea		$28000+128*(128-150/2),a1
				bsr		zx0_decompress

				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_LOGO_EKO,(a0)


				move.l	#300,d0
				bsr		WaitNbVBlank

				bsr		ProcessEraseScreen
				
				bsr		StartFireEffect

			
				rts

;=============================================================================
; Process Logo Eko
;=============================================================================
ProcessLogoEko:
				rts
				
							even
Texts_Animation:			
	dc.l		128-26*8/2, 50+8*0
	dc.b		"THIS DEMO WAS MADE FOR THE",0
	even

	dc.l		128-24*8/2, 50+8*4
	dc.b		"RETRO PROGRAMMERS UNITED",0
	even

	dc.l		128-19*8/2, 50+8*6
	dc.b		"FOR OBSCURE SYSTEMS",0
	even

	dc.l		128-20*8/2, 50+8*10
	dc.b		"PROGRAMMING JAM 2026",0
	even

	dc.l		128-14*8/2, 50+8*12
	dc.b		"ON SINCLAIR QL",0 ; Last text to be display

	even
	dc.l		-1
	even

	dc.l		128-28*8/2, 50
	dc.b		"CREDITS FOR THIS LITTLE DEMO",0
	even

	dc.l		128-10*8/2, 50+8*8
	dc.b		"CODE - JGL",0
	even

	dc.l		128-27*8/2, 50+8*12
	dc.b		"ART - JGL, HELPED BY GEMINI",0
	even

	dc.l		128-29*8/2, 50+8*16
	dc.b		"MUSIC - GEMINI, HELPED BY JGL",0
	even

	dc.l		-1
	even
	
	dc.l		128-23*8/2, 50+8*0
	dc.b		"BIG THANKS TO",0
	even

	dc.l		128-31*8/2, 50+8*6
	dc.b		"CHIBIAKUMAS & HIS QL DEVTOOLKIT",0
	even

	dc.l		128-25*8/2, 50+8*10
	dc.b		"TERDINA FOR HIS QEMULATOR",0
	even

	dc.l		128-30*8/2, 50+8*14
	dc.b		"SPKR/SMFX FOR THE QLSYS SAMPLE",0
	even

	dc.l		128-31*8/2, 50+8*18
	dc.b		"OTHERS RETRO PROGRAMMERS UNITED",0
	even

	even
	dc.l		-1
	even

	dc.l		128-23*8/2, 50+8*0
	dc.b		"AND TO",0
	even

	dc.l		128-31*8/2, 50+8*6
	dc.b		"MAXOUT, THANKS FOR ALL AND MORE",0
	even

	dc.l		128-22*8/2, 50+8*10
	dc.b		"AND LAST BUT NOT LEAST",0
	even
	dc.l		128-30*8/2, 50+8*12
	dc.b		"OLIPIX - CREATOR OF THE RPUFOS",0
	even
	dc.l		128-31*8/2, 50+8*14
	dc.b		"!CHECK OUT HIS YOUTUBE CHANNEL!",0
	even

	dc.l		128-15*8/2, 50+8*20
	dc.b		"!!! BYE BYE !!!",0
	even

	even
	dc.l		-2
	even

	RSRESET
STextAnim_TextAdr:			RS.L 1		; Text Adr
STextAnim_FinalX:			RS.L 1		; Final Y pos
STextAnim_FinalY:			RS.L 1		; Final Y pos
STextAnim_CurrentY:			RS.L 1		; Current Y pos
STextAnim_SinOffset:		RS.L 1		; Y speed - 24:8 format
STextAnim_SIZEOF:     		RS.B 0

TextAnimation:				dcb.b    STextAnim_SIZEOF,0
	even
CurrentTextAnim:			dc.l	0

;=============================================================================
; Start text animation
;=============================================================================
StartTextAnimation:
				bsr		ProcessEraseScreen

				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_TEXT_ANIM,(a0)

				lea     NbLoop(pc),a0
                move.l  #0,(a0)
				lea     NbVbl(pc),a0
                move.l  #0,(a0)

				lea		Texts_Animation(pc),a0
				lea		CurrentTextAnim(pc),a1
				move.l	a0,(a1)

				bsr		StartNextTextAnimation
				rts
				
;=============================================================================
; Start Next text animation
; a1 = Coord & Text Adr
;=============================================================================
StartNextTextAnimation:
				lea		CurrentTextAnim(pc),a2
				move.l	(a2),a0

				cmp.l	#-2,(a0)
				beq.s	.Restart

				cmp.l	#-1,(a0)
				bne.s	.SetNext

				move.l	#200,d0
				bsr		WaitNbVBlank
				bsr		ProcessEraseScreen

				lea		CurrentTextAnim(pc),a2
				move.l	(a2),a0
				add.l	#4,a0
.SetNext:

				lea		TextAnimation(pc),a1
				move.l	(a0)+,d0				; x final
				move.l	(a0)+,d1				; y final
				
				move.l	d0,STextAnim_FinalX(a1)
				move.l	d1,STextAnim_FinalY(a1)
				move.l	#255+16,STextAnim_CurrentY(a1)
				move.l	a0,STextAnim_TextAdr(a1)
				move.l	#0,STextAnim_SinOffset(a1)
				
.Loop:
				tst.b	(a0)+
				bne.s	.Loop

				move.l	a0,d0
				add.l	#1,d0
				and.l	#$FFFFFFFE,d0			; make it even
				
				move.l	d0,(a2)
				rts

.Restart:
				move.l	#20000,d0
				bsr		WaitNbVBlank
				bsr		StartTextAnimation
				rts

SinTable16:
    dc.b    8,8,9,9,10,10,10,11,11,11,12,12,12,13,13,13
    dc.b    14,14,14,14,15,15,15,15,15,16,16,16,16,16,16,16
    dc.b    16,16,16,16,16,16,16,15,15,15,15,15,14,14,14,14
    dc.b    13,13,13,12,12,12,11,11,11,10,10,10,9,9,8,8
    dc.b    8,8,7,7,6,6,6,5,5,5,4,4,4,3,3,3
    dc.b    2,2,2,2,1,1,1,1,1,0,0,0,0,0,0,0
    dc.b    0,0,0,0,0,0,0,1,1,1,1,1,2,2,2,2
    dc.b    3,3,3,4,4,4,5,5,5,6,6,6,7,7,8,8

;=============================================================================
; DisplayTextAnim
;=============================================================================
DisplayTextAnim:
				lea		TextAnimation(pc),a3
				move.l	STextAnim_TextAdr(a3),a4
				move.l	STextAnim_FinalX(a3),d5
				move.l	STextAnim_CurrentY(a3),d6
				move.l	STextAnim_SinOffset(a3),d4
				lea		SinTable16(pc),a5

.LoopDisplayTextAnim:
				moveq	#0,d2
				move.b	(a4)+,d2			; get char
				beq		.endoftext
				cmp.b	#32,d2
				beq		.next				; space
				
				move.l	d6,d3
				moveq	#0,d0
				move.b	(a5,d4.w),d0
				add.l	d0,d3
				cmp.l	STextAnim_FinalY(a3),d3
				bge.s	.NotAbove
				move.l	STextAnim_FinalY(a3),d3
.NotAbove:
				
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				move.l	a0,a6
				add.l	#$8000,a6
				lea		Font(pc),a1
				sub.b	#33,d2				; sub first char (start with "!")
				lsl.l	#5,d2				; *32 : 4 bytes (2 words for 8 pixels) * 8 lines
				add.l	d2,a1
				move.l	d5,d0
				move.l	d3,d1

				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen

			rept 8
				cmp.l	a6,a0
				bcc		.NoMoreDraw
				move.l  (a1)+,(a0)
				lea		128(a0),a0
			endr
			rept 8
				cmp.l	a6,a0
				bcc		.NoMoreDraw
				move.l  #0,(a0)
				lea		128(a0),a0
			endr
.NoMoreDraw:
.next:
				add.l	#8,d5				; next char 8 pixels to the right
				add.l	#6,d4
				and.l	#127,d4
				
				bra		.LoopDisplayTextAnim
.endoftext:
				sub.l	#2,STextAnim_CurrentY(a3)
				move.l	STextAnim_CurrentY(a3),d0
				add.l	#20,d0
				cmp.l	STextAnim_FinalY(a3),d0
				bge.s	.Above
				move.l	STextAnim_FinalY(a3),STextAnim_CurrentY(a3)

				bsr		StartNextTextAnimation
				rts

.Above:				
				add.l	#2,STextAnim_SinOffset(a3)
				and.l	#127,STextAnim_SinOffset(a3)
				rts

;=============================================================================
; Start Logo Retro prog
;=============================================================================
StartLogoRetroProg:
				bsr		ProcessEraseScreen

				lea		$20000,a0
				move.l	#$AAFFAAFF,d0
				;bsr		ClearScreenMinusOneLine

				lea		$28000,a0
				move.l	#$AAFFAAFF,d0
				;bsr		ClearScreenMinusOneLine

				lea		LogoRetroProg(pc),a0
				lea		$20000+128*(128-214/2),a1
				bsr		zx0_decompress

				lea		LogoRetroProg(pc),a0
				lea		$28000+128*(128-214/2),a1
				bsr		zx0_decompress

				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_LOGO_RETRO_PROG,(a0)
				
				move.l	#300,d0
				bsr		WaitNbVBlank
			
				rts

	even
SquareAroundPlasma:
				dc.l	63,6
				dc.l	64+128,6
				dc.l	64+128,250
				dc.l	63,250
				dc.l	63,6
	even
	
;=============================================================================
; Start Plasma
;=============================================================================
StartPlasma:
				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_PLASMA_EFFECT,(a0)
				lea     NbLoop(pc),a0
                move.l  #0,(a0)
				lea     NbVbl(pc),a0
                move.l  #0,(a0)

				move.l	#2-1,d3
.DrawSquareScreen:
				lea		SquareAroundPlasma(pc),a0
				move.l	#4-1,d7
.DrawSquare:
				move.l	(a0),d0
				move.l	4(a0),d1
				move.l	8(a0),d4
				move.l	12(a0),d5
				moveq	#1,d6
				bsr		DrawLine
				
				add.l	#8,a0
				
				dbra	d7,.DrawSquare
				bsr		SwapBuffer
				dbra	d3,.DrawSquareScreen
				
				rts

;=============================================================================
; Plasma
;=============================================================================
PlasmaEffect:
				lea		ScreenBase(pc),a4
				move.l	(a4),a4
				add.l	#32+128*7,a4
				
				lea		SinTable512(pc),a3
				lea		PlasmaColorLUT(pc),a2			; Color in table
				
				lea		NbLoop(pc),a1
				move.l	(a1),d5
				lsl.l	#1,d5					; Speed *2
				and.w	#$FF,d5					; Keep under 256
				
				btst	#2,d5
				beq.s	.NoDecal
				;DBGBREAK
				add.w	#256,a4
.NoDecal:				
				moveq	#60,d7
.LoopY:
				; Wave Y
				move.w	d7,d3
				add.w	d5,d3					; Y + T (Max: 63 + 255 = 318)
				move.b	(a3,d3.w),d3			; d3 = Wave Y (0-85)
				
				moveq	#64,d6
.LoopX:
				; Wave X
				move.w	d6,d1					; d1 = X
				add.w	d5,d1					; d1 = X + T
				move.w	d1,d4
				move.b	(a3,d1.w),d0			; d0 = Wave X (0-85)
				
				; Wave X+Y
				add.w	d7,d4					; d4 = (X+T) + Y (Max: 64+255+63 = 382)
				move.b	(a3,d4.w),d2			; d2 = Wave X+Y (0-85)
				
				; Wave sum
				add.b	d3,d0
				add.b	d2,d0
				
				; Color from table
				and.w	#$FF,d0
				lsl.w	#2,d0
				move.l	(a2,d0.w),d1
				
				; Write color
				;move.l	d1,128(a4)
				move.l	d1,(a4)+
				;move.l	d1,256-4(a4)
				;move.l	d1,126+128(a4)
				;move.w	d1,128*3(a4)
				;add.w	#2,a4
				
				subq.w	#4,d6
				bne.s	.LoopX
				
				lea		128*4-64(a4),a4
				dbra	d7,.LoopY

 				lea		NbVbl(pc),a1
				cmp.l	#50*15,(a1)
				bmi.s	.NoNextPart
				bsr		StartBobShading
.NoNextPart:

				rts

SinTable512:
    dc.b 63,64,65,66,66,67,67,68,68,68,68,68,67,67,66,66
    dc.b 65,64,64,63,62,61,60,59,57,56,55,54,53,52,50,49
    dc.b 48,47,46,45,44,43,42,42,41,40,40,39,39,38,38,38
    dc.b 37,37,37,37,37,38,38,38,38,39,39,40,40,40,41,41
    dc.b 42,43,43,44,44,44,45,45,46,46,46,46,47,47,47,47
    dc.b 47,46,46,46,45,45,44,44,43,42,42,41,40,39,38,37
    dc.b 36,35,34,32,31,30,29,28,27,25,24,23,22,21,20,20
    dc.b 19,18,18,17,17,16,16,16,16,16,17,17,18,18,19,20
    dc.b 21,22,23,24,26,27,29,31,32,34,36,38,40,42,45,47
    dc.b 49,51,53,55,58,60,62,64,66,68,69,71,73,74,76,77
    dc.b 78,79,80,81,82,82,82,82,82,82,82,81,81,80,79,78
    dc.b 77,75,74,72,70,68,66,64,62,60,57,55,52,50,47,45
    dc.b 42,39,37,34,32,29,27,24,22,20,18,16,14,12,10,09
    dc.b 07,06,05,04,03,03,02,02,02,02,02,02,02,03,04,05
    dc.b 06,07,08,10,11,13,15,16,18,20,22,24,26,29,31,33
    dc.b 35,37,39,42,44,46,48,50,52,53,55,57,58,60,61,62
    dc.b 63,64,65,66,66,67,67,68,68,68,68,68,67,67,66,66
    dc.b 65,64,64,63,62,61,60,59,57,56,55,54,53,52,50,49
    dc.b 48,47,46,45,44,43,42,42,41,40,40,39,39,38,38,38
    dc.b 37,37,37,37,37,38,38,38,38,39,39,40,40,40,41,41
    dc.b 42,43,43,44,44,44,45,45,46,46,46,46,47,47,47,47
    dc.b 47,46,46,46,45,45,44,44,43,42,42,41,40,39,38,37
    dc.b 36,35,34,32,31,30,29,28,27,25,24,23,22,21,20,20
    dc.b 19,18,18,17,17,16,16,16,16,16,17,17,18,18,19,20
    dc.b 21,22,23,24,26,27,29,31,32,34,36,38,40,42,45,47
    dc.b 49,51,53,55,58,60,62,64,66,68,69,71,73,74,76,77
    dc.b 78,79,80,81,82,82,82,82,82,82,82,81,81,80,79,78
    dc.b 77,75,74,72,70,68,66,64,62,60,57,55,52,50,47,45
    dc.b 42,39,37,34,32,29,27,24,22,20,18,16,14,12,10,09
    dc.b 07,06,05,04,03,03,02,02,02,02,02,02,02,03,04,05
    dc.b 06,07,08,10,11,13,15,16,18,20,22,24,26,29,31,33
    dc.b 35,37,39,42,44,46,48,50,52,53,55,57,58,60,61,62	

; G0 F0 G1 F1 G2 F2 G3 F3 / R0 B0 R1 B1 R2 B2 R3 B3
G0 equ %1000000000000000
G1 equ %0010000000000000
G2 equ %0000100000000000
G3 equ %0000001000000000
   
B0 equ %0000000001000000
B1 equ %0000000000010000
B2 equ %0000000000000100
B3 equ %0000000000000001
   
R0 equ %0000000010000000
R1 equ %0000000000100000
R2 equ %0000000000001000
R3 equ %0000000000000010

G02 equ (G0|G2)
B02 equ (B0|B2)
R02 equ (R0|R2)
G02B13 equ (G0|G2|B1|B3)
GB02G13 equ (G0|B0|G2|B2|G1|G3)
R02GB13 equ (R0|R2|G1|G3|B1|B3)
BR02R13 equ (B0|B2|R0|R2|R1|R3)
GR02BR13 equ (G0|G2|R0|R2|B1|B3|R1|R3)
GBR02GR13 equ (G0|G2|R0|R2|B0|B2|G1|G3|R1|R3)

PlasmaColorLUT:
    ; --- Bloc 0 (Index 0 à 31) - Noir ---
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
    dc.w B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02

    ; --- Bloc 1 (Index 32 à 63) - Bleu ---
    dc.w B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02,B02
    dc.l $00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055
    dc.l $00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055
	dc.w G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13

    ; --- Bloc 2 (Index 64 à 95) - Vert ---
	dc.w G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13,G02B13
    dc.l $AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00
    dc.l $AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00
    dc.w GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13

    ; --- Bloc 3 (Index 96 à 127) - Cyan (Vert + Bleu) ---
    dc.w GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13,GB02G13
    dc.l $AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55
    dc.l $AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55
    dc.w R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13

    ; --- Bloc 4 (Index 128 à 159) - Rouge ---
    dc.w R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13,R02GB13
    dc.l $00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA
    dc.l $00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA
    dc.w BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13

    ; --- Bloc 5 (Index 160 à 191) - Magenta (Rouge + Bleu) ---
    dc.w BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13,BR02R13
    dc.l $00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF
    dc.l $00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF
    dc.w GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13

    ; --- Bloc 6 (Index 192 à 223) - Jaune (Rouge + Vert) ---
    dc.w GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13,GR02BR13
    dc.l $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
    dc.l $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
    dc.w GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13

    ; --- Bloc 7 (Index 224 à 255) - Blanc (Rouge + Vert + Bleu) ---
    dc.w GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13,GBR02GR13
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF

;=============================================================================
; Start bob shading
;=============================================================================
StartBobShading:
				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_BOB_SHADING,(a0)

				lea     NbVbl(pc),a1
				move.l	#0,(a1)
				lea     NbLoop(pc),a1
				move.l	#0,(a1)
				
				lea		$20000,a0
				move.l	#0,d0
				;move.l	#$AAFFAAFF,d0
				bsr		ClearScreenMinusOneLine

				lea		$28000,a0
				move.l	#0,d0
				;move.l	#$AAFFAAFF,d0
				bsr		ClearScreenMinusOneLine

				lea		Current_Bob(pc),a0
				lea		Bob_01(pc),a1
				move.l	a1,(a0)
				lea		Bob_02(pc),a1
				move.l	a1,4(a0)
				rts

BobShading:
    dc.b 0,1,0,1, 1,0,1,0
    dc.b 0,1,2,1, 2,1,1,0
    dc.b 1,2,1,2, 1,2,1,1
    dc.b 1,2,1,2, 1,2,2,1
    dc.b 1,2,2,2, 2,2,2,1
    dc.b 1,2,1,2, 1,2,2,1
    dc.b 1,2,1,2, 1,2,1,1
    dc.b 1,1,2,2, 2,2,1,1
    dc.b 0,1,2,1, 2,1,1,0
    dc.b 0,1,0,1, 1,0,1,0

	even

	RSRESET
SBob_SinOffest:				RS.L 1
SBob_CosOffest:				RS.L 1
SBob_SinAdd:				RS.L 1
SBob_CosAdd:				RS.L 1
SBob_SIZEOF:     			RS.B 0

Bob_01:			dc.l	0, 0, 4, -3
Bob_02:			dc.l	0, 0, -2, 1
Bob_03:			dc.l	0, 0, -1, 5
Bob_04:			dc.l	0, 0, 2, -3

Current_Bob:	dc.l	0,0

ColorBobTrans:
	dc.w	ColorPixelBlack
	dc.w	ColorPixelBlue
	dc.w	ColorPixelRed
	dc.w	ColorPixelMagenta
	dc.w	ColorPixelGreen
	dc.w	ColorPixelYellow
	dc.w	ColorPixelYellow
	dc.w	ColorPixelWhite
	
;=============================================================================
; a0 : SBob
; d0.l : X, d1.l : Y
;=============================================================================
AddOneBob:
				move.l	SBob_SinOffest(a0),d2
				add.l	SBob_SinAdd(a0),d2
				and.l	#511,d2
				move.l	d2,SBob_SinOffest(a0)

				move.l	SBob_CosOffest(a0),d3
				add.l	SBob_CosAdd(a0),d3
				and.l	#511,d3
				move.l	d3,SBob_CosOffest(a0)
				
				lea		sin_table_8_232(pc),a1
				move.l	#0,d0
				move.b	(a1,d2.w),d0
				move.l	#0,d1
				move.b	(a1,d3.w),d1

				lea		$20000,a4
				lea 	BobShading(pc),a5
				lea 	ColorBobTrans(pc),a6
				
				move.l	d0,d4
				move.l	d1,d5
				move.l	#10-1,d7
.LoopY:
				move.l	#8-1,d6
.LoopX:
				move.l	#0,d3
				move.b	(a5)+,d3
				beq		.NoAdd

				move.l	d4,d0
				add.l	d6,d0
				move.l	d5,d1
				add.l	d7,d1
				
				bsr		GetPixel
				
				move.l	#0,d0
				move.l	d2,d1
				and.l	#$8000,d1
				beq.s	.NoGreen
				or.b	#%100,d0
.NoGreen:
				move.l	d2,d1
				and.l	#$80,d1
				beq.s	.NoRed
				or.b	#%010,d0
.NoRed:
				move.l	d2,d1
				and.l	#$40,d1
				beq.s	.NoBlue
				or.b	#%001,d0
.NoBlue:
				add.b	d0,d3
				cmp.l	#7,d3
				bmi.s	.NoMax
				move.b	#7,d3
.NoMax:
				lsl.w	#1,d3
				move.w	(a6,d3.w),d3
				move.w	d3,a3

				move.l	d4,d0
				add.l	d6,d0
				move.l	d5,d1
				add.l	d7,d1
				
				PlotPixelStart
				move.l	a1,a2
				add.l	#$8000,a2
				and.w	d3,(a2)
				;move.w	#ColorPixelWhite,d3
				move.w	a3,d3
                ror.w   d2,d3
                or.w    d3,(a1)
                or.w    d3,(a2)
.NoAdd:
				dbra	d6,.LoopX
				dbra	d7,.LoopY
				
				rts

;=============================================================================
; Process bob shading
;=============================================================================
ProcessBobShading:
				lea		Current_Bob(pc),a0
				move.l	(a0),a0
				bsr		AddOneBob

				lea		Current_Bob(pc),a0
				move.l	4(a0),a0
				bsr		AddOneBob
				
				lea		NbLoop(pc),a0
				cmp.l	#300,(a0)
				beq.s	.StartNextBob

				lea		NbLoop(pc),a0
				cmp.l	#600,(a0)
				beq.s	.EndBob

				rts
				
.StartNextBob:
				lea		Current_Bob(pc),a0
				lea		Bob_01(pc),a1
				move.l	a1,(a0)
				lea		Bob_02(pc),a1
				move.l	a1,4(a0)
				
				bsr		ProcessEraseScreen
				rts
.EndBob:
				bsr		StartOutro
				rts

;=============================================================================
; Start Fire Effect
;=============================================================================
StartFireEffect:
				bsr		ProcessEraseScreen

				lea		Fireplace(pc),a0
				lea		$20000+128,a1
				bsr		zx0_decompress

				lea		Fireplace(pc),a0
				lea		$28000+128,a1
				bsr		zx0_decompress

				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_FIRE,(a0)

				lea     NbVbl(pc),a1
				move.l	#0,(a1)
				lea     NbLoop(pc),a1
				move.l	#0,(a1)

				;bsr		DeactivateSwapBuffer

; Fill for buffer with only one line at the bottom
				lea		BufferData(pc),a0
				move.l	#FIRE_EFFECT_SIZE_Y-1-1,d7
.LoopY:				
				move.l	#FIRE_EFFECT_SIZE_X-1,d6
.LoopX:
				move.b	#0,(a0)+
				dbra	d6,.LoopX
				dbra	d7,.LoopY

				move.l	#FIRE_EFFECT_SIZE_X*2-1,d6
.LoopXLastLine:
				move.b	#126,(a0)+						; Direclty multiplied by 2 for .w LUT colot access
				dbra	d6,.LoopXLastLine

; Create speudo random for sub and displacement
 ;DBGBREAK
				lea		BufferData(pc),a0
				add.l	#FIRE_EFFECT_SIZE_Y*FIRE_EFFECT_SIZE_X,a0
				move.l	#FIRE_EFFECT_RANDOM_SIZE-1,d7
.LoopRandom:
				bsr		GetRandom
				and.l	#3,d0
				lsl.l	#1,d0
				move.b	d0,(a0)+						; Sub value for dot fire
				dbra	d7,.LoopRandom

				lea		CurrentBurnText(pc),a0
				lea		Burn_Text(pc),a1
				move.l	a1,(a0)
				
				lea		BurnTextTimer(pc),a0
				move.l	#0,(a0)
				
				rts

FIRE_EFFECT_SIZE_X		equ		(4*42)/4
FIRE_EFFECT_SIZE_Y		equ		64
FIRE_EFFECT_RANDOM_SIZE	equ		1024+FIRE_EFFECT_SIZE_X*FIRE_EFFECT_SIZE_Y
FIRE_DECAL_POS_Y		equ		108

B13 equ (B1|B3)
B0123 equ (B0|B1|B2|B3)
B02R13 equ (B0|B2|R1|R3)
R0123 equ (R0|R1|R2|R3)
R02B13R13 equ (R0|R2|B1|B3|R1|R3)
R0123B0123 equ (R0123|B0123)
R02B02G13 equ (R0|R2|B0|B2|G1|G3)
G0123 equ (G0|G1|G2|G3)
G02B13G13 equ (G0|G2|B1|B3|G1|G3)
R02G13R13 equ (R0|R2|G1|G3|R1|R3)
G0123R0123 equ (G0123|R0123)
G02R02B13G13R13 equ (G0|G2|R0|R2|B1|B3|G1|G3|R1|R3)
B0123G0123R0123 equ (B0123|G0123|R0123)

FireColorLUT:
;Black
	dc.w		0,0,0,0,0,0,0,0
;Black->Blue
	dc.w		B13,B13,B13,B13,B13,B13,B13
;Blue
	dc.w		B0123,B0123,B0123,B0123,B0123,B0123,B0123
;Blue->Red
	dc.w		B02R13,B02R13,B02R13,B02R13,B02R13,B02R13,B02R13
;Red
	dc.w		R0123,R0123,R0123,R0123,R0123,R0123,R0123
;Red->Yellow
	dc.w		R02G13R13,R02G13R13,R02G13R13,R02G13R13,R02G13R13,R02G13R13,R02G13R13
;Yellow
	dc.w		G0123R0123,G0123R0123,G0123R0123,G0123R0123,G0123R0123,G0123R0123,G0123R0123
;Yellow->White
	dc.w		G02R02B13G13R13,G02R02B13G13R13,G02R02B13G13R13,G02R02B13G13R13,G02R02B13G13R13,G02R02B13G13R13,G02R02B13G13R13
;White
	dc.w		B0123G0123R0123,B0123G0123R0123,B0123G0123R0123,B0123G0123R0123,B0123G0123R0123,B0123G0123R0123,B0123G0123R0123

FireSeed:	dc.l		$12345678



;=============================================================================
; Process Fire Effect
;=============================================================================

 macro DoOneFireDot
				move.b	(a3)+,d1
				move.b	FIRE_EFFECT_SIZE_X(a0),d0
				sub.b	d1,d0
				bcc.s	.NotNeg\@
				moveq	#0,d0
.NotNeg\@:
				move.b	d0,(a0)+
				move.w	(a1,d0.w),(a2)+

 endm
 
ProcessFireEffect:
; Process fire
				lea		BurnTextTimer(pc),a0
				lea		VblNbFrameLastLoopSaved(pc),a1
				move.l	(a1),d0
				add.l	d0,(a0)

				move.l	ScreenBase(pc),a2
				add.l	#64-FIRE_EFFECT_SIZE_X,a2
				add.l	#128*FIRE_DECAL_POS_Y,a2
				move.l	NbLoop(pc),d0
				btst	#1,d0
				beq.s	.NoAdd
				add.l	#128,a2
.NoAdd:

				lea		FireColorLUT(pc),a1
				lea		BufferData(pc),a0

				lea		BufferData(pc),a3
				add.l	#FIRE_EFFECT_SIZE_Y*FIRE_EFFECT_SIZE_X,a3		; Random precalc table
				
				lea		FireSeed(pc),a4
				move.l	(a4),d0
				add.l	#134,d0
				and.l	#1023,d0
				move.l	d0,(a4)
				add.l	d0,a3

				moveq	#0,d0

				move.l	#FIRE_EFFECT_SIZE_Y-1-1,d7
.LoopY:				
			rept FIRE_EFFECT_SIZE_X
				DoOneFireDot
			endr

				lea		(128-FIRE_EFFECT_SIZE_X*2+128)(a2),a2
				dbra	d7,.LoopY

				bsr		DisplayBigRPUFOS
				bsr		AddRPUFOSToBurn
				rts

Burn_Text:
					dc.b	1,24,1
					dc.b	" "
					dc.b	1,24,1
					dc.b	" "
					
					dc.b	3,22,11
					dc.b	"EKO"

					dc.b	2,28,14
					dc.b	"IS"

					dc.b	4,14,7
					dc.b	"BACK"

					dc.b	3,22,11
					dc.b	"FOR"

					dc.b	3,22,11
					dc.b	"THE"

					dc.b	6,0,0
					dc.b	"RPUFOS"

					dc.b	4,14,7
					dc.b	"2026"

					dc.b	3,22,11
					dc.b	"JAM"

					dc.b	2,28,14
					dc.b	"ON"

					dc.b	2,28,14
					dc.b	"QL"
					dc.b	0
	even
CurrentBurnText:	dc.l	0		; Adr 
BurnTextTimer:		dc.l	0
	
;=============================================================================
AddRPUFOSToBurn:
; Add things into the fire
				move.l	BurnTextTimer(pc),d0
				cmp.l	#150,d0
				bmi		.AddNothing

				lea		BufferData(pc),a0
				add.l	#FIRE_EFFECT_SIZE_X*32+1,a0
				
				lea		CurrentBurnText(pc),a2
				move.l	(a2),a2
				tst.b	(a2)
				bne.s	.NotEndOfBurnText
				beq		StartLogoRetroProg
				rts
.NotEndOfBurnText:
				moveq	#0,d7
				move.b	(a2),d7
				moveq	#0,d0
				move.b	2(a2),d0
				add.l	d0,a0
				add.l	#3,a2
				sub.b	#1,d7
.LoopLetters:
				move.l	#5-1,d6
				moveq	#0,d4
				move.b	(a2)+,d4
				cmp.b	#" ",d4
				beq.s	.GoToNext
				sub.w	#48,d4			; "0"
				cmp.w	#10,d4
				bmi.s	.Number
				sub.w	#(65-48)-10,d4			; "A" just after "9" in our "font"
.Number:
				lsl.w	#5,d4
				lea		Font5x5(pc),a1
				add.w	d4,a1
.LoopLines:
				move.l	#5-1,d5
.LoopCol:
				move.b	(a1)+,d0
				beq.s	.NoSet
				move.b	d0,FIRE_EFFECT_SIZE_X(a0)
				move.b	d0,(a0)
.NoSet:
				add.l	#1,a0
				dbra	d5,.LoopCol

				add.l	#FIRE_EFFECT_SIZE_X*2-5,a0
				dbra	d6,.LoopLines

				sub.l	#FIRE_EFFECT_SIZE_X*2*5-5,a0
				add.l	#2,a0
				dbra	d7,.LoopLetters
				
.GoToNext:
				lea		CurrentBurnText(pc),a0
				move.l	a2,(a0)
				lea	BurnTextTimer(pc),a0
				move.l	#0,(a0)

.AddNothing:
				rts

;=============================================================================
DisplayBigRPUFOS:
				move.l	BurnTextTimer(pc),d0
				cmp.l	#50,d0
				bmi		.AddNothing
				cmp.l	#150,d0
				bge		.AddNothing

; Add things into the fire
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				add.l	#128*(FIRE_DECAL_POS_Y+64)+24,a0
				lea		Font5x5(pc),a1
				
				lea		CurrentBurnText(pc),a2
				move.l	(a2),a2
				tst.b	(a2)
				bne.s	.NotEndOfBurnText
				rts
.NotEndOfBurnText:
				moveq	#0,d7
				move.b	(a2),d7
				moveq	#0,d0
				move.b	1(a2),d0
				add.l	d0,a0
				add.l	#3,a2
				sub.b	#1,d7
.LoopLetters:
				moveq	#0,d4
				move.b	(a2)+,d4
				cmp.b	#" ",d4
				beq		.AddNothing
				sub.w	#48,d4			; "0"
				cmp.w	#10,d4
				bmi.s	.Number
				sub.w	#(65-48)-10,d4			; "A" just after "9" in our "font"
.Number:
				lsl.w	#5,d4
				lea		Font5x5(pc),a1
				add.w	d4,a1

				move.l	#5-1,d6
.LoopLines:
				move.l	#5-1,d5
.LoopCol:
				move.b	(a1)+,d0
				beq.s	.NoSet
				move.w	#$AAFF,128*0(a0)
				move.w	#$AAFF,128*1(a0)
				move.w	#$AAFF,128*2(a0)
				move.w	#$AAFF,128*3(a0)
.NoSet:
				add.l	#2,a0
				dbra	d5,.LoopCol
				
				add.l	#128*4-5*2,a0
				dbra	d6,.LoopLines

				sub.l	#128*4*5,a0
				add.l	#14,a0
				dbra	d7,.LoopLetters
.AddNothing:
				rts
			
;=============================================================================
; Start outro
;=============================================================================
StartOutro:
				bsr		ProcessEraseScreen

				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_OUTRO_01,(a0)

				lea     NbVbl(pc),a1
				move.l	#0,(a1)
				lea     NbLoop(pc),a1
				move.l	#0,(a1)

				lea		Outro01(pc),a0
				lea		$20000,a1
				bsr		zx0_decompress

				lea		$20000+128,a0
				lea		$28000+128,a1
				bsr		CopyScreenMinusOneLine

				lea		Outro02(pc),a0
				lea		BufferData32k(pc),a1
				bsr		zx0_decompress
				rts

;=============================================================================
; Start Chara falling phase
;=============================================================================
StartCharaFalling:
				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_OUTRO_FALLING,(a0)

				lea     NbVbl(pc),a1
				move.l	#0,(a1)
				lea     NbLoop(pc),a1
				move.l	#0,(a1)

				lea		BufferData32k(pc),a1
				add.l	#108/2+80*128,a1

				move.l	#32-1,d7
.LoopClearChara:
			rept 5
				move.l  #$0,(a1)+
			endr
				lea		(128-4*5)(a1),a1
				dbra	d7,.LoopClearChara

				lea		BufferData32k(pc),a0
				lea		$20000,a1
				bsr		CopyScreen

				lea		BufferData32k(pc),a0
				add.l	#128,a0
				lea		$28000+128,a1
				bsr		CopyScreenMinusOneLine

				rts

;=============================================================================
; Start 3D after chara falling phase
;=============================================================================
Start3D:
				lea		DemoStatus(pc),a0
				move.l	#STATUS_DEMO_OUTRO_3D,(a0)

				lea		Projected(pc),a1
				lea		Projected1(pc),a2
				move.l	a2,(a1)
                bsr     RotateAndProject

				rts
				
;=============================================================================
; Chara falling phase
;=============================================================================
CharaFalling:

; Grow Rainbow
				lea		RainbowPos(pc),a5
				lea		ScreenBase(pc),a4
				move.l	(a4),a4

SPEED_RAINBOW	equ 64
SPEED_CHARA		equ 128
				
	macro DrawRainbow
				move.l	#\5,d0
				move.l	\2(a5),d1
				cmp.l	#255*2,\2(a5)
				bmi.s	.NoSub\@
				sub.l	#SPEED_RAINBOW,\2(a5)
.NoSub\@:
				lsr.l	#8,d1
			rept 6
				bsr		PlotPixel\1
				add.l	#1,d0
			endr

				move.l	#\5,d0
				move.l	\3(a5),d1
				cmp.l	#\4*255,\3(a5)
				bge.s	.NoAdd\@
				add.l	#SPEED_RAINBOW,\3(a5)
.NoAdd\@:
				lsr.l	#8,d1
			rept 6
				bsr		PlotPixel\1
				add.l	#1,d0
			endr
	endm
	
				DrawRainbow <Blue>, <0>, <24>, <125>, <111>
				DrawRainbow <Cyan>, <4>, <28>, <120>, <111+6>
				DrawRainbow <Green>, <8>, <32>, <115>, <111+6*2>
				DrawRainbow <Yellow>, <12>, <36>, <110>, <111+6*3>
				DrawRainbow <Magenta>, <16>, <40>, <115>, <111+6*4>
				DrawRainbow <Red>, <20>, <44>, <120>, <111+6*5>

; Chara falling
				lea     NbLoop(pc),a4
				lea		ScreenBase(pc),a0
				move.l	(a0),a0

				lea		OlipixChara(pc),a1
				lea		CharaPos(pc),a5
				move.l	#112,d0
				move.l	(a5),d1
				add.l	#SPEED_CHARA,(a5)
				lsr.l	#8,d1
				move.l	d1,d4

				cmp.l	#255,d4
				bge.s	.EndCharaFalling
				
				lea		BufferData32k(pc),a3
				cmp.l	#0,(a4)
				bne.s	.NotFirstChara
				move.l	a0,a3
.NotFirstChara:
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen

				add.l	d1,a3
				add.l	d0,a3
						
				move.l	a1,a2
				lea		512(a2),a2		; a2 = mask

				move.w  #128-32/2,d1
                
				move.l	#32-1,d7
.LoopSpr32:
				cmp.l	#255,d4
				bge.s	.EndLoopSpr
				add.l	#1,d4
			rept 4
				move.l  (a3)+,d0
				and.l   (a2)+,d0
				or.l    (a1)+,d0
				move.l  d0,(a0)+
			endr
				adda.w  d1,a0
				adda.w  d1,a3

				dbra	d7,.LoopSpr32
.EndLoopSpr:
				rts

.EndCharaFalling:
				bsr		Start3D
				rts
				
;=============================================================================
; Draw red lines
;=============================================================================
DrawRedLine:
; Lines "scroll"
				lea     NbLoop(pc),a4
				lea		TableLinePos(pc),a5
				lea		ScreenBase(pc),a2
				move.l	(a2),a2
				add.l	#128*128,a2

				move.l	#$00AA00AA,d0
				move.l	#$FF55FF55,d1

				move.l	#0,d3
				move.l	#6-1,d2			; 6 Lines
.LoopLine:
				move.l	(a4),d7
				add.l	d3,d7

				move.l	d7,d5
				sub.l	#2,d5
				and.l	#127,d7
				lsl.l	#1,d7
				and.l	#127,d5
				lsl.l	#1,d5			; Coord of current frame and frame n-2 (double buffer)
				
				moveq	#0,d6
				move.w	(a5,d7.w),d6
				moveq	#0,d4
				move.w	(a5,d5.w),d4	; Get the coord from table

				move.l	a2,a0
				lsl.l	#7,d6
				add.l	d6,a0			; New line adr
				
				move.l	a2,a1
				lsl.l	#7,d4
				add.l	d4,a1			; Prev line adr (n-2)
				
			rept	32
				and.l	d1,(a1)+		; Erase red bits
				or.l	d0,(a0)+		; Write red bits
			endr

				add.l	#128/6,d3
				dbra	d2,.LoopLine
				
				rts

	even
CharaPos:
	dc.l	80*256

RainbowPos:
	dc.l	16*256, 16*256, 16*256, 16*256, 16*256, 16*256
	dc.l	72*256, 72*256, 72*256, 72*256, 72*256, 72*256

TableLinePos:
	dc.w   0,   0,   0,   0,   0,   0,   0,   1
    dc.w   1,   1,   1,   1,   1,   1,   1,   1
    dc.w   2,   2,   2,   2,   2,   2,   2,   3
    dc.w   3,   3,   3,   3,   3,   4,   4,   4
    dc.w   4,   4,   5,   5,   5,   5,   6,   6
    dc.w   6,   6,   7,   7,   7,   7,   8,   8
    dc.w   8,   9,   9,  10,  10,  10,  11,  11
    dc.w  12,  12,  12,  13,  13,  14,  14,  15
    dc.w  16,  16,  17,  17,  18,  19,  19,  20
    dc.w  21,  21,  22,  23,  24,  25,  25,  26
    dc.w  27,  28,  29,  30,  31,  32,  33,  35
    dc.w  36,  37,  38,  40,  41,  42,  44,  45
    dc.w  47,  48,  50,  52,  53,  55,  57,  59
    dc.w  61,  63,  65,  67,  69,  72,  74,  76
    dc.w  79,  82,  84,  87,  90,  93,  96,  99
    dc.w 102, 106, 109, 113, 116, 120, 124, 126
	even


ReplaceXOffset:		dc.l	16
ReplaceYOffset:		dc.l	16
	
;=============================================================================
; Replace outro 01 with outro 02 overtime
;=============================================================================
ReplaceOutroImage:
				lea     NbVbl(pc),a4
				move.l	(a4),d7
				
				cmp.l	#50,d7
				bmi		.EndReplaceOutroImage

				and.l	#3,d7
				bne		.EndReplaceOutroImage

				move.l	#$20000,a0
				move.l	#$28000,a1
				lea		BufferData32k(pc),a2

				lea		ReplaceXOffset(pc),a3
				move.l	(a3),d0
				lea		ReplaceYOffset(pc),a4
				move.l	(a4),d1

				lsr.l	#1,d0					; /2 for X offset
				lsl.l	#7,d1					; * 128 for Y offset
				add.l	d1,d0
				add.l	d0,a0
				add.l	d0,a1
				add.l	d0,a2
				
				moveq	#16-1,d7				; Nb line
.LoopYReplace:
				moveq	#32/4/2-1,d6			; Nb Words
.LoopXReplace:
				move.l	(a2),(a0)+
				move.l	(a2)+,(a1)+
				dbra	d6,.LoopXReplace
				
				lea		(128-32/2)(a0),a0
				lea		(128-32/2)(a1),a1
				lea		(128-32/2)(a2),a2
				dbra	d7,.LoopYReplace

				move.l	(a3),d0
				add.l	#32,d0
				cmp.l	#224,d0
				bmi.s	.NotANewLine

				move.l	#16,d0
				add.l	#16,(a4)
				cmp.l	#224,(a4)
				bhi.s	.StopReplaceOutroImage
.NotANewLine:
				move.l	d0,(a3)
.EndReplaceOutroImage:
				rts
.StopReplaceOutroImage:

				bsr		StartCharaFalling
				rts

;=============================================================================
; Outro around effect
;=============================================================================

TableAroundEffect:
	dc.w	3,2,4,2,3,4,2,3,2,3,4,3,2,3,4,3
	dc.w	4,2,3,4,2,3,4,2,3,4,2,3,4,2,3,4
	dc.w	5,4,2,3,4,5,2,3,5,4,5,2,3,5,4,2
	dc.w	2,2,4,5,2,3,2,4,2,3,2,4,2,3,4,2
	dc.w	3,2,3,4,3,2,3,4,3,4,2,3,4,2,3,4
	dc.w	2,3,4,2,3,4,2,3,4,5,4,2,3,4,5,2
	dc.w	3,5,4,5,2,3,5,4,2,2,4,2,4,5,2,3
	dc.w	3,2,3,4,3,2,3,4,3,4,2,3,4,2,3,4

; https://youtu.be/qc4H21jJt6Q?t=1881
	
COLOR_BLUE_LONG		equ		$00550055
COLOR_GREEN_LONG	equ		$AA00AA00

OutroAroundEffect:
				lea		ScreenBase(pc),a6
				move.l	(a6),a6
				add.l	#128*(256-8),a6

				lea     NbVbl(pc),a4
				move.l	(a4),d7
				
				and.l	#7,d7
				lsl.l	#7,d7
				add.l	d7,a6

				lea		TableAroundEffect(pc),a5

				move.l	#COLOR_BLUE_LONG,d0
				move.l	#COLOR_BLUE_LONG,d1
				move.l	#COLOR_BLUE_LONG,d2
				move.l	#COLOR_BLUE_LONG,d3
				move.l	#COLOR_GREEN_LONG,d4
				move.l	#COLOR_GREEN_LONG,d5
				move.l	#COLOR_GREEN_LONG,d6
				move.l	#COLOR_GREEN_LONG,a0

; Bottom full lines
				moveq	#0,d7
				move.w	(a5)+,d7
				sub.w	#1,d7
.L1:
			rept 2
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
			endr
				dbra	d7,.L1

				move.w	(a5)+,d7
				sub.w	#1,d7
.L2:
			rept 2
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
			endr
				dbra	d7,.L2

				move.w	(a5)+,d7
				sub.w	#1,d7
.L3:
			rept 2
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
			endr
				dbra	d7,.L3

				move.w	(a5)+,d7
				sub.w	#1,d7
.L4:
			rept 2
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
			endr
				dbra	d7,.L4

	macro	BlueBorderLine
				move.w	(a5)+,d7
				sub.w	#1,d7
	.loop\@:
				movem.l	d0-d1,-(a6)
				lea		-(128-16)(a6),a6
				movem.l	d0-d1,-(a6)
				dbra	d7,.loop\@
	endm

	macro	GreenBorderLine
				move.w	(a5)+,d7
				sub.w	#1,d7
	.loop\@:
				movem.l	d4-d5,-(a6)
				lea		-(128-16)(a6),a6
				movem.l	d4-d5,-(a6)
				dbra	d7,.loop\@
	endm

; Border lines
		rept 36
			BlueBorderLine
			GreenBorderLine
		endr
		
; Up lines
				move.w	(a5)+,d7
				sub.w	#1,d7
.L1u:
			rept 2
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
			endr
				dbra	d7,.L1u

				move.w	(a5)+,d7
				sub.w	#1,d7
.L2u:
			rept 2
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
			endr
				dbra	d7,.L2u

				move.w	(a5)+,d7
				sub.w	#1,d7
.L3u:
			rept 2
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
				movem.l	d0-d3,-(a6)
			endr
				dbra	d7,.L3u

				rts
				move.w	(a5)+,d7
				sub.w	#1,d7
.L4u:
			rept 2
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
				movem.l	d4-d6/a0,-(a6)
			endr
				dbra	d7,.L4u
				
				rts
				
				
;=============================================================================
; Image deformation test
;=============================================================================
ImageDeformationTest:
	if 0
				lea		ScreenBase(pc),a6
				move.l	(a6),a6
				add.l	#128/2-128/2/2,a6

				lea     NbLoop(pc),a1
				move.l	(a1),d0
				and.l	#1023,d0
				;lsl.l	#1,d0

				lea		TableSpeSin(pc),a5
				moveq	#0,d7

				lea		Demo01(pc),a0
				;DBGBREAK
				
			rept 128
				add.w	#2,d0
				and.w	#1023,d0
				moveq	#0,d7
				move.b	(a5,d0.w),d7
				ext.l	d7
				;asr.l	#3,d7			; -32 to 32
				move.l	d7,d6
				asr.l	#2,d7			; 4 pixels / word
				add.l	d7,d7
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
	endif

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
	even

TableSin256: ; 256 value, from -255 to 255
	dc.w    0, 6, 13, 19, 25, 31, 37, 44, 50, 56, 62, 68, 74, 80, 86, 92
	dc.w    98, 103, 109, 115, 120, 126, 131, 136, 142, 147, 152, 157, 162, 167, 171, 176
	dc.w    180, 185, 189, 193, 197, 201, 205, 208, 212, 215, 219, 222, 225, 228, 231, 233
	dc.w    236, 238, 241, 243, 245, 247, 248, 250, 251, 253, 254, 254, 255, 255, 255, 255
	dc.w    255, 255, 255, 255, 254, 254, 253, 251, 250, 248, 247, 245, 243, 241, 238, 236
	dc.w    233, 231, 228, 225, 222, 219, 215, 212, 208, 205, 201, 197, 193, 189, 185, 180
	dc.w    176, 171, 167, 162, 157, 152, 147, 142, 136, 131, 126, 120, 115, 109, 103, 98
	dc.w    92, 86, 80, 74, 68, 62, 56, 50, 44, 37, 31, 25, 19, 13, 6, 0
	dc.w    0, -6, -13, -19, -25, -31, -37, -44, -50, -56, -62, -68, -74, -80, -86, -92
	dc.w    -98, -103, -109, -115, -120, -126, -131, -136, -142, -147, -152, -157, -162, -167, -171, -176
	dc.w    -180, -185, -189, -193, -197, -201, -205, -208, -212, -215, -219, -222, -225, -228, -231, -233
	dc.w    -236, -238, -241, -243, -245, -247, -248, -250, -251, -253, -254, -254, -255, -255, -255, -255
	dc.w    -255, -255, -255, -255, -254, -254, -253, -251, -250, -248, -247, -245, -243, -241, -238, -236
	dc.w    -233, -231, -228, -225, -222, -219, -215, -212, -208, -205, -201, -197, -193, -189, -185, -180
	dc.w    -176, -171, -167, -162, -157, -152, -147, -142, -136, -131, -126, -120, -115, -109, -103, -98
	dc.w    -92, -86, -80, -74, -68, -62, -56, -50, -44, -37, -31, -25, -19, -13, -6, 0
	even

sin_table_8_232:
    ; 0° à 90° (0 à 127)
    dc.b 120,121,123,124,125,127,128,130,131,132,134,135,136,138,139,140
    dc.b 142,143,145,146,147,149,150,151,153,154,155,157,158,159,160,162
    dc.b 163,164,165,167,168,169,170,172,173,174,175,176,178,179,180,181
    dc.b 182,183,185,186,187,188,189,190,191,192,193,194,195,196,197,198
    dc.b 199,200,201,202,203,204,205,206,207,208,209,209,210,211,212,213
    dc.b 213,214,215,216,216,217,218,218,219,220,220,221,222,222,223,223
    dc.b 223,224,224,225,225,226,226,227,227,228,228,228,229,229,229,230
    dc.b 230,230,230,231,231,231,231,232,232,232,232,232,232,232,232,232

    ; 90° à 180° (128 à 255)
    dc.b 232,232,232,232,232,232,232,232,232,231,231,231,231,230,230,230
    dc.b 230,229,229,229,228,228,228,227,227,226,226,225,225,224,224,223
    dc.b 223,223,222,222,221,220,220,219,218,218,217,216,216,215,214,213
    dc.b 213,212,211,210,209,209,208,207,206,205,204,203,202,201,200,199
    dc.b 198,197,196,195,194,193,192,191,190,189,188,187,186,185,183,182
    dc.b 181,180,179,178,176,175,174,173,172,170,169,168,167,165,164,163
    dc.b 162,160,159,158,157,155,154,153,151,150,149,147,146,145,143,142
    dc.b 140,139,138,136,135,134,132,131,130,128,127,125,124,123,121,120

    ; 180° à 270° (256 à 383)
    dc.b 120,119,117,116,115,113,112,110,109,108,106,105,104,102,101,100
    dc.b 98,97,95,94,93,91,90,89,87,86,85,83,82,81,80,78
    dc.b 77,76,75,73,72,71,70,68,67,66,65,64,62,61,60,59
    dc.b 58,57,55,54,53,52,51,50,49,48,47,46,45,44,43,42
    dc.b 41,40,39,38,37,36,35,34,33,32,31,31,30,29,28,27
    dc.b 27,26,25,24,24,23,22,22,21,20,20,19,18,18,17,17
    dc.b 17,16,16,15,15,14,14,13,13,12,12,12,11,11,11,10
    dc.b 10,10,10,9,9,9,9,8,8,8,8,8,8,8,8,8

    ; 270° à 360° (384 à 511)
    dc.b 8,8,8,8,8,8,8,8,8,9,9,9,9,10,10,10
    dc.b 10,11,11,11,12,12,12,13,13,14,14,15,15,16,16,17
    dc.b 17,17,18,18,19,20,20,21,22,22,23,24,24,25,26,27
    dc.b 27,28,29,30,31,31,32,33,34,35,36,37,38,39,40,41
    dc.b 42,43,44,45,46,47,48,49,50,51,52,53,54,55,57,58
    dc.b 59,60,61,62,64,65,66,67,68,70,71,72,73,75,76,77
    dc.b 78,80,81,82,83,85,86,87,89,90,91,93,94,95,97,98
    dc.b 100,101,102,104,105,106,108,109,110,112,113,115,116,117,119,120
	

	even
Font:						incbin 		"Data\Font8x8.bin"
	even
Outro02:					incbin 		"Data\Demo\Outro_02.bin.zx0"
	even
OlipixChara:				incbin 		"Data\Demo\Olipix_Chara.bin"
	even
; Here start the 32K buffer for effects
BufferData32k:
LogoRetroProg:				incbin 		"Data\Demo\LogoRPUFOS.bin.zx0"
	even
LogoEko:					incbin 		"Data\Demo\LogoEko.bin.zx0"
	even
Fireplace:					incbin 		"Data\Demo\FirePlace.bin.zx0"
	even
Outro01:					incbin 		"Data\Demo\Outro_01.bin.zx0"
	even
Font5x5:
	include "Font5x5.asm"
	even
BufferData:
		dcb.b				32*1024-(BufferData-LogoRetroProg),0
BufferDataEnd:

SIZE_BUFFER_DATA equ (BufferDataEnd-BufferData)
		

MIN_SIZE        equ 16*1024

                iflt SIZE_BUFFER_DATA-MIN_SIZE
                fail "Error, buffer data is too small !!!"
				printt "BufferData size is : "
				printv SIZE_BUFFER_DATA
                endc
