; Note : Based from sample from https://www.chibiakumas.com/68000/sinclairql.php

SoundTest:
				lea		SoundCommand(pc),a3   ; These three lines
				move.b	#$11,d0    ; Stop the note
				trap	#1
				rts
	even

	SoundCommand:
        dc.b	$A			; Sound Command
        dc.b	8			; Bytes to follow
        dc.l	$0000aaaa	; Byte Parameters
        dc.b	40			; Pitch 1
        dc.b	80			; Pitch 2
        dc.b	8,2			; interval between steps (0,0),
        dc.b	$88,$43     ; duration $1388 = 5000 units
        dc.b	$10			; step in pitch (4bit) / wrap (4bit)
        dc.b	$44			; randomness of step (4bit) / fuzziness (4bit)
        dc.b	1			; No return parameters       
	even

sfx_laser
        dc.b    5,80            ; pitch1+1, pitch2+1 (fast sweep pair)
        dc.b    2,0             ; interval = 2 (lo,hi)
        dc.b    $00,$04         ; duration = $0400 (lo,hi)
        dc.b    $10             ; gradient=1, wrap=0
        dc.b    $00             ; random=0, fuzz=0

FrameBeforeNextSound:	dc.l	0
CurrentNote:			dc.l	0
CurrentMusic:			dc.l	0

;=============================================================================
; Stop sound
;=============================================================================
StopSound:
        lea     SilentCommand(pc),a3
        move.b  #$11,d0
        trap    #1
		rts

;=============================================================================
; Start Music
; a0 = Music adr
;=============================================================================
StartMusic:
		lea		CurrentMusic(pc),a6
		move.l	a0,(a6)

		lea		FrameBeforeNextSound(pc),a0
		lea		CurrentNote(pc),a1
		move.l	#0,(a0)
		move.l	#0,(a1)
		
		rts

;=============================================================================
; Play Music
; a0 = Music adr
;=============================================================================
PlayMusic:
		;DBGBREAK

        lea     CurrentMusic(pc),a2
		tst.l	(a2)
		beq.s	.NoTune
		move.l	(a2),a2

		lea		FrameBeforeNextSound(pc),a0
		move.l	(a0),d0
		bne.s	.EndPlayTune

		lea		CurrentNote(pc),a1
		move.l	(a1),d0
		lsl.l	#2,d0
		add.l	#1,(a1)

		add.l	d0,a2

        move.w  0(a2),d1
        beq.s   .EndOfTune
		moveq	#0,d2
        move.w  2(a2),d2			; Time
		move.l	d2,(a0)

        cmpi.w  #$FFFF,d1			; Silence ?
        beq.s   .silence

        ; --- Préparation et envoi du son ---
        lea     SoundBlock(pc),a3
        move.b  d1,6(a3)             ; Pitch 1
        move.b  d1,7(a3)             ; Pitch 2 

        move.b  #0,10(a3)             
        move.b  d2,11(a3)

        ; Appel système
        move.b  #$11,d0              
        trap    #1
		bra		.EndPlayTune

.silence:
		bsr		StopSound

.EndPlayTune:
		sub.l	#1,(a0)
        rts

.EndOfTune:
		move.l	#0,(a0)
		move.l	#0,(a1)
		rts
.NoTune:
		rts
		
		
    even

SilentCommand:
        dc.b    $B                ; Command byte
        dc.b    0                ;Bytes to follow
        dc.l    $0              ; Send no data
        dc.b    1                ; No return parameters       

	even
SoundBlock:
        dc.b	$A			; Play sound ($B stop sound)
        dc.b	8			; Bytes to follow
        dc.l	$0000aaaa	; Byte Parameters
        dc.b	$20			; Pitch 1
        dc.b	$F0			; Pitch 2
        dc.w	0			; interval between steps (0,0),
        dc.b	50,0		; Duration
        dc.b	$1			; step in pitch (4bit) / wrap (4bit)
        dc.b	$0			; randomness of step (4bit) / fuzziness (4bit)
        dc.b	1			; No return parameters       
    even

; ====================================================================
; DICTIONNAIRE UNIVERSEL DES NOTES - SINCLAIR QL IPC
; Basé sur N_DO_4 = $50 (80 en décimal). Échelle logarithmique.
; Les bémols s'obtiennent en utilisant le dièse de la note précédente.
; ====================================================================

; --- OCTAVE 2 (Extrêmes graves - Limite du registre 8-bits) ---
; Les notes sous le Mi 2 dépassent la valeur $FF (255) et sont impossibles.
N_MI_2      equ $FC ; 252
N_FA_2      equ $F0 ; 240
N_FA_D_2    equ $E4 ; 228 (Fa dièse / Sol bémol)
N_SOL_2     equ $D4 ; 212
N_SOL_D_2   equ $C8 ; 200 (Sol dièse / La bémol)
N_LA_2      equ $C0 ; 192
N_LA_D_2    equ $B4 ; 180 (La dièse / Si bémol)
N_SI_2      equ $A8 ; 168

; --- OCTAVE 3 (Basse standard) ---
N_DO_3      equ $A0 ; 160
N_DO_D_3    equ $98 ; 152 (Do dièse / Ré bémol)
N_RE_3      equ $8E ; 142
N_RE_D_3    equ $86 ; 134 (Ré dièse / Mi bémol)
N_MI_3      equ $7E ; 126
N_FA_3      equ $78 ; 120
N_FA_D_3    equ $72 ; 114 (Fa dièse / Sol bémol)
N_SOL_3     equ $6A ; 106
N_SOL_D_3   equ $64 ; 100 (Sol dièse / La bémol)
N_LA_3      equ $60 ; 96
N_LA_D_3    equ $5A ; 90  (La dièse / Si bémol)
N_SI_3      equ $54 ; 84

; --- OCTAVE 4 (Mélodie centrale - Octave de référence) ---
N_DO_4      equ $50 ; 80
N_DO_D_4    equ $4C ; 76  (Do dièse / Ré bémol)
N_RE_4      equ $47 ; 71
N_RE_D_4    equ $43 ; 67  (Ré dièse / Mi bémol)
N_MI_4      equ $3F ; 63
N_FA_4      equ $3C ; 60
N_FA_D_4    equ $39 ; 57  (Fa dièse / Sol bémol)
N_SOL_4     equ $35 ; 53
N_SOL_D_4   equ $32 ; 50  (Sol dièse / La bémol)
N_LA_4      equ $30 ; 48
N_LA_D_4    equ $2D ; 45  (La dièse / Si bémol)
N_SI_4      equ $2A ; 42

; --- OCTAVE 5 (Aiguës) ---
N_DO_5      equ $28 ; 40
N_DO_D_5    equ $26 ; 38  (Do dièse / Ré bémol)
N_RE_5      equ $24 ; 36
N_RE_D_5    equ $22 ; 34  (Ré dièse / Mi bémol)
N_MI_5      equ $20 ; 32
N_FA_5      equ $1E ; 30
N_FA_D_5    equ $1D ; 29  (Fa dièse / Sol bémol)
N_SOL_5     equ $1B ; 27
N_SOL_D_5   equ $19 ; 25  (Sol dièse / La bémol)
N_LA_5      equ $18 ; 24
N_LA_D_5    equ $17 ; 23  (La dièse / Si bémol)
N_SI_5      equ $15 ; 21

; --- OCTAVE 6 (Très aiguës - Attention à la justesse matérielle) ---
; Les valeurs deviennent si petites que l'arrondi crée des fausses notes.
N_DO_6      equ $14 ; 20
N_DO_D_6    equ $13 ; 19
N_RE_6      equ $12 ; 18
N_RE_D_6    equ $11 ; 17
N_MI_6      equ $10 ; 16
N_FA_6      equ $0F ; 15
N_FA_D_6    equ $0E ; 14
N_SOL_6     equ $0D ; 13
N_SOL_D_6   equ $0C ; 12 (Identique au La !)
N_LA_6      equ $0C ; 12 (Identique au Sol# !)
N_LA_D_6    equ $0B ; 11 (Identique au Si !)
N_SI_6      equ $0B ; 11 (Identique au La# !)

; Constantes de contrôle de lecture
SILENCE     equ $FFFF
FIN         equ $0000

	even
Music_GameStart:
    ; --- Arpège rapide (Do Majeur) ---
    dc.w N_SOL_3, 6, SILENCE, 2
    dc.w N_DO_4, 6, SILENCE, 2
    dc.w N_MI_4, 6, SILENCE, 2
    dc.w N_SOL_4, 6, SILENCE, 2
    
    ; --- Relance courte ---
    dc.w N_MI_4, 6, SILENCE, 2
    dc.w N_SOL_4, 6, SILENCE, 2
    
    ; --- Point d'orgue aigu (Résolution) ---
    dc.w N_DO_5, 25, SILENCE, 2
    
    ; --- Marqueur de fin ---
    dc.w FIN, 0

Music_LifeLost:
    ; --- Descente chromatique ralentissante ---
    dc.w N_SOL_3, 6, SILENCE, 2    ; 8 unités
    dc.w N_FA_D_3, 8, SILENCE, 2   ; 10 unités
    dc.w N_FA_3, 10, SILENCE, 2    ; 12 unités
    
    ; --- Suspension ---
    dc.w N_MI_3, 15, SILENCE, 10   ; 25 unités
    
    ; --- Chute finale extrême grave ---
    dc.w N_MI_2, 35                ; 35 unités
    
    ; --- Marqueur de fin ---
    dc.w FIN, 0

Music_GameOver:
    ; --- Première descente chromatique (Durée : 2,9s / 145 unités) ---
    dc.w N_SOL_4, 20, SILENCE, 5   ; 0.5s
    dc.w N_FA_D_4, 20, SILENCE, 5  ; 0.5s
    dc.w N_FA_4, 20, SILENCE, 5    ; 0.5s
    dc.w N_MI_4, 45, SILENCE, 5    ; 1.0s
    dc.w SILENCE, 15               ; Pause dramatique (0.3s)

    ; --- Deuxième descente chromatique, plus grave (Durée : 3,3s / 165 unités) ---
    dc.w N_RE_4, 20, SILENCE, 5    ; 0.5s
    dc.w N_DO_D_4, 20, SILENCE, 5  ; 0.5s
    dc.w N_DO_4, 45, SILENCE, 5    ; 1.0s
    dc.w N_SI_3, 45, SILENCE, 5    ; 1.0s
    dc.w SILENCE, 15               ; Pause dramatique (0.3s)

    ; --- Note finale fatale et coupure nette (Durée : 1,5s / 75 unités) ---
    dc.w N_LA_3, 75                ; 1.5s soutenu, sans silence de détachement final
    
    ; --- Marqueur de fin ---
    dc.w FIN, 0
	
Music_OdeALaJoie:
Music_OdeALaJoie_Fast:
    ; =========================================================
    ; THEME A (Mesures 1 à 4)
    ; =========================================================
    ; Mesure 1 : Mi, Mi, Fa, Sol
    dc.w N_MI_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_FA_4,16, SILENCE,4, N_SOL_4,16, SILENCE,4
    ; Mesure 2 : Sol, Fa, Mi, Ré
    dc.w N_SOL_4,16, SILENCE,4, N_FA_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_RE_4,16, SILENCE,4
    ; Mesure 3 : Do, Do, Ré, Mi
    dc.w N_DO_4,16, SILENCE,4, N_DO_4,16, SILENCE,4, N_RE_4,16, SILENCE,4, N_MI_4,16, SILENCE,4
    ; Mesure 4 : Mi (noire pointée), Ré (croche), Ré (blanche)
    dc.w N_MI_4,25, SILENCE,5, N_RE_4,7, SILENCE,3, N_RE_4,35, SILENCE,5

    ; =========================================================
    ; THEME A' (Mesures 5 à 8)
    ; =========================================================
    ; Mesure 5 : Mi, Mi, Fa, Sol
    dc.w N_MI_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_FA_4,16, SILENCE,4, N_SOL_4,16, SILENCE,4
    ; Mesure 6 : Sol, Fa, Mi, Ré
    dc.w N_SOL_4,16, SILENCE,4, N_FA_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_RE_4,16, SILENCE,4
    ; Mesure 7 : Do, Do, Ré, Mi
    dc.w N_DO_4,16, SILENCE,4, N_DO_4,16, SILENCE,4, N_RE_4,16, SILENCE,4, N_MI_4,16, SILENCE,4
    ; Mesure 8 : Ré (noire pointée), Do (croche), Do (blanche)
    dc.w N_RE_4,25, SILENCE,5, N_DO_4,7, SILENCE,3, N_DO_4,35, SILENCE,5

    ; =========================================================
    ; THEME B - Le Pont (Mesures 9 à 12)
    ; =========================================================
    ; Mesure 9 : Ré, Ré, Mi, Do
    dc.w N_RE_4,16, SILENCE,4, N_RE_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_DO_4,16, SILENCE,4
    ; Mesure 10 : Ré, Mi/Fa (croches), Mi, Do
    dc.w N_RE_4,16, SILENCE,4, N_MI_4,7, SILENCE,3, N_FA_4,7, SILENCE,3, N_MI_4,16, SILENCE,4, N_DO_4,16, SILENCE,4
    ; Mesure 11 : Ré, Mi/Fa (croches), Mi, Ré
    dc.w N_RE_4,16, SILENCE,4, N_MI_4,7, SILENCE,3, N_FA_4,7, SILENCE,3, N_MI_4,16, SILENCE,4, N_RE_4,16, SILENCE,4
    ; Mesure 12 : Do, Ré, Sol (octave inférieure)
    dc.w N_DO_4,16, SILENCE,4, N_RE_4,16, SILENCE,4, N_SOL_3,35, SILENCE,5

    ; =========================================================
    ; THEME A' (Mesures 13 à 16) - Conclusion
    ; =========================================================
    ; Mesure 13 : Mi, Mi, Fa, Sol
    dc.w N_MI_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_FA_4,16, SILENCE,4, N_SOL_4,16, SILENCE,4
    ; Mesure 14 : Sol, Fa, Mi, Ré
    dc.w N_SOL_4,16, SILENCE,4, N_FA_4,16, SILENCE,4, N_MI_4,16, SILENCE,4, N_RE_4,16, SILENCE,4
    ; Mesure 15 : Do, Do, Ré, Mi
    dc.w N_DO_4,16, SILENCE,4, N_DO_4,16, SILENCE,4, N_RE_4,16, SILENCE,4, N_MI_4,16, SILENCE,4
    ; Mesure 16 : Ré (noire pointée), Do (croche), Do (blanche)
    dc.w N_RE_4,25, SILENCE,5, N_DO_4,7, SILENCE,3, N_DO_4,35, SILENCE,5

    ; --- Marqueur de fin ---
    dc.w FIN, 0

	even
