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

COL_INFO_NOTHING	equ		0
COL_INFO_WALL		equ		1
COL_INFO_TRACING	equ		2
COL_INFO_FILLING	equ		3
COL_INFO_WAY		equ		4
COL_INFO_WAS_A_WAY	equ		5

PLAYFIELD_START_X	equ		32
PLAYFIELD_START_Y	equ		48

NB_LIFE_START		equ		3
TIMER_START			equ		64

;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000


GAME_STATUS_MENU				equ		0
GAME_STATUS_GAME				equ		1
GAME_STATUS_GAMESTART			equ		2
GAME_STATUS_GAMELOOSELIFE		equ		3
GAME_STATUS_GAMEOVER			equ		10


; TODO :
; - Check if the player is not in a valid zone after a fill and set him at a safe place. OR DIE ?


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

				bsr		StartMenu
				;bsr		StartGame

MainLoop:
			; WaitVBlank
				bsr		WaitVBlank
				
			ifd TIMER_MODE
				move.b	#ScreenMode01,$18063			; Display screen 1
			endif

				bsr		SwapBuffer

				bsr 	ReadKeyboard

				lea		Keyboard(pc),a1

				btst	#Keyboard03_S,3(a1)
				beq.s	.NoKeyS
				bset	#Keyboard01_Down,1(a1)
.NoKeyS:
				btst	#Keyboard04_D,4(a1)
				beq.s	.NoKeyD
				bset	#Keyboard01_Right,1(a1)
.NoKeyD:
				btst	#Keyboard04_A,4(a1)
				beq.s	.NoKeyA
				bset	#Keyboard01_Left,1(a1)
.NoKeyA:
				btst	#Keyboard06_Q,6(a1)
				beq.s	.NoKeyQ
				bset	#Keyboard01_Left,1(a1)
.NoKeyQ:
				btst	#Keyboard05_W,5(a1)
				beq.s	.NoKeyW
				bset	#Keyboard01_Up,1(a1)
.NoKeyW:
				btst	#Keyboard02_Z,2(a1)
				beq.s	.NoKeyZ
				bset	#Keyboard01_Up,1(a1)
.NoKeyZ:

				btst	#Keyboard01_ESC,1(a1)
				beq.s	.NoESC
				bsr		DebugDisplayQLixColInfo
				;bsr		ResetQLix
.NoESC:

				lea     NbLoop(pc),a0
				add.l	#1,(a0)
				move.l	(a0),d6

				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Enter,d4		; Press space to move while tracing
				beq.s	.nobreakpoint
				;DBGBREAK
				
				bsr			SoundTest
				
				;bsr		ClearScreen
				;bsr		DebugDisplayQLixColInfo
				;bsr		PlayTune
.nobreakpoint:

				lea		GameMode(pc),a0
				move.l	(a0),d0

				cmp.l	#GAME_STATUS_MENU,d0
				beq.s   .CaseMenu

				cmp.l	#GAME_STATUS_GAMESTART,d0
				beq.s   .CaseGameStart
				
				cmp.l	#GAME_STATUS_GAME,d0
				beq.s   .CaseGame

				cmp.l	#GAME_STATUS_GAMELOOSELIFE,d0
				beq.s   .CaseGameLooseLife

				cmp.l	#GAME_STATUS_GAMEOVER,d0
				beq.s   .CaseGameOver
				
				bra.s   .EndSwitch

.CaseMenu:
				bsr		ProcessMenu
				bra.s   .EndSwitch
.CaseGameStart:
				bsr		ProcessGameStart
				bra.s   .EndSwitch
.CaseGame:
				bsr		ProcessGame
				bra.s   .EndSwitch
.CaseGameLooseLife:
				bsr		ProcessGameLooseLife
				bra.s   .EndSwitch
.CaseGameOver:
				bsr		ProcessGameOver
				bra.s   .EndSwitch
				nop
.EndSwitch:				

				bsr		DrawVblTimer

			ifd TIMER_MODE
				DisplayOffForProfiling
			endif
				bra		MainLoop

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
	include "Lines.asm"
	even
	include "sinus.asm"
;=============================================================================
	even
;=============================================================================
; Set Game Status
; d0 = GAME_STATUS_???
; Destroy a0
;=============================================================================
SetGameStatus:
				lea		GameMode(pc),a0
				move.l	d0,(a0)

				lea     NbLoop(pc),a0
                move.l  #0,(a0)
				
				lea		SpiraleBackBuffer(pc),a0
				move.l	#0,(a0)+
				rts
				
;=============================================================================
; Start Menu
;=============================================================================
StartMenu:
			ifd DOUBLE_BUFFERING				
				move.l	#$28000,a0
				bsr     ClearScreen
			endif
			
				move.l	#$20000,a0
				bsr     ClearScreen

				lea		QLixLogoCompressed(pc),a0
				lea		$20000,a1
				bsr		zx0_decompress

				lea		QLixLogoCompressed(pc),a0
				move.l	#$28000,a1
				bsr		zx0_decompress
				
				move.l	#GAME_STATUS_MENU,d0
				bsr		SetGameStatus

				lea		Text_Move(pc),a0
				move.l	#48,d0
				move.l	#8*12,d1
				bsr		DisplayText

				lea		Text_Trace(pc),a0
				move.l	#48,d0
				move.l	#8*15,d1
				bsr		DisplayText
				
				move.l	#48-24,d0
				move.l	#8*15+4,d1
				move.l	#48-8,d4
				move.l	#8*15+4,d5
				move.l	#ColorPixelRed,d6
				bsr		DrawLine

				lea		Text_AvoidEnnemies(pc),a0
				move.l	#48,d0
				move.l	#8*18,d1
				bsr		DisplayText

				lea		Text_AvoidQLix(pc),a0
				move.l	#48,d0
				move.l	#8*21,d1
				bsr		DisplayText

				lea		Text_Bottom01(pc),a0
				move.l	#0,d0
				move.l	#8*30,d1
				bsr		DisplayText

				lea		Text_Bottom02(pc),a0
				move.l	#0,d0
				move.l	#8*31,d1
				bsr		DisplayText
				
				lea		Ennemy01MoveInfo(pc),a3
				move.l	#48-16,SEntityMoveInfo_X(a3)
				move.l	#8*18+3,SEntityMoveInfo_Y(a3)
				lea		Ennemy02MoveInfo(pc),a3
				move.l	#48-16,SEntityMoveInfo_X(a3)
				move.l	#8*18+3,SEntityMoveInfo_Y(a3)

				lea		PlayerMoveInfo(pc),a3
				move.l	#48-16,SEntityMoveInfo_X(a3)
				move.l	#8*12+3,SEntityMoveInfo_Y(a3)

				lea		QLixCoord(pc),a3
				move.l	#(33)*256,(a3)
				move.l	#(8*21)*256,4(a3)
				move.l	#(48-8)*256,8(a3)
				move.l	#(8*21+8)*256,12(a3)

				lea		Music_OdeALaJoie(pc),a0
				bsr		StartMusic
				rts
				
;=============================================================================
; Process Menu
;=============================================================================
ProcessMenu:
				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.WaitOnMenu

				bsr		StopSound
				bsr		StartGame
				rts
.WaitOnMenu:
				lea     NbLoop(pc),a0
				move.l	(a0),d7

				lea		Text_PressSpaceEmpty(pc),a0
				btst	#4,d7
				beq.s	.NoSpace
				lea		Text_PressSpace(pc),a0
.NoSpace:
				move.l	#128-11*8/2,d0
				move.l	#8*26,d1
				bsr		DisplayText

				bsr		CleanPreviousDisplay
				bsr		DrawAll

				bsr		PlayMusic
				rts
				
;=============================================================================
; Start Game Start
;=============================================================================
StartGame:
				move.l	#GAME_STATUS_GAMESTART,d0
				bsr		SetGameStatus

				lea		Music_GameStart(pc),a0
				bsr		StartMusic

				bsr		ResetQLix
				rts

;=============================================================================
; Process game loose life
;=============================================================================
ProcessGameLooseLife:
				bsr		CleanPreviousDisplay

				lea     NbLoop(pc),a0
				move.l	(a0),d0
				cmp.l	#90,d0
				bne.s	.NotEndingGameLooseLife

				bsr		BigClean

				bsr		BackSpiraleSaveBuffer
				bsr		SwapBuffer
				bsr		BackSpiraleSaveBuffer

				move.l	#GAME_STATUS_GAMESTART,d0
				bsr		SetGameStatus
				bsr		StopSound
				lea		Music_GameStart(pc),a0
				bsr		StartMusic


				bsr		TouchPlayerTracing			; Can set GAME_SATUS at Gameover
				rts
.NotEndingGameLooseLife:

				lea     NbLoop(pc),a0
				move.l	(a0),d0
				cmp.l	#50,d0
				bhi.s	.NoSpirale
				bsr		DrawSpiraleAround
.NoSpirale:

				bsr		DrawAll

				bsr		PlayMusic

				rts


;=============================================================================
; Process game start
;=============================================================================
ProcessGameStart:
				lea     NbLoop(pc),a0
				move.l	(a0),d0
				cmp.l	#75,d0
				bne.s	.NotEndingGameStart

				bsr		BigClean

				bsr		BackSpiraleSaveBuffer
				bsr		SwapBuffer
				bsr		BackSpiraleSaveBuffer

				move.l	#GAME_STATUS_GAME,d0
				bsr		SetGameStatus
				bsr		StopSound
				rts
.NotEndingGameStart:

				bsr		CleanPreviousDisplay

				lea     NbLoop(pc),a0
				move.l	(a0),d0
				cmp.l	#50,d0
				bhi.s	.NoSpirale
				bsr		DrawSpiraleAround
.NoSpirale:
				bsr		DrawAll

				bsr		PlayMusic
				rts

				
;=============================================================================
; Spirale around player at start & loose
;=============================================================================
SpiraleBackBuffer: dcb.l (32/2/4)*32+1,0

BackSpiraleSaveBuffer:
				lea		PlayerMoveInfo(pc),a3		; a3 = Player coord adr
				lea		ScreenBase(pc),a4
				move.l	(a4),a4
				lea		SpiraleBackBuffer(pc),a1
				tst.l	(a1)+
				beq.s	.NoBackSpirale
				move.l	SEntityMoveInfo_X(a3),d0		; X
				move.l	SEntityMoveInfo_Y(a3),d1		; Y
				sub.l	#16-3,d0
				sub.l	#16-3,d1
				move.l	a4,a0
				bsr		Back32x32
.NoBackSpirale:
				rts

SaveSpiraleSaveBuffer:
				lea		PlayerMoveInfo(pc),a3		; a3 = Player coord adr
				lea		ScreenBase(pc),a4
				move.l	(a4),a4
				move.l	SEntityMoveInfo_X(a3),d0		; X
				move.l	SEntityMoveInfo_Y(a3),d1		; Y
				sub.l	#16-3,d0
				sub.l	#16-3,d1
				move.l	a4,a0
				lea		SpiraleBackBuffer(pc),a1
				move.l	#1,(a1)+
				bsr		Save32x32
				rts

DrawSpiraleAround:
				lea		PlayerMoveInfo(pc),a3		; a3 = Player coord adr
				lea		ScreenBase(pc),a4
				move.l	(a4),a4
				
				bsr		BackSpiraleSaveBuffer
				bsr		SaveSpiraleSaveBuffer
				
				lea     NbLoop(pc),a0
				move.l	(a0),d7								; Num frame
				;moveq	#64,d7

                move.w  d7,d6
				add.w	#32,d6
				add.w	d6,d6
                lea     SinTable6(pc),a6
				moveq	#0,d5
                andi.w  #127,d6
				move.b	(a6,d6.w),d5
				add.b	#6,d5				; between 0 & 11
				lsl.l	#7,d5				; x128 to change sin table

				move.l	#16-1,d4
.LoopSpirale:
                lea     SinTable13(pc),a6

                andi.w  #127,d7
                move.w  d7,d6
				add.w	d5,d6
				moveq	#0,d3
                move.b  (a6,d6.w),d3    				; Sin(Angle)
				ext.w	d3
				move.l	SEntityMoveInfo_X(a3),d0		; X
				add.w	d3,d0

                move.w  d7,d6
                addi.w  #32,d6
                andi.w  #127,d6
				add.w	d5,d6
				moveq	#0,d3
                move.b  (a6,d6.w),d3    				; Cos(Angle)
				ext.w	d3
				move.l	SEntityMoveInfo_Y(a3),d1		; Y
				add.w	d3,d1
				
				bsr		PlotPixelWhite
				
				add.l	#128/16,d7
				dbra	d4,.LoopSpirale
				
				rts
				
;=============================================================================
; Process game
;=============================================================================
ProcessGame:
				bsr		CleanPreviousDisplay

				lea		PlayerMustDie(pc),a0
				tst.l	(a0)
				beq.s	.PlayerMustNotDie
				move.l	#0,(a0)

				lea		Music_LifeLost(pc),a0
				bsr		StartMusic

				move.l	#GAME_STATUS_GAMELOOSELIFE,d0
				bsr		SetGameStatus
				rts
.PlayerMustNotDie:

				lea		Ennemy01MoveInfo(pc),a3
				bsr		MoveEnnemy
				
				lea		Ennemy02MoveInfo(pc),a3
				bsr		MoveEnnemy
				
				bsr		MovePlayer
				
				bsr		MoveQLix
				
				bsr		UpdateTimer
				
				bsr		DrawAll
				rts

;=============================================================================
; Start Game Over
;=============================================================================
StartGameOver:
				move.l	#GAME_STATUS_GAMEOVER,d0
				bsr		SetGameStatus

				lea		Music_GameOver(pc),a0
				bsr		StartMusic
				rts

;=============================================================================
; Process game over
;=============================================================================
ProcessGameOver:
				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.WaitOnGameOver

				bsr		StopSound
				bsr		StartMenu
				rts
.WaitOnGameOver:
				lea     NbLoop(pc),a0
				move.l	(a0),d7

				lea		Text_GameOver(pc),a0
				move.l	#128-13*8/2,d0
				move.l	#128-4,d1
				bsr		DisplayText

				lea		Text_GameOverScore02(pc),a0
				lea		Score(pc),a6
				move.l	(a6),d0
				bsr		NumberToAscii_000000

				lea		Text_GameOverScore01(pc),a0
				move.l	#128-18*8/2,d0
				move.l	#128+4+8,d1
				bsr		DisplayText

				lea		Text_PressSpaceEmpty(pc),a0
				btst	#4,d7
				beq.s	.NoSpace
				lea		Text_PressSpace(pc),a0
.NoSpace:
				move.l	#128-11*8/2,d0
				move.l	#128+4+8*8,d1
				bsr		DisplayText
				
				bsr		PlayMusic
				rts


	even
GameMode:	dc.l		0
	even
PlayerCoordStartTracing:	dc.l	0,0				
	even
PlayerIsTracing:	dc.b 0
	even
PlayerLife:	dc.b 0
	even
FillingCounter:		dc.l 0
	even
Score:		dc.l 0
	even
Timer:		dc.l 0
	even
TimerDisplayed:		dc.l 0
	even
FloodFillingStackBottom:
				dcb.b	2048,0
FloodFillingStack:
	even

PlayerMustDie:	dc.l	0
	even

EnnemyMoveOffest:
	dc.b	0,1,3,-1 ; R D U   ; Add -1 to multiple by 4 to get the right offset list
	dc.b	1,2,0,-1 ; D L R
	dc.b	2,3,1,-1 ; L U D
	dc.b	3,0,2,-1 ; U R L
	even
EnnemyCoordForMoveOffest:
	dc.b	2,0		; R
	dc.b	0,2		; D
	dc.b	-2,0	; L
	dc.b	0,-2	; U
	even

	
	RSRESET
SEntityMoveInfo_X:			RS.L 1	; Current X
SEntityMoveInfo_Y:			RS.L 1	; Current Y
SEntityMoveInfo_fX:			RS.L 1	; Current X - 24:8 format
SEntityMoveInfo_fY:			RS.L 1	; Current Y - 24:8 format
SEntityMoveInfo_fSpeedX:	RS.L 1	; Speed X - 24:8 format
SEntityMoveInfo_fSpeedY:	RS.L 1	; Speed Y - 24:8 format
SEntityMoveInfo_NbMove:		RS.L 1	; Nb Move to do
SEntityMoveInfo_XFinal:		RS.L 1	; Final X to set at final move (32:0)
SEntityMoveInfo_YFinal:		RS.L 1	; Final Y to set at final move (32:0)
SEntityMoveInfo_MoveOff:	RS.L 1	; Move offset for ennemies
SEntityMoveInfo_SIZEOF:     RS.B 0

PlayerMoveInfo:				dcb.b    SEntityMoveInfo_SIZEOF,0
	even
Ennemy01MoveInfo:			dcb.b    SEntityMoveInfo_SIZEOF,0
	even
Ennemy02MoveInfo:			dcb.b    SEntityMoveInfo_SIZEOF,0
	even

;=============================================================================
; Move an entity
; a3 = SEntityMoveInfo adress
; d0 = 0 if no move done
;=============================================================================
MoveEntity:
; Must move?
				tst.l		SEntityMoveInfo_NbMove(a3)
				beq.s		.NoMoveEntity

; Last move?
				sub.l		#1,SEntityMoveInfo_NbMove(a3)
				beq.s		.EndOfMovingEntity

; Move.
				move.l		SEntityMoveInfo_fSpeedX(a3),d0
				add.l		d0,SEntityMoveInfo_fX(a3)
				move.l		SEntityMoveInfo_fSpeedY(a3),d0
				add.l		d0,SEntityMoveInfo_fY(a3)
				
				move.l		SEntityMoveInfo_fX(a3),d0
				lsr.l		#8,d0
				move.l		d0,SEntityMoveInfo_X(a3)

				move.l		SEntityMoveInfo_fY(a3),d0
				lsr.l		#8,d0
				move.l		d0,SEntityMoveInfo_Y(a3)
				
.EndMoveEntity:
				moveq		#1,d0
				rts

.EndOfMovingEntity:
				move.l		SEntityMoveInfo_XFinal(a3),SEntityMoveInfo_X(a3)
				move.l		SEntityMoveInfo_YFinal(a3),SEntityMoveInfo_Y(a3)
				moveq		#0,d0
				rts

.NoMoveEntity:
				moveq		#0,d0
				rts

;=============================================================================
; Clean all previous things displayed at the same time at the start of the frame
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
; Clean one sprite
; a1 = Save struct adr
; d7 = Num Buffer
;=============================================================================
CleanOneSprite:
; Erase previous player
				move.l	d7,d6
				lsl.l	#6,d6
				add.l	d6,a1
				tst.b	56(a1)				; Valid back buffer ?
				beq.s	.DoNotEraseSprite

				move.l	(a1),d0
				move.l	4(a1),d1
				add.l	#8,a1
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				bsr		BackSprite8x8Shifted
.DoNotEraseSprite:
				rts
				
;=============================================================================
; Clean all previous things displayed at the same time at the start of the frame
;=============================================================================
CleanPreviousDisplay:
				lea		BufferNum(pc),a6
				moveq	#0,d7
				move.w	(a6),d7

; Erase previous player
				lea		PlayerSave(pc),a1
				bsr		CleanOneSprite

; Erase previous ennemies
				lea		Ennemy02Save(pc),a1
				bsr		CleanOneSprite

				lea		Ennemy01Save(pc),a1
				bsr		CleanOneSprite

; Erase previous QLix
				lea		QLixCoordSave(pc),a1
				move.l	d7,d6
				lsl.l	#4,d6					; *16 for next frame
				add.l	d6,a1
				move.l	(a1),d0
				move.l	4(a1),d1
				move.l	8(a1),d4
				move.l	12(a1),d5
				move.l	#ColorPixelBlack,d6
				bsr		DrawLineQLix

				rts

;=============================================================================
; Big clean to remove everything from both frame buffer and reset sprite back buffer
;=============================================================================
BigClean:
				bsr		SwapBuffer
				bsr		CleanPreviousDisplay
				bsr		SwapBuffer
				bsr		CleanPreviousDisplay

				lea		PlayerSave(pc),a1
				move.b	#0,56(a1)
				move.b	#0,56+64(a1)					; Invalidate both back buffer

				lea		Ennemy01Save(pc),a1
				move.b	#0,56(a1)
				move.b	#0,56+64(a1)					; Invalidate both back buffer

				lea		Ennemy02Save(pc),a1
				move.b	#0,56(a1)
				move.b	#0,56+64(a1)					; Invalidate both back buffer
				rts
				
;=============================================================================
; Save a sprite
; a1 = Save struct adr
; a3 = Sprite coord
; Then draw all
;=============================================================================
SaveOneSprite:
				move.l	d7,d6
				lsl.l	#6,d6
				add.l	d6,a1

				move.l	SEntityMoveInfo_X(a3),d0
				sub.l	#3,d0
				move.l	SEntityMoveInfo_Y(a3),d1
				sub.l	#3,d1
				move.l	d0,(a1)
				move.l	d1,4(a1)

				add.l	#8,a1
				move.b	#1,48(a1)				; Validate back buffer
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				bsr		SaveSprite8x8Shifted
				rts

;=============================================================================
; Draw a sprite
; a1 = Save struct adr
; a3 = Sprite coord
; Then draw all
;=============================================================================
DrawOneSprite:
				lea     NbLoop(pc),a0
                move.l  (a0),d0
				and.l	#%1100,d0

				lsr.l	#2,d0
				lsl.l	#7,d0
				move.l	d0,d1
				add.l	d1,d1
				add.l	d0,a1
				add.l	d1,a1

				move.l	SEntityMoveInfo_X(a3),d0
				sub.l	#3,d0
				move.l	SEntityMoveInfo_Y(a3),d1
				sub.l	#3,d1

				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				bsr		DisplaySprite8x8MaskedShifted
				rts
				
;=============================================================================
; Draw all
; First save background
; Then draw all
;=============================================================================
DrawAll:
				lea		BufferNum(pc),a6
				moveq	#0,d7
				move.w	(a6),d7

; Save ennemies 01 & 02
				lea		Ennemy01Save(pc),a1
				lea		Ennemy01MoveInfo(pc),a3
				bsr		SaveOneSprite

				lea		Ennemy02Save(pc),a1
				lea		Ennemy02MoveInfo(pc),a3
				bsr		SaveOneSprite
				
; Save player
				lea		PlayerSave(pc),a1
				lea		PlayerMoveInfo(pc),a3
				bsr		SaveOneSprite

; Draw QLix
				lea		QLixCoordSave(pc),a1
				lea		QLixCoord(pc),a3
				move.l	d7,d6
				lsl.l	#4,d6					; *16 for next frame
				add.l	d6,a1
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	8(a3),d4
				move.l	12(a3),d5
				lsr.l	#8,d0
				lsr.l	#8,d1
				lsr.l	#8,d4
				lsr.l	#8,d5
				move.l	d0,(a1)
				move.l	d1,4(a1)
				move.l	d4,8(a1)
				move.l	d5,12(a1)
				move.l	#ColorPixelWhite,d6

				cmp.w	#PLAYFIELD_START_X,d0
				bmi.s	.QlixOut
				cmp.w	#PLAYFIELD_START_Y,d1
				bmi.s	.QlixOut

				cmp.w	#191+PLAYFIELD_START_X,d0
				bhi.s	.QlixOut
				cmp.w	#191+PLAYFIELD_START_Y,d1
				bhi.s	.QlixOut

				bsr		DrawLineQLix

				cmp.l	#COL_INFO_TRACING,a6		; Any pixel of the drawline touch player line?
				bne.s	.noplayercollide
				lea		PlayerMustDie(pc),a0
				move.l	#1,(a0)
				bra		.ContinueDraw
.noplayercollide:
				cmp.l	#0,a6		; Any pixel of the drawline touch player line?
				beq.s	.ContinueDraw
				bra		.ContinueDraw
.QlixOut:
				DBGBREAK

.ContinueDraw:
; Draw ennemies 01 & 02
				lea		SpriteEnnemy_01(pc),a1
				lea		Ennemy01MoveInfo(pc),a3
				bsr		DrawOneSprite

				lea		SpriteEnnemy_01(pc),a1
				lea		Ennemy02MoveInfo(pc),a3
				bsr		DrawOneSprite

; Draw player
				lea		SpritePlayer_01(pc),a1
				lea		PlayerMoveInfo(pc),a3
				bsr		DrawOneSprite

				rts

;=============================================================================
; Macro for Move Entity
;=============================================================================
	macro SetupMoveInfoUp
				move.l	#0,SEntityMoveInfo_fSpeedX(a3)
				move.l	#-256,SEntityMoveInfo_fSpeedY(a3)
				move.l	#2,SEntityMoveInfo_NbMove(a3)
				move.l	SEntityMoveInfo_X(a3),SEntityMoveInfo_XFinal(a3)
				move.l	SEntityMoveInfo_Y(a3),SEntityMoveInfo_YFinal(a3)
				sub.l	#2,SEntityMoveInfo_YFinal(a3)
				move.l	SEntityMoveInfo_X(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fX(a3)
				move.l	SEntityMoveInfo_Y(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fY(a3)
	endm
	macro SetupMoveInfoDown
				move.l	#0,SEntityMoveInfo_fSpeedX(a3)
				move.l	#256,SEntityMoveInfo_fSpeedY(a3)
				move.l	#2,SEntityMoveInfo_NbMove(a3)
				move.l	SEntityMoveInfo_X(a3),SEntityMoveInfo_XFinal(a3)
				move.l	SEntityMoveInfo_Y(a3),SEntityMoveInfo_YFinal(a3)
				add.l	#2,SEntityMoveInfo_YFinal(a3)
				move.l	SEntityMoveInfo_X(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fX(a3)
				move.l	SEntityMoveInfo_Y(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fY(a3)
	endm
	macro SetupMoveInfoRight
				move.l	#256,SEntityMoveInfo_fSpeedX(a3)
				move.l	#0,SEntityMoveInfo_fSpeedY(a3)
				move.l	#2,SEntityMoveInfo_NbMove(a3)
				move.l	SEntityMoveInfo_X(a3),SEntityMoveInfo_XFinal(a3)
				move.l	SEntityMoveInfo_Y(a3),SEntityMoveInfo_YFinal(a3)
				add.l	#2,SEntityMoveInfo_XFinal(a3)
				move.l	SEntityMoveInfo_X(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fX(a3)
				move.l	SEntityMoveInfo_Y(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fY(a3)
	endm
	macro SetupMoveInfoLeft
				move.l	#-256,SEntityMoveInfo_fSpeedX(a3)
				move.l	#0,SEntityMoveInfo_fSpeedY(a3)
				move.l	#2,SEntityMoveInfo_NbMove(a3)
				move.l	SEntityMoveInfo_X(a3),SEntityMoveInfo_XFinal(a3)
				move.l	SEntityMoveInfo_Y(a3),SEntityMoveInfo_YFinal(a3)
				sub.l	#2,SEntityMoveInfo_XFinal(a3)
				move.l	SEntityMoveInfo_X(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fX(a3)
				move.l	SEntityMoveInfo_Y(a3),d0
				lsl.l	#8,d0
				move.l	d0,SEntityMoveInfo_fY(a3)
	endm

;=============================================================================
; Move one ennemy
; Input : a3 - ennemy info
;=============================================================================
MoveEnnemy:
				bsr		MoveEntity
				tst.l	d0
				bne.w	.EnnemyCollision

; Get current col
				;DBGBREAK
				moveq	#0,d2
				move.l	SEntityMoveInfo_X(a3),d0		; X
				move.l	SEntityMoveInfo_Y(a3),d1		; Y
				sub.w	#PLAYFIELD_START_X,d0
				sub.w	#PLAYFIELD_START_Y,d1
				bsr		GetQLixColInfo
				move.l	d2,a5			; Save col info

; Next move according to the table offest
				lea		EnnemyMoveOffest(pc),a6
				lea		EnnemyCoordForMoveOffest(pc),a4
				moveq	#0,d0
				moveq	#0,d1
				moveq	#0,d2
				moveq	#0,d3
				move.l	SEntityMoveInfo_MoveOff(a3),d3		; Get move offest table
				lsl.b	#2,d3			; *4
				
.TestNextMoveOffset:
				move.b	(a6,d3.w),d2	; Get num coord for move offest
				cmp.b	#-1,d2
				beq		.EnnemyLocked
				move.b	d2,d7
				add.b	#1,d3			; Next move offset if needed
				add.b	d2,d2			; *2
				
				move.l	SEntityMoveInfo_X(a3),d5		; X
				move.l	SEntityMoveInfo_Y(a3),d6		; Y
				add.b	(a4,d2.w),d5
				add.b	1(a4,d2.w),d6	; New coord to test

				move.l	d5,d0
				move.l	d6,d1
				cmp.l	#COL_INFO_WAS_A_WAY,a5
				bne.s	.TestPlayerMoveNormal
				bsr		PlayerCanMoveFromOldWay 	; d0-d2,a2
				bra.s	.EndCanMove
.TestPlayerMoveNormal:
				bsr		PlayerCanMove 	; d0-d2,a2
.EndCanMove:
				cmp.b	#1,d2
				bne.s	.TestNextMoveOffset

				move.l	d7,SEntityMoveInfo_MoveOff(a3)		; Store new move offset
				
				move.l	SEntityMoveInfo_X(a3),d0		; X
				move.l	SEntityMoveInfo_Y(a3),d1		; Y
				cmp.l	d5,d0
				beq.s	.EnnemyMoveY
				cmp.l	d5,d0
				bhi.s	.EnnemyMoveXLeft
				SetupMoveInfoRight
				rts
.EnnemyMoveXLeft:
				SetupMoveInfoLeft
				rts

.EnnemyMoveY:
				cmp.l	d6,d1
				bhi.s	.EnnemyMoveYUp
				SetupMoveInfoDown
				rts
.EnnemyMoveYUp:
				SetupMoveInfoUp
				
				rts

; Player collision
.EnnemyCollision:
DIST_COL_ENNEMY_PLAYER		equ 2
				lea		PlayerMoveInfo(pc),a0
				move.l	SEntityMoveInfo_X(a0),d0
				move.l	SEntityMoveInfo_Y(a0),d1

				move.l	SEntityMoveInfo_X(a3),d2
				move.l	SEntityMoveInfo_Y(a3),d3

				sub.l	d0,d2
				bpl.s	.nonegx
				neg.l	d2						; |XP-XE|
.nonegx:
				cmp.l	#DIST_COL_ENNEMY_PLAYER,d2
				bhi.s	.endcollideennemy

				sub.l	d1,d3
				bpl.s	.nonegy
				neg.l	d3						; |XP-XE|
.nonegy:
				cmp.l	#DIST_COL_ENNEMY_PLAYER,d3
				bhi.s	.endcollideennemy
				
				lea		PlayerMustDie(pc),a0
				move.l	#1,(a0)
				;DBGBREAK

.endcollideennemy:
				rts

.EnnemyLocked:
				DBGBREAK
				rts

;=============================================================================
; Move Player
;=============================================================================
PLAYER_SPEED	equ		2
MovePlayer:
				lea		PlayerMoveInfo(pc),a3		; a3 = Player coord adr
				bsr		MoveEntity
				tst.l	d0
				bne.w	.EndMovePlayer

				lea		PlayerCoordStartTracing(pc),a6

; Keyboard & collisions
				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				moveq	#0,d3

				lea		PlayerIsTracing(pc),a5

; Can go Up ?
				btst	#Keyboard01_Up,d4
				beq.w	.NoUp
				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1
				sub.l	#2,d1					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceUp
.MoveUp:
				SetupMoveInfoUp

				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceUp:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq		.NoUp
				tst.w	d2							; empty ?
				bne.s	.NoUp
.FillUp:
				SetupMoveInfoUp

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1

				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingUp
				move.l	d0,(a6)
				move.l	d1,4(a6)
.NotStartTracingUp:
				move.b	#1,(a5)					; Tracing flag
				sub.l	#2,d1
				bsr		PlotPixelRed2

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1
				sub.l	#2,d1
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoUp:

; Can go Down ?
				btst	#Keyboard01_Down,d4
				beq.w	.NoDown
				move.l	(a3),d0
				move.l	4(a3),d1
				add.l	#PLAYER_SPEED,d1					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceDown
.MoveDown:
				SetupMoveInfoDown

				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceDown:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoDown
				tst.w	d2						; empty ?
				bne.s	.NoDown
.FillDown:
				SetupMoveInfoDown

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1

				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingDown
				move.l	d0,(a6)
				move.l	d1,4(a6)
.NotStartTracingDown:
				move.b	#1,(a5)					; Tracing flag
				add.l	#2,d1
				bsr		PlotPixelRed2

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1
				add.l	#2,d1
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoDown:

; Can go Right ?
				btst	#Keyboard01_Right,d4
				beq.w	.NoRight
				move.l	(a3),d0
				move.l	4(a3),d1
				add.l	#PLAYER_SPEED,d0					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceRight
.MoveRight:
				SetupMoveInfoRight

				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceRight:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoRight
				tst.w	d2						; empty ?
				bne.s	.NoRight
.FillRight:
				SetupMoveInfoRight

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1

				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingRight
				move.l	d0,(a6)
				move.l	d1,4(a6)
.NotStartTracingRight:
				move.b	#1,(a5)					; Tracing flag
				add.l	#2,d0
				bsr		PlotPixelRed2

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1
				add.l	#2,d0
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoRight:

; Can go Left ?
				btst	#Keyboard01_Left,d4
				beq.w	.NoLeft
				move.l	(a3),d0
				move.l	4(a3),d1
				sub.l	#PLAYER_SPEED,d0					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceLeft
.MoveLeft:
				SetupMoveInfoLeft

				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceLeft:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoLeft
				tst.w	d2						; empty ?
				bne.s	.NoLeft

.FillLeft:
				SetupMoveInfoLeft

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1

				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingLeft
				move.l	d0,(a6)
				move.l	d1,4(a6)
.NotStartTracingLeft:
				move.b	#1,(a5)					; Tracing flag
				sub.l	#2,d0
				bsr		PlotPixelRed2

				move.l	SEntityMoveInfo_X(a3),d0
				move.l	SEntityMoveInfo_Y(a3),d1
				sub.l	#2,d0
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoLeft:

.EndMovePlayer:
				rts

;=============================================================================
; Check if player can move at this coordinate
; Input :
; 		d0 = X (0-191)
;		d1 = Y (0-191)
; Output : -
;		d2.l = 1 - can move to / 0 = can fill to / 2 - can't move to
; Destroy : 
;		d0, d1, d2
;		a2
;=============================================================================
;COL_INFO_NOTHING	equ		0
;COL_INFO_WALL		equ		1
;COL_INFO_TRACING	equ		2
;COL_INFO_FILLING	equ		3
;COL_INFO_WAY		equ		4
;COL_INFO_WAS_A_WAY	equ		5

	macro CommonPlayerMoveStart
				sub.w	#PLAYFIELD_START_X,d0
				bmi.s	.outcoordmove
				sub.w	#PLAYFIELD_START_Y,d1
				bmi.s	.outcoordmove

				cmp.w	#191,d0
				bhi.s	.outcoordmove
				cmp.w	#191,d1
				bhi.s	.outcoordmove
				
				lsr.w	#1,d0
				lsr.w	#1,d1
				
				lea 	QLixCollision(pc),a2
				move.w	d1,d2
				lsl.w	#6,d2		; *64
				lsl.w	#5,d1		; *32
				add.w	d1,a2
				add.w	d2,a2		; *96

				add.w	d0,a2

				move.b	(a2),d2
				tst.b	d2			; Dest is empty ? can only fill to.
				beq.s	.canfillto

				cmp.b	#COL_INFO_WAY,d2	; Dest must be a way
				beq.s	.canmoveto
	endm

	macro CommonPlayerMoveEnd
				bra.s	.cantmoveto
.canmoveto:
				moveq	#1,d2
				rts				
.canfillto:
				moveq	#0,d2
				rts				
.outcoordmove:
				DBGBREAK
.cantmoveto:
				moveq	#2,d2
	endm

PlayerCanMove:
				CommonPlayerMoveStart
				CommonPlayerMoveEnd
				rts				

PlayerCanMoveFromOldWay:
				CommonPlayerMoveStart
				cmp.b	#COL_INFO_WAS_A_WAY,d2	; or Dest must be an old way
				beq.s	.canmoveto
				CommonPlayerMoveEnd
				rts				
				
;=============================================================================
; Fill Playfield when the player close
;=============================================================================
	even
PreviousFillingCounter: dc.l 0

FillPlayField:
                movem.l d0-d7/a0-a6,-(sp)

				bsr		BigClean

				lea		PreviousFillingCounter(pc),a5
				lea		FillingCounter(pc),a6
				move.l	(a6),(a5)						; To compute a score based on filling at one time
				
				lea		FloodFillingStack,a6
				lea		FloodFillingStack,a5
				
;9794414 : 1,3s
;9789900 cycles

				;DBGBREAK
; Coord to start flood scanline filling
; First we fill the Qix region
				lea		QLixCoord(pc),a3
				move.l	(a3),d0
				asr.l   #8,d0
				move.l	4(a3),d1
				asr.l   #8,d1

				sub.w	#PLAYFIELD_START_X,d0
				bmi		.cantfill
				sub.w	#PLAYFIELD_START_Y,d1
				bmi		.cantfill

				cmp.w	#191,d0
				bhi		.cantfill
				cmp.w	#191,d1
				bhi		.cantfill

				lsr.w	#1,d0
				lsr.w	#1,d1
				
				moveq	#COL_INFO_FILLING,d3	; Into a register for optimisation

				move.b	d0,-(a6)				; Save first X
				move.b	d1,-(a6)				; Save first Y
				moveq	#0,d4
				moveq	#0,d5

				lea		QLixCollision(pc),a0
				move.l	a0,a4

.loopfilling:
				cmp.l	a6,a5					; Nothing in the filling stack
				beq.w	.endfilling

				move.b	(a6)+,d5				; Get Y
				move.b	(a6)+,d4				; Get X

				move.l	a4,a0
				add.l	d4,a0		; X
				move.l	d5,d1
				move.l	d5,d0
				lsl.l	#6,d1		; *64
				lsl.l	#5,d0		; *32
				add.l	d1,a0
				add.l	d0,a0		; *96 (Y)

				add.l	#1,a0		; for the first -(a0)
				addq.w	#1,d4

				move.l	d5,d0
				addq.w	#1,d0
				move.l	d5,d1
				subq.w	#1,d1
				
.scanleft:
				subq.w	#1,d4
				tst.b	-(a0)					;like cmp.b	#COL_INFO_NOTHING,-(a0)
				beq.s	.scanleft

				addq.w	#1,d4					; Return to the valid pixel on the right.
				add.l	#1,a0
				
				moveq	#0,d6					; Above flag
				moveq	#0,d7					; Below flag
.filltotheright:
				move.b	d3,(a0)+				; Set to COL_INFO_FILLING

				tst.b	-97(a0)				; like cmp.b	#COL_INFO_NOTHING,-193(a0)
				bne.s	.somethingabove
				tst.b	d6
				bne.s	.testbelow				; Do not stock new line until we get a new one
				moveq	#1,d6					; Set above flag
				move.b	d4,-(a6)
				move.b	d1,-(a6)				; Push next line to filling at previous pixel
				bra.s	.testbelow
.somethingabove:
				moveq	#0,d6					; Nothing above, reset above flag
.testbelow:
				tst.b	95(a0)					; like cmp.b	#COL_INFO_NOTHING,191(a0)
				bne.s	.somethingbelow
				tst.b	d7
				bne.s	.fillnext				; Do not stock new line until we get a new one
				moveq	#1,d7					; Set above flag
				move.b	d4,-(a6)
				move.b	d0,-(a6)				; Push next line to filling at previous pixel
				bra.s	.fillnext
.somethingbelow:
				moveq	#0,d7					; Nothing below, reset below flag
.fillnext:

				addq.w	#1,d4					; Fill next pixel
				tst.b	(a0)					; like cmp.b	#COL_INFO_NOTHING,(a0)
				beq.s	.filltotheright

				bra.s	.loopfilling
				
.endfilling:
				;DBGBREAK

; Find Way that must be Old Way
; 1937208 cycles ; 0.25s
; Optimized with the help of Gemini
                moveq   #COL_INFO_WAY,d0
                moveq   #COL_INFO_FILLING,d1
                moveq   #COL_INFO_WAS_A_WAY,d2

                lea     QLixCollision(pc),a0
                move.w  #(96*96)/4-1,d7       ; /4 as we test 4 pixels per loop

				bra.s	.scan_loop
	macro DoAWay
.is_way\1:
				cmp.b	-2(a0),d1               ; Gauche
				beq.s	.ret\1
				cmp.b	0(a0),d1                ; Droite
				beq.s	.ret\1
				cmp.b	-97(a0),d1             ; Haut
				beq.s	.ret\1
				cmp.b	95(a0),d1              ; Bas
				beq.s	.ret\1
				cmp.b	-98(a0),d1             ; Haut-Gauche
				beq.s	.ret\1
				cmp.b	-96(a0),d1             ; Haut-Droite
				beq.s	.ret\1
				cmp.b	94(a0),d1              ; Bas-Gauche
				beq.s	.ret\1
				cmp.b	96(a0),d1              ; Bas-Droite
				beq.s	.ret\1
				
				move.b	d2,-1(a0)
				bra.s	.ret\1
	endm
	
				DoAWay 1
				DoAWay 2						; 1 & 2 here to allow .s for jump
	
.scan_loop:
				cmp.b	(a0)+,d0
				beq.s	.is_way1
.ret1:
				cmp.b	(a0)+,d0
				beq.s	.is_way2
.ret2:
				cmp.b	(a0)+,d0
				beq.s	.is_way3
.ret3:
				cmp.b	(a0)+,d0
				beq		.is_way4
.ret4:
				dbra	d7,.scan_loop
				bra.w	.end_scan

				DoAWay 3
				DoAWay 4						; 3 & 4 here to allow .s for jump
.end_scan:
				;bsr		DebugDisplayQLixColInfo
				;DBGBREAK

; Now we fill the other part and clean the qix region
				lea		QLixCollision(pc),a0
				lea		FillingCounter(pc),a6

				moveq	#0,d5			; Y col
				
				move.l	#96-1,d7		; Nb lines
.loopY:
				moveq	#0,d4			; X col
				move.l	#96-1,d6		; Nb cols
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_FILLING,d0		; COL_INFO_FILLING ?
				beq		.isfilling

				tst.b	d0							; like cmp.b	#COL_INFO_NOTHING,d0		; empty place become a wall
				beq.s	.tobefilledinside

				cmp.b	#COL_INFO_TRACING,d0		; COL_INFO_TRACING ? player tracing become a wall
				beq.s	.tobefilledborder

				bra.s	.doloop

.tobefilledinside:
				move.b	#COL_INFO_WALL,-1(a0)

				add.l	#185*4,(a6)						; Inc filling counter

				move.w	d4,d0
				lsl.w	#1,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelCyan2x4
				bra.s	.doloop

.tobefilledborder:
				move.b	#COL_INFO_WAY,-1(a0)

				add.l	#185*4,(a6)						; Inc filling counter

				move.w	d4,d0
				lsl.w	#1,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelWhite2x4
				bra.s	.doloop
				
.isfilling:
				clr.b	-1(a0)					; like move.b	#COL_INFO_NOTHING,-1(a0)	; filled area become empty
				
.doloop:				
				add.w	#1,d4
				dbra	d6,.loopX

				add.w	#1,d5
				dbra	d7,.loopY

; Update Score.
				lea		PreviousFillingCounter(pc),a5
				lea		FillingCounter(pc),a6
				move.l	(a6),d0
				sub.l	(a5),d0
				lsr.l	#8,d0
				lsr.l	#8,d0
				add.l	#1,d0
				
				mulu	d0,d0
				lsl.l	#4,d0
				lea		Score(pc),a5
				add.l	d0,(a5)

				bsr		UpdateText

; Win this level ?
				lea		FillingCounter(pc),a6
				move.l	(a6),d0
				lsr.l	#8,d0
				lsr.l	#8,d0
				cmp.l	#75,d0
				bmi.s	.NoWin
				bsr		StartWinLevel
.NoWin:
                movem.l (sp)+,d0-d7/a0-a6
				rts

.cantfill:
				DBGBREAK
                movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; Touch player tracing
;=============================================================================
TouchPlayerTracing:
                movem.l d0-d7/a0-a6,-(sp)

				moveq	#0,d5		; Y screen
				
				move.l	#96-1,d7	; Nb lines
.loopY:
				moveq	#0,d4		; X screen
				move.l	#96-1,d6	; Nb cols

				lea		QLixCollision(pc),a0
				move.w	d5,d1
				add.w	d4,a0		; X
				move.w	d1,d0
				lsl.w	#6,d1		; *64
				lsl.w	#5,d0		; *32
				add.w	d1,a0
				add.w	d0,a0		; *96 (Y)
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_TRACING,d0
				bne.s	.doloop

				move.b	#COL_INFO_NOTHING,-1(a0)

				move.w	d4,d0
				lsl.w	#1,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelBlack2x4
				bra.s	.doloop

.isfilling:
				move.b	#COL_INFO_NOTHING,-1(a0)	; filled area become empty
				
.doloop:				
				add.w	#1,d4
				dbra	d6,.loopX
				add.w	#1,d5
				dbra	d7,.loopY

				lea		PlayerMoveInfo(pc),a0
				lea		PlayerCoordStartTracing(pc),a1
				move.l	(a1),SEntityMoveInfo_X(a0)
				move.l	4(a1),SEntityMoveInfo_Y(a0)
				move.l	#0,SEntityMoveInfo_NbMove(a0)

				lea		PlayerIsTracing(pc),a5
				move.b	#0,(a5)

				bsr		ResetEnnemiesPosition
				
				CleanVarL PlayerMustDie,a0
				lea		PlayerLife(pc),a0
				sub.b	#1,(a0)
				bne.s	.NotGameOver
				bsr		StartGameOver
.NotGameOver:
				bsr		DisplayLife
				
                movem.l (sp)+,d0-d7/a0-a6
				rts

	even
QLixCoord:		dcb.l	2*2,0				; coord.l * 2 (x, Y) * 2 point (for the line)
	even
QLixCoordSave:	dcb.l	2*2*2,0				; coord.l * 2 (x, Y) * 2 point (for the line) * 2 (nb frame)
	even
QLixVelocity:	dc.l	256,-128,128,-256
	even
;=============================================================================
; Move one coord of the QLix
; a1 = coord to move
; a2 = vel coord to move
;=============================================================================
QLIX_MOVE_MASK 		equ		$FF
QLIX_MOVE_ADD 		equ		1024
QLIX_MOVE_LSL 		equ		6
QLIX_DIST_POINT		equ		12*256
QLIX_DIST_ADJUST	equ		128
QLIX_MAX_VELOCITY	equ		768

MoveOneQLixCoord:
; Move and test collision for X
				move.l	(a1),d0
				move.l	4(a1),d1
				add.l	(a2),d0

				moveq	#0,d2
				lsr.l	#8,d0
				lsr.l	#8,d1
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		GetQLixColInfo

				tst.b	d2
				beq.s	.nocollideX
				cmp.b	#COL_INFO_WALL,d2
				beq.s	.collidewallX
				cmp.b	#COL_INFO_TRACING,d2
				beq		.collidetracing

.collidewallX:
				neg.l	(a2)						; Change direction of X velocity
				GetRandom d0
				move.l	d0,d1
				and.l	#QLIX_MOVE_MASK,d0
				add.l	#QLIX_MOVE_ADD,d0
				;lsl.l	#QLIX_MOVE_LSL,d0
				btst	#8,d1
				beq.s	.negy
				neg.l	d0
.negy:
				move.l	d0,4(a2)					; Random Y velocity
				bra.s	.testcollideY

.nocollideX:
				move.l	(a2),d0
				add.l	d0,(a1)						; Save new X
.testcollideY:

; Move and test collision for Y
				move.l	(a1),d0
				move.l	4(a1),d1
				add.l	4(a2),d1

				moveq	#0,d2
				lsr.l	#8,d0
				lsr.l	#8,d1
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		GetQLixColInfo

				tst.b	d2
				beq.s	.nocollideY
				cmp.b	#COL_INFO_WALL,d2
				beq.s	.collidewallY
				cmp.b	#COL_INFO_TRACING,d2
				beq.s	.collidetracing

.collidewallY:
				neg.l	4(a2)						; Change direction of Y velocity
				GetRandom d0
				move.l	d0,d1
				and.l	#QLIX_MOVE_MASK,d0
				add.l	#QLIX_MOVE_ADD,d0
				;lsl.l	#QLIX_MOVE_LSL,d0
				btst	#8,d1
				beq.s	.negx
				neg.l	d0
.negx:
				move.l	d0,(a2)						; Random X velocity
				bra.s	.endcollide

.collidetracing:
				lea		PlayerMustDie(pc),a0
				move.l	#1,(a0)
				;DBGBREAK
				bra.s	.endcollide

.nocollideY:
				move.l	4(a2),d0
				add.l	d0,4(a1)						; Save new Y
				
.endcollide:
				rts
				

;=============================================================================
; Move QLix
;=============================================================================
MoveQLix:
;	DBGBREAK

; Make the two points at good distance
				lea		QLixCoord(pc),a1
				lea		QLixVelocity(pc),a2
				move.l	(a1),d0					; X0
				sub.l	8(a1),d0				; X0-X1
				bpl.s	.nonegx
				neg.l	d0						; |X0-X1|
.nonegx:
				cmp.l	#QLIX_DIST_POINT,d0
				bmi.s	.startdisty

				move.l	(a1),d0
				cmp.l	8(a1),d0
				bgt.s	.x0x1					; X0 > X1 ?
				add.l	#QLIX_DIST_ADJUST,(a2)
				sub.l	#QLIX_DIST_ADJUST,8(a2)
				bra.s	.startdisty
.x0x1:
				sub.l	#QLIX_DIST_ADJUST,(a2)
				add.l	#QLIX_DIST_ADJUST,8(a2)

.startdisty;
				move.l	4(a1),d0					; Y0
				sub.l	12(a1),d0				; Y0-Y1
				bpl.s	.nonegy
				neg.l	d0						; |Y0-Y1|
.nonegy:
				cmp.l	#QLIX_DIST_POINT,d0
				bmi.s	.nottoofarawayy

				move.l	4(a1),d0
				cmp.l	12(a1),d0
				bgt.s	.y0y1					; Y0 > Y1 ?
				add.l	#QLIX_DIST_ADJUST,4(a2)
				sub.l	#QLIX_DIST_ADJUST,12(a2)
				bra.s	.nottoofarawayy
.y0y1:
				sub.l	#QLIX_DIST_ADJUST,4(a2)
				add.l	#QLIX_DIST_ADJUST,12(a2)
.nottoofarawayy:
; Move the two points
				lea		QLixCoord(pc),a1
				lea		QLixVelocity(pc),a2
				bsr 	MoveOneQLixCoord

				lea		QLixCoord+8(pc),a1
				lea		QLixVelocity+8(pc),a2
				bsr 	MoveOneQLixCoord

				
; Cap velocity
.capx0:
				cmp.l	#QLIX_MAX_VELOCITY,(a2)
				ble.s	.capx1
				move.l	#QLIX_MAX_VELOCITY,(a2)
.capx1:
				cmp.l	#-QLIX_MAX_VELOCITY,8(a2)
				bge.s	.capy0
				move.l	#-QLIX_MAX_VELOCITY,8(a2)

.capy0:
				cmp.l	#QLIX_MAX_VELOCITY,4(a2)
				ble.s	.capy1
				move.l	#QLIX_MAX_VELOCITY,4(a2)
.capy1:
				cmp.l	#-QLIX_MAX_VELOCITY,12(a2)
				bge.s	.endmoveqlix
				move.l	#-QLIX_MAX_VELOCITY,12(a2)

.endmoveqlix:
				rts

;=============================================================================
; Update text
;=============================================================================
UpdateText:
; Percent fill.
				lea		Text000(pc),a0
				lea		FillingCounter(pc),a6
				move.l	(a6),d0
				lsr.l	#8,d0
				lsr.l	#8,d0
				bsr		NumberToAscii_00
				
				move.l	#19*8,d0
				move.l	#20,d1
				bsr		DisplayText

; Score.
				lea		Text_Score02(pc),a0
				lea		Score(pc),a6
				move.l	(a6),d0
				bsr		NumberToAscii_000000

				lea		Text_Score01(pc),a0
				move.l	#8*5,d0
				move.l	#243,d1
				bsr		DisplayText

				rts

;=============================================================================
; Update timer
; TODO : Optimiser en ne faisant qu'un draw au départ et en effacant les pixels du temps qui descend.
;=============================================================================
UpdateTimer:
				lea		Timer(pc),a0
				sub.l	#5,(a0)
				ble.s	.nomoretime

				move.l	(a0),d0
				move.l	d0,d2
				lsr.l	#8,d0

				lea		TimerDisplayed(pc),a0
				move.l	(a0),d1
				lsr.l	#8,d1
				
				cmp.l	d0,d1
				beq.s	.EndDisplayTimer
				
				move.l	d2,(a0)				; Save displayed timer
				
				move.l	#160+64,d0
				sub.l	d1,d0
				move.l	#244,d1
				
				move.l	d0,d5
				move.l	d1,d6
				bsr		PlotPixelBlack2
				move.l	d5,d0
				add.l	#1,d6
				move.l	d6,d1
				bsr		PlotPixelBlack2
				move.l	d5,d0
				add.l	#1,d6
				move.l	d6,d1
				bsr		PlotPixelBlack2
				move.l	d5,d0
				add.l	#1,d6
				move.l	d6,d1
				bsr		PlotPixelBlack2
				move.l	d5,d0
				add.l	#1,d6
				move.l	d6,d1
				bsr		PlotPixelBlack2
.EndDisplayTimer:
				rts
				
.nomoretime:
				bsr		StartGameOver
				rts
				
;=============================================================================
; Update life
; a2 : frame buffer
;=============================================================================
DisplayLife:
				move.l	#1,d7
				lea		ScreenBase(pc),a0
				move.l	(a0),a2
				lea		ScreenBaseFront(pc),a6
				move.l	(a6),a6

.loopdispaylife:
				lea		PlayerLife(pc),a3

				lea		SpriteHeart(pc),a1
				move.l	a2,a0
				move.l	#232,d0
				move.l	#23,d1
				cmp.b	#3,(a3)
				bmi.s	.not3life
				bsr		DisplaySprite16x16
				bra.s	.2life
.not3life:
				bsr		ClearSprite16x16
				
.2life:

				lea		SpriteHeart(pc),a1
				move.l	a2,a0
				move.l	#232,d0
				move.l	#23+20,d1
				cmp.b	#2,(a3)
				bmi.s	.not2life
				bsr		DisplaySprite16x16
				bra.s	.1life
.not2life:
				bsr		ClearSprite16x16
.1life:

				lea		SpriteHeart(pc),a1
				move.l	a2,a0
				move.l	#232,d0
				move.l	#23+20*2,d1
				cmp.b	#1,(a3)
				bmi.s	.not1life
				bsr		DisplaySprite16x16
				bra.s	.0life
.not1life:
				bsr		ClearSprite16x16
.0life:

				move.l	a6,a2					; Set next frame buffer to draw
				dbra	d7,.loopdispaylife

				rts

;=============================================================================
; Collision info
; d0 : x (0-191)
; d1 : y (0-191)
; d2 : COL_INFO_???
;=============================================================================
SetQLixColInfo:
				cmp.w	#0,d0
				bmi.s	ErrorColCoord
				cmp.w	#0,d1
				bmi.s	ErrorColCoord

				cmp.w	#191,d0
				bhi.s	ErrorColCoord
				cmp.w	#191,d1
				bhi.s	ErrorColCoord

				lsr.w	#1,d0
				lsr.w	#1,d1

				lea		QLixCollision(pc),a0
				add.w	d0,a0		; X
				move.w	d1,d0
				lsl.w	#6,d1		; *64
				lsl.w	#5,d0		; *32
				add.w	d1,a0
				add.w	d0,a0		; *96 (Y)

				move.b	d2,(a0)		; We set the info
				rts

GetQLixColInfo:
				cmp.w	#0,d0
				bmi.s	ErrorColCoord
				cmp.w	#0,d1
				bmi.s	ErrorColCoord

				cmp.w	#191,d0
				bhi.s	ErrorColCoord
				cmp.w	#191,d1
				bhi.s	ErrorColCoord

				lsr.w	#1,d0
				lsr.w	#1,d1

				lea		QLixCollision(pc),a0
				add.w	d0,a0		; X
				move.w	d1,d0
				lsl.w	#6,d1		; *64
				lsl.w	#5,d0		; *32
				add.w	d1,a0
				add.w	d0,a0		; *96 (Y)
				
				move.b	(a0),d2		; We get the info
				rts

ErrorColCoord:
				;DBGBREAK
				move.b	#COL_INFO_WALL,d2		; We get the info
				rts

; For debug purpose only
DebugDisplayQLixColInfo:
				movem.l d0-d7/a0-a6,-(sp)
				lea		QLixCollision(pc),a0

				moveq	#0,d5	; Y screen
				
				move.l	#96-1,d7				; 192 lines
.loopY:
				moveq	#0,d4	; X screen
				move.l	#96-1,d6				; 192 col
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_NOTHING,d0
				beq		.doloop

				cmp.b	#COL_INFO_WALL,d0
				beq.s	.isWhite

				cmp.b	#COL_INFO_TRACING,d0
				beq.s	.isRed

				cmp.b	#COL_INFO_WAY,d0
				beq.s	.isGreen

				cmp.b	#COL_INFO_WAS_A_WAY,d0
				beq.s	.isBlue

				move.w	d4,d0
				move.w	d5,d1
				lsl.w	#1,d0
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_X,d0
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelYellow2x4
				bra.s	.doloop
.isRed:
				move.w	d4,d0
				move.w	d5,d1
				lsl.w	#1,d0
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_X,d0
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelRed2x4
				bra.s	.doloop
.isGreen:
				move.w	d4,d0
				move.w	d5,d1
				lsl.w	#1,d0
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_X,d0
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelGreen2x4
				bra.s	.doloop
.isBlue:
				move.w	d4,d0
				move.w	d5,d1
				lsl.w	#1,d0
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_X,d0
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelBlue2x4
				bra.s	.doloop
.isWhite:
				move.w	d4,d0
				move.w	d5,d1
				lsl.w	#1,d0
				lsl.w	#1,d1
				add.w	#PLAYFIELD_START_X,d0
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelWhite2x4
				
.doloop:				
				add.w	#1,d4
				dbra	d6,.loopX
				add.w	#1,d5
				dbra	d7,.loopY
				movem.l (sp)+,d0-d7/a0-a6
				rts

				
;=============================================================================
; StartWinLevel
;=============================================================================
StartWinLevel:

				lea		Score(pc),a6
				move.l	(a6),d0
				lea		PlayerLife(pc),a5
				move.b	(a5),d1

				bsr		ResetQLix

				move.l	d0,(a6)
				move.b	d1,(a5)

				bsr		DisplayLife
				bsr		UpdateText
				rts
				
;=============================================================================
; ResetQLix
;=============================================================================
ResetQLix:
                movem.l d0-d7/a0-a6,-(sp)
				
; Init screen and background for collision
				lea		QLixBackgroundCompressed(pc),a0
				lea		$20000,a1
				bsr		zx0_decompress

				lea		QLixBackgroundCompressed(pc),a0
				move.l	#$28000,a1
				bsr		zx0_decompress

; Init collisions informations
; TODO : Can be highly optimized with movem (but done only once per level at start...)
;COL_INFO_NOTHING	equ		0
;COL_INFO_WALL		equ		1
;COL_INFO_TRACING	equ		2
;COL_INFO_FILLING	equ		3
;COL_INFO_WAY		equ		4
;COL_INFO_WAS_A_WAY	equ		5
COL_BORDER_SIZE equ	6
				lea		QLixCollision(pc),a0
				move.l	#(96*96)/4-1,d7
.ClearCol:
				clr.l	(a0)+ 				; COL_INFO_NOTHING is 0
				dbra	d7,.ClearCol

				lea		QLixCollision(pc),a0
				move.l	#96*2-1,d7	; 2 lines of wall
.WallTop:
				move.b	#COL_INFO_WALL,(a0)+
				dbra	d7,.WallTop

				move.l	#96-1,d7	; 1 lines of way
.WayTop:
				move.b	#COL_INFO_WAY,(a0)+
				dbra	d7,.WayTop
				
				lea		QLixCollision(pc),a0
				add.l	#96*(96-3),a0
				move.l	#96-1,d7	; 1 lines of way
.WayBottom:
				move.b	#COL_INFO_WAY,(a0)+
				dbra	d7,.WayBottom

				move.l	#96*2-1,d7	; 2 lines of wall
.WallBottom:
				move.b	#COL_INFO_WALL,(a0)+
				dbra	d7,.WallBottom

				lea		QLixCollision(pc),a0
				lea		96*2(a0),a0
				move.l	#96-4-1,d7	; 96 lines of border
.Border:
				move.b	#COL_INFO_WALL,(a0)+
				move.b	#COL_INFO_WALL,(a0)+
				move.b	#COL_INFO_WAY,(a0)+
				lea		96-6(a0),a0
				move.b	#COL_INFO_WAY,(a0)+
				move.b	#COL_INFO_WALL,(a0)+
				move.b	#COL_INFO_WALL,(a0)+
				dbra	d7,.Border

; Init player vars
				lea		PlayerMoveInfo(pc),a0
				move.l	#128,SEntityMoveInfo_X(a0)
				move.l	#240-COL_BORDER_SIZE,SEntityMoveInfo_Y(a0)
				move.l	#0,SEntityMoveInfo_NbMove(a0)
				lea		PlayerCoordStartTracing(pc),a0
				move.l	#128,(a0)
				move.l	#240-COL_BORDER_SIZE,4(a0)

				CleanVarB PlayerIsTracing,a0
				CleanVarL FillingCounter,a0
				CleanVarL PreviousFillingCounter,a0
				CleanVarL Score,a0
				CleanVarL PlayerMustDie,a0
				lea		PlayerLife(pc),a0
				move.b	#NB_LIFE_START,(a0)

				lea		PlayerSave(pc),a0
				move.b	#0,56(a0)
				move.b	#0,56+64(a0)					; Invalidate both back buffer


; Timer
				lea		Timer(pc),a0
				move.l	#TIMER_START*256,(a0)
				lea		TimerDisplayed(pc),a0
				move.l	#TIMER_START*256,(a0)

; Init ennemies
				bsr		ResetEnnemiesPosition
				
; Init QLix vars:
				lea		QLixCoord(pc),a0
				move.l	#128*256,(a0)
				move.l	#128*256,4(a0)			; 24:8 format (*256)
				move.l	#132*256,8(a0)
				move.l	#132*256,12(a0)			; 24:8 format (*256)

; Display static texts
				bsr		UpdateText

; Life
				bsr		DisplayLife

                movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; Reset Ennemies Position
;=============================================================================
ResetEnnemiesPosition:
				lea		Ennemy01MoveInfo(pc),a0
				move.l	#34+46,SEntityMoveInfo_X(a0)
				move.l	#47+COL_BORDER_SIZE,SEntityMoveInfo_Y(a0)
				move.l	#0,SEntityMoveInfo_NbMove(a0)
				move.l	#2,SEntityMoveInfo_MoveOff(a0)

				lea		Ennemy01Save(pc),a0
				move.b	#0,56(a0)
				move.b	#0,56+64(a0)					; Invalidate both back buffer

				
				lea		Ennemy02MoveInfo(pc),a0
				move.l	#221-46,SEntityMoveInfo_X(a0)
				move.l	#47+COL_BORDER_SIZE,SEntityMoveInfo_Y(a0)
				move.l	#0,SEntityMoveInfo_NbMove(a0)
				move.l	#0,SEntityMoveInfo_MoveOff(a0)

				lea		Ennemy02Save(pc),a0
				move.b	#0,56(a0)
				move.b	#0,56+64(a0)					; Invalidate both back buffer
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
; from https://www.chibiakumas.com/68000/sinclairql.php

				moveq	#0,d1
				moveq	#1,d2
				move.b	#1<<3,$18021   ; ack frame interrupt
.wait:
				add.l	d2,d1
				btst    #3,$18021		; ...and wait for the next VBL
				beq.s   .wait                   ; (bit 3 only: bits 7..5 always move)

				lea		VBlankTimer(pc),a0
				move.l	d1,(a0)

	if 0
	move.b	#%11111111,$18021    ;Clear interrupt bits
			   moveq	#0,d1
			   moveq	#1,d2
waitVBlankAgain:
				add.l	d2,d1
				move.b	$18021,d0            ;Read in interrupt state
				tst.b	d0                    ;Wait for an interrupt
				beq.s	waitVBlankAgain
				
				lea		VBlankTimer(pc),a0
				move.l	d1,(a0)
	endif
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
ScreenBase:			dc.l	$20000
ScreenBaseFront:	dc.l	$28000
	even

VBlankTimer:		dc.l	0
	even
BufferNum:		dc.w	0
	even
NbLoop:			dc.l	0
	even
Text000:				dc.b	"00% / 75%",0
Text_Score01:			dc.b	"SCORE:"
Text_Score02:			dc.b	"0000000",0
Text_GameOver:			dc.b	"..GAME@OVER..",0
Text_GameOverScore01:	dc.b	"YOUR@SCORE:"
Text_GameOverScore02:	dc.b	"0000000",0
Text_PressSpace:		dc.b	"PRESS@SPACE",0
Text_PressSpaceEmpty:	dc.b	"@@@@@@@@@@@",0
Text_Move:				dc.b	"MOVE WITH ARROWS",0
Text_Trace:				dc.b	"SPACE TO TRACE",0
Text_AvoidEnnemies:		dc.b	"AVOID ENNEMIES",0
Text_AvoidQLix:			dc.b	"AVOID QLIX",0
Text_Bottom01:			dc.b	"          QLIX FOR QL",0
Text_Bottom02:			dc.b	" BY JGL FOR RPUFOS GAMEJAM 2026",0
	even

SpritePlayer_01:	incbin		"Data\QLixPlayer01.bin"
	even
SpritePlayer_02:	incbin		"Data\QLixPlayer02.bin"
	even
SpritePlayer_03:	incbin		"Data\QLixPlayer03.bin"
	even
SpritePlayer_04:	incbin		"Data\QLixPlayer04.bin"
	even

SpriteEnnemy_01:	incbin		"Data\QLixEnnemy01.bin"
	even
SpriteEnnemy_02:	incbin		"Data\QLixEnnemy02.bin"
	even
SpriteEnnemy_03:	incbin		"Data\QLixEnnemy03.bin"
	even
SpriteEnnemy_04:	incbin		"Data\QLixEnnemy04.bin"
	even
SpriteHeart:	incbin			"Data\QLixHeart.bin"
	even
Font:			incbin 		"Data\Font8x8.bin"
	even
LogoRetroProg:			incbin 		"Data\logo.bin.zx0"
	even

PlayerSave:		dcb.b	(2*4+8*6+1+7)*2		; (2 coord.l (x,y) + sprite8x8 shifted (8 lines * 6 bytes) + 1 (is valid, if not cannot be back on screen) + 7 (padding for 64 bytes size)) * 2 framebuffer
	even
Ennemy01Save:	dcb.b	(2*4+8*6+1+7)*2		; (2 coord.l (x,y) + sprite8x8 shifted (8 lines * 6 bytes) + 1 (is valid, if not cannot be back on screen) + 7 (padding for 64 bytes size)) * 2 framebuffer
	even
Ennemy02Save:	dcb.b	(2*4+8*6+1+7)*2		; (2 coord.l (x,y) + sprite8x8 shifted (8 lines * 6 bytes) + 1 (is valid, if not cannot be back on screen) + 7 (padding for 64 bytes size)) * 2 framebuffer
	
	even
	
				dcb.b	2048,0
TopOfStack:
	even

QLixBackgroundCompressed:	incbin		"Data\QLixBackground.bin.zx0"
	even
QLixLogoCompressed:			incbin		"Data\QLixLogo.bin.zx0"
	even

QLixCollision:				dcb.b	(192/2)*(192/2),0
	even


	end
