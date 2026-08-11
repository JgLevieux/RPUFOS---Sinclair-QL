	even
	include "macros.asm"
	even
; =============================================================================
DOUBLE_BUFFERING	equ		1

;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000

; =============================================================================
Start:
				DBGENABLE
			; Remove QDOS, mainly for double buffering as second screen adress contain QDOS data
                trap    #0              			; Call QDOS for Superviseur mode
                ori.w   #$0700,sr       			; All hardware interrupt off.
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
				move.w	#$2700,sr					; Supervisor mode & no interrupt
				lea		VBLRouterList(pc),a0
				lea		VBLInterrupt(pc),a1
				move.l	a1,4(a0)					; Function to be called each frame.
				move.l	a0,$2803c					; write VBLANK pointer to JSROM location
				move.w	#$2100,sr					; Enable interrupts for Vbl, keyboard & sound (as well as microdrive & rs232)
				; TODO - Specific code for minerva support

			; Frame counter (real display)
				lea     NbLoop(pc),a0
                move.l  #0,(a0)
				lea     NbVbl(pc),a0
                move.l  #0,(a0)
				;bsr		StartOutro
				;bsr		StartCharaFalling

				lea		Music_OdeALaJoie(pc),a0
				bsr		StartMusic
				
MainLoop:
			; WaitVBlank
				bsr		WaitVBlank
				;bra		MainLoop

			ifd TIMER_MODE
				move.b	#ScreenMode01,$18063			; Display screen 1
			endif

				bsr		SwapBuffer

				bsr		DrawVblTimer
				
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

				cmp.l	#STATUS_DEMO_OUTRO_01,d0
				beq.s   .CaseOutro01

				cmp.l	#STATUS_DEMO_OUTRO_02,d0
				beq.s   .CaseOutro02
				
				cmp.l	#STATUS_DEMO_OUTRO_FALLING,d0
				beq.s   .CaseOutroFalling

				cmp.l	#STATUS_DEMO_PLASMA_EFFECT,d0
				beq.s   .CasePlasma
				
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
				;bsr		OutroAroundEffect
				bsr		CharaFalling
				bra.s   .EndSwitch
				
.CasePlasma:
				bsr		PlasmaEffect
				bra.s   .EndSwitch
				nop

.EndSwitch:				

			ifd TIMER_MODE
				DisplayOffForProfiling
			endif
			
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

	even
DemoStatus:			dc.l	STATUS_DEMO_PLASMA_EFFECT
ReplaceXOffset:		dc.l	16
ReplaceYOffset:		dc.l	16

;=============================================================================
; Start outro
;=============================================================================
PlasmaEffect:
				lea		ScreenBase(pc),a4
				move.l	(a4),a4
				add.l	#32+128,a4
				
				lea		SinTable512(pc),a3
				lea		ColorLUT(pc),a2			; Color in table
				
				lea		NbLoop(pc),a1
				move.l	(a1),d5
				lsl.l	#1,d5					; Speed *2
				and.w	#$FF,d5					; Keep under 256
				
				btst	#2,d5
				beq.s	.NoDecal
				;DBGBREAK
				add.w	#256,a4
.NoDecal:				
				lea     NbLoop(pc),a0
				move.l	(a0),d7
				;and.l	#63,d7
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
				;move.l	d1,126+128(a4)
				;move.w	d1,128*3(a4)
				;add.w	#2,a4
				
				subq.w	#4,d6
				bne.s	.LoopX
				
				lea		128*4-64(a4),a4
				dbra	d7,.LoopY

 				lea		NbVbl(pc),a1
				cmp.l	#50*5,(a1)
				bmi.s	.NoNextPart
				bsr		StartOutro
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

ColorLUT:
    ; --- Bloc 0 (Index 0 à 31) - Noir ---
    ; Aucun des bits 5, 6 ou 7 n'est à 1.
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000
    dc.l $00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000,$00000000

    ; --- Bloc 1 (Index 32 à 63) - Bleu ---
    ; Seul le bit 5 (valeur 32) est à 1.
    dc.l $00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055
    dc.l $00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055
    dc.l $00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055
    dc.l $00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055,$00550055

    ; --- Bloc 2 (Index 64 à 95) - Vert ---
    ; Seul le bit 6 (valeur 64) est à 1.
    dc.l $AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00
    dc.l $AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00
    dc.l $AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00
    dc.l $AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00,$AA00AA00

    ; --- Bloc 3 (Index 96 à 127) - Cyan (Vert + Bleu) ---
    ; Bits 5 et 6 sont à 1. ($AA00 | $0055 = $AA55)
    dc.l $AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55
    dc.l $AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55
    dc.l $AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55
    dc.l $AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55,$AA55AA55

    ; --- Bloc 4 (Index 128 à 159) - Rouge ---
    ; Seul le bit 7 (valeur 128) est à 1.
    dc.l $00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA
    dc.l $00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA
    dc.l $00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA
    dc.l $00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA,$00AA00AA

    ; --- Bloc 5 (Index 160 à 191) - Magenta (Rouge + Bleu) ---
    ; Bits 5 et 7 sont à 1. ($00AA | $0055 = $00FF)
    dc.l $00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF
    dc.l $00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF
    dc.l $00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF
    dc.l $00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF,$00FF00FF

    ; --- Bloc 6 (Index 192 à 223) - Jaune (Rouge + Vert) ---
    ; Bits 6 et 7 sont à 1. ($00AA | $AA00 = $AAAA)
    dc.l $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
    dc.l $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
    dc.l $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA
    dc.l $AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA,$AAAAAAAA

    ; --- Bloc 7 (Index 224 à 255) - Blanc (Rouge + Vert + Bleu) ---
    ; Bits 5, 6 et 7 sont à 1.
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF
    dc.l $AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF,$AAFFAAFF
	
;=============================================================================
; Start outro
;=============================================================================
StartOutro:
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
				lea		BufferData(pc),a1
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

				lea		BufferData(pc),a1
				add.l	#108/2+80*128,a1

				move.l	#32-1,d7
.LoopClearChara:
			rept 5
				move.l  #$0,(a1)+
			endr
				lea		(128-4*5)(a1),a1
				dbra	d7,.LoopClearChara

				lea		BufferData(pc),a0
				lea		$20000,a1
				bsr		CopyScreen

				lea		BufferData(pc),a0
				add.l	#128,a0
				lea		$28000+128,a1
				bsr		CopyScreenMinusOneLine

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
				
				lea		BufferData(pc),a3
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

; Lines "scroll"
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
				lea		BufferData(pc),a2

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
	;include "sinus.asm"
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

				bsr		PlayMusic
				
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
	even
							dcb.b	2048,0
TopOfStack:
	even

SinTable0_80:
    dc.b 42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57
    dc.b 58,59,60,61,62,63,64,65,66,66,67,68,69,70,71,71
    dc.b 72,73,73,74,75,76,76,77,77,78,78,79,79,80,80,81
    dc.b 81,82,82,82,83,83,83,83,84,84,84,84,84,84,84,84
    dc.b 85,84,84,84,84,84,84,84,84,83,83,83,83,82,82,82
    dc.b 81,81,80,80,79,79,78,78,77,77,76,76,75,74,73,73
    dc.b 72,71,71,70,69,68,67,66,66,65,64,63,62,61,60,59
    dc.b 58,57,56,55,54,53,52,51,50,49,48,47,46,45,44,43
    dc.b 42,41,40,39,38,37,36,35,34,33,32,31,30,29,28,27
    dc.b 26,25,24,23,22,21,20,19,18,18,17,16,15,14,13,13
    dc.b 12,11,11,10,9,8,8,7,7,6,6,5,5,4,4,3
    dc.b 3,2,2,2,1,1,1,1,0,0,0,0,0,0,0,0
    dc.b 0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,2
    dc.b 3,3,4,4,5,5,6,6,7,7,8,8,9,10,11,11
    dc.b 12,13,13,14,15,16,17,18,18,19,20,21,22,23,24,25
    dc.b 26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41
	even

TableSpeSin:
        DC.B 0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8
        DC.B 9,9,10,10,11,11,12,12,13,13,13,14,14,15,15,16
        DC.B 16,17,17,18,18,18,19,19,20,20,20,21,21,22,22,22
        DC.B 23,23,23,24,24,24,25,25,25,25,26,26,26,27,27,27
        DC.B 27,27,28,28,28,28,28,29,29,29,29,29,29,30,30,30
        DC.B 30,30,30,30,30,30,31,31,31,31,31,31,31,31,31,31
        DC.B 31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31
        DC.B 31,31,31,31,30,30,30,30,30,30,30,30,30,30,30,30
        DC.B 30,29,29,29,29,29,29,29,29,29,29,29,29,28,28,28
        DC.B 28,28,28,28,28,28,28,28,27,27,27,27,27,27,27,27
        DC.B 27,27,27,27,26,26,26,26,26,26,26,26,26,26,26,26
        DC.B 26,26,26,26,25,25,25,25,25,25,25,25,25,25,25,25
        DC.B 25,25,25,25,25,25,25,24,24,24,24,24,24,24,24,24
        DC.B 24,24,24,24,24,24,24,24,24,23,23,23,23,23,23,23
        DC.B 23,23,23,23,23,23,23,22,22,22,22,22,22,22,22,22
        DC.B 21,21,21,21,21,21,21,21,20,20,20,20,20,20,20,19
        DC.B 19,19,19,19,19,18,18,18,18,18,18,17,17,17,17,17
        DC.B 16,16,16,16,16,15,15,15,15,15,14,14,14,14,14,13
        DC.B 13,13,13,13,12,12,12,12,11,11,11,11,11,10,10,10
        DC.B 10,10,9,9,9,9,8,8,8,8,8,8,7,7,7,7
        DC.B 7,6,6,6,6,6,6,5,5,5,5,5,5,5,5,4
        DC.B 4,4,4,4,4,4,4,4,3,3,3,3,3,3,3,3
        DC.B 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        DC.B 3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4
        DC.B 4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5
        DC.B 5,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7
        DC.B 7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8
        DC.B 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
        DC.B 9,9,9,9,9,9,9,9,9,9,9,9,9,9,8,8
        DC.B 8,8,8,8,8,8,8,8,8,7,7,7,7,7,7,7
        DC.B 6,6,6,6,6,6,5,5,5,5,5,4,4,4,4,4
        DC.B 3,3,3,3,3,2,2,2,2,2,1,1,1,1,0,0
        DC.B 0,0,0,-1,-1,-1,-1,-2,-2,-2,-2,-2,-3,-3,-3,-3
        DC.B -3,-4,-4,-4,-4,-4,-5,-5,-5,-5,-5,-6,-6,-6,-6,-6
        DC.B -6,-7,-7,-7,-7,-7,-7,-7,-8,-8,-8,-8,-8,-8,-8,-8
        DC.B -8,-8,-8,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9
        DC.B -9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9,-9
        DC.B -9,-8,-8,-8,-8,-8,-8,-8,-8,-8,-8,-8,-8,-7,-7,-7
        DC.B -7,-7,-7,-7,-7,-7,-7,-6,-6,-6,-6,-6,-6,-6,-6,-6
        DC.B -5,-5,-5,-5,-5,-5,-5,-5,-5,-4,-4,-4,-4,-4,-4,-4
        DC.B -4,-4,-4,-4,-4,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3
        DC.B -3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3,-3
        DC.B -3,-3,-3,-3,-3,-3,-3,-3,-3,-4,-4,-4,-4,-4,-4,-4
        DC.B -4,-4,-5,-5,-5,-5,-5,-5,-5,-5,-6,-6,-6,-6,-6,-6
        DC.B -7,-7,-7,-7,-7,-8,-8,-8,-8,-8,-8,-9,-9,-9,-9,-10
        DC.B -10,-10,-10,-10,-11,-11,-11,-11,-11,-12,-12,-12,-12,-13,-13,-13
        DC.B -13,-13,-14,-14,-14,-14,-14,-15,-15,-15,-15,-15,-16,-16,-16,-16
        DC.B -16,-17,-17,-17,-17,-17,-18,-18,-18,-18,-18,-18,-19,-19,-19,-19
        DC.B -19,-19,-20,-20,-20,-20,-20,-20,-20,-21,-21,-21,-21,-21,-21,-21
        DC.B -21,-22,-22,-22,-22,-22,-22,-22,-22,-22,-23,-23,-23,-23,-23,-23
        DC.B -23,-23,-23,-23,-23,-23,-23,-23,-24,-24,-24,-24,-24,-24,-24,-24
        DC.B -24,-24,-24,-24,-24,-24,-24,-24,-24,-24,-25,-25,-25,-25,-25,-25
        DC.B -25,-25,-25,-25,-25,-25,-25,-25,-25,-25,-25,-25,-25,-26,-26,-26
        DC.B -26,-26,-26,-26,-26,-26,-26,-26,-26,-26,-26,-26,-26,-27,-27,-27
        DC.B -27,-27,-27,-27,-27,-27,-27,-27,-27,-28,-28,-28,-28,-28,-28,-28
        DC.B -28,-28,-28,-28,-29,-29,-29,-29,-29,-29,-29,-29,-29,-29,-29,-29
        DC.B -30,-30,-30,-30,-30,-30,-30,-30,-30,-30,-30,-30,-30,-31,-31,-31
        DC.B -31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31
        DC.B -31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-31,-30,-30,-30,-30,-30
        DC.B -30,-30,-30,-30,-29,-29,-29,-29,-29,-29,-28,-28,-28,-28,-28,-27
        DC.B -27,-27,-27,-27,-26,-26,-26,-25,-25,-25,-25,-24,-24,-24,-23,-23
        DC.B -23,-22,-22,-22,-21,-21,-20,-20,-20,-19,-19,-18,-18,-18,-17,-17
        DC.B -16,-16,-15,-15,-14,-14,-13,-13,-13,-12,-12,-11,-11,-10,-10,-9
        DC.B -9,-8,-7,-7,-6,-6,-5,-5,-4,-4,-3,-3,-2,-2,-1,-1

	
	
Font:						incbin 		"Data\Font8x8.bin"
	even
;LogoRetroProg:				incbin 		"Data\logo.bin.zx0"
	even
Outro01:					incbin 		"Data\Outro_01.bin.zx0"
	even
Outro02:					incbin 		"Data\Outro_02.bin.zx0"
	even
OlipixChara:				incbin 		"Data\Olipix_Chara.bin"
	even
Demo01:						;incbin 		"Data\Demo01.bin"
	even
BufferData:
		dcb.b				32*1024,0

