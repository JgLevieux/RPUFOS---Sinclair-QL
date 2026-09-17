	even
	include "sk_ipc.asm"
	even

;MUSIC_KING equ 1
MUSIC_TETRIS equ 1
;MUSIC_PROUT equ 1

StartMusic:
        lea     Music_Pointer(pc),a1
        move.l  a0,(a1)
        lea     Music_PointerSave(pc),a1
        move.l  a0,(a1)
        lea     Music_Timer(pc),a1
        clr.w   (a1)
        lea     Music_Status(pc),a1
        move.b  #1,(a1)
        rts

PlayMusic:
        movem.l d0-d6/a0-a3,-(sp)

        lea     Music_Status(pc),a1
        tst.b   (a1)
        beq     .exit               ; Si 0, on quitte

        lea     Music_Timer(pc),a1
        tst.w   (a1)
        bgt.s   .decrement          ; Si oui, on décrémente

.read_next:
        lea     Music_Pointer(pc),a1
        move.l  (a1),a0            ; a0 pointe sur les données de la table
        move.w  (a0)+,d0           ; Pitch 1 & 2 or END or SILENCE

        cmp.w   #CMD_END,d0
        beq.s   .stop_music

        cmp.w   #CMD_SILENCE,d0
        beq.s   .do_silence

.do_sound:
        move.w  (a0)+,d6           ; Interval
        move.w  (a0)+,d7			; Duration
        lea     Music_Timer(pc),a2
        move.w  d7,(a2)            ; Met à jour le timer interne
		
        move.w  (a0)+,d1           ; Step & Wrap & Rand & Fuzz
		move.w	d1,d2
		and.w	#$F,d2				; Fuzz
		lsr.w	#4,d1
		move.w	d1,d3
		and.w	#$F,d3				; Rand
		lsr.w	#4,d1
		move.w	d1,d4
		and.w	#$F,d4				; Wrap
		lsr.w	#4,d1
		move.w	d1,d5
		and.w	#$F,d5				; Step

        lea     Music_Pointer(pc),a2
        move.l  a0,(a2)            ; Sauvegarde le pointeur avancé

		bsr		SndTone
		
        bra.s   .exit

.do_silence:
        ;addq.l  #2,a0              ; Ignore Intervalle
        lea     Music_Timer(pc),a1
        move.w  (a0)+,(a1)         ; Récupère Duration pour le timer interne
        
        lea     Music_Pointer(pc),a1
        move.l  a0,(a1)            ; Sauvegarde le pointeur

		bsr		SndSilence
        bra.s   .exit

.decrement:
        lea     Music_Timer(pc),a1
        subq.w  #1,(a1)
        bra.s   .exit

.stop_music:
        lea     Music_Timer(pc),a1
        clr.w   (a1)
        lea     Music_Pointer(pc),a1
        lea     Music_PointerSave(pc),a0
		move.l	(a0),(a1)
        
		bsr		SndSilence

.exit:
        movem.l (sp)+,d0-d6/a0-a3
        rts


SndTone:
                lea     SndPrm(pc),a3
                move.w  d0,d1
                andi.w  #$F,d1
                move.b  d1,SND_PARAM_PITCH_2_LBYTE(a3)

				lsr.w	#4,d0
                move.w  d0,d1
                andi.w  #$F,d1
                move.b  d1,SND_PARAM_PITCH_2_HBYTE(a3)

				lsr.w	#4,d0
                move.w  d0,d1
                andi.w  #$F,d1
                move.b  d1,SND_PARAM_PITCH_1_LBYTE(a3)

				lsr.w	#4,d0
                move.w  d0,d1
                andi.w  #$F,d1
                move.b  d1,SND_PARAM_PITCH_1_HBYTE(a3)
				
				move.b	d6,SND_PARAM_STEP_INTERVAL_1_LBYTE(a3)

				move.b	d7,SND_PARAM_DURATION_2_LBYTE(a3)

				
                move.b  d5,SND_PARAM_STEP(a3)
                move.b  d4,SND_PARAM_WRAP(a3)
                move.b  d3,SND_PARAM_RANDOM(a3)
                move.b  d2,SND_PARAM_FUZZ(a3)
                bsr     IpcStart
                moveq   #IPC_BEEP,d0
                bsr     IpcNibble
                lea     SndPrm(pc),a3
                moveq   #16-1,d3
.nib:
                move.b  (a3)+,d0
                bsr     IpcNibble
                dbra    d3,.nib
                bra     IpcEnd

SndSilence:
                bsr     IpcStart
                moveq   #IPC_KILLSND,d0
                bsr     IpcNibble
                bra     IpcEnd

                even

SND_PARAM_PITCH_1_HBYTE				equ		0
SND_PARAM_PITCH_1_LBYTE				equ		1
SND_PARAM_PITCH_2_HBYTE				equ		2
SND_PARAM_PITCH_2_LBYTE				equ		3

SND_PARAM_STEP_INTERVAL_1_HBYTE		equ		4
SND_PARAM_STEP_INTERVAL_1_LBYTE		equ		5
SND_PARAM_STEP_INTERVAL_2_HBYTE		equ		6
SND_PARAM_STEP_INTERVAL_2_LBYTE		equ		7

SND_PARAM_DURATION_1_HBYTE			equ		8
SND_PARAM_DURATION_1_LBYTE			equ		9
SND_PARAM_DURATION_2_HBYTE			equ		10
SND_PARAM_DURATION_2_LBYTE			equ		11

SND_PARAM_STEP						equ		12
SND_PARAM_WRAP						equ		13
SND_PARAM_RANDOM					equ		14
SND_PARAM_FUZZ						equ		15
				
SndPrm:
                dc.b    0,0                     ; pitch    : SndTone fills these four
                dc.b    0,0                     ; pitch_2
                dc.b    0,0                     ; step interval, low byte  : no slide
                dc.b    0,0                     ; step interval, high byte
                dc.b    0,0                     ; duration, low byte
                dc.b    0,0                     ; duration, high byte
                dc.b    0,0                     ; pitch step, wrap
                dc.b    0,0                     ; random, and fuzz which SndTone fills
                even

		
Music_Pointer:
        dc.l    0           ; Pointeur actuel dans la table
Music_PointerSave:
        dc.l    0           ; Pointeur actuel dans la table
Music_Timer:
        dc.w    0           ; Compte à rebours avant événement
Music_Status:
        dc.b    0           ; 1 = Lecture en cours, 0 = Arrêté
        even

		
 ifd MUSIC_TETRIS
; =====================================================================
; LECTEUR MT.IPCOM - KOROBEINIKI (TETRIS THEME) - FORMAT SILENCE 4 OCTETS
; Format des notes : 8 octets (Pitch1_2, Interval, Duration, Step_Wrap_Rand_Fuzz)
; Format des silences : 4 octets (CMD_SILENCE, Duration)
; =====================================================================

I_LEAD  equ $0000   ; Onde carrée pure
I_BASS  equ $0006   ; Onde grave saturée (Fuzz=6)
I_KICK  equ $6018   ; Percussion : Pitch drop (Step=6) + Bruit (Rand=1/Fuzz=8)
I_SNARE equ $804A   ; Caisse claire saturée (Step=8, Rand=4, Fuzz=A)
I_ARP   equ $4100   ; Arpège 8-bits matériel (Step=4, Wrap=1)
I_MAD   equ $512C   ; Bruit de destruction 

CMD_SILENCE equ $FF00
CMD_END     equ $FFFF

Music_Demoscene:
    ; =====================================================================
    ; PARTIE 1 : INTRO BASS & DRUMS (12.8s / 640 ticks)
    ; =====================================================================
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    ; Mesures 5 à 8 (Répétition Intro)
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $7E7E,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $6060,0,5,I_BASS, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5

    ; =====================================================================
    ; PARTIE 2 : THEME A & B EN MULTIPLEXAGE (25.6s / 1280 ticks)
    ; =====================================================================
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $60F0,1,5,I_KICK, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $40A0,2,5,I_SNARE, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1E1E,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $1818,0,5,I_LEAD, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1A1A,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $1E1E,0,5,I_LEAD, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $40A0,2,5,I_SNARE, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5

    ; Répétition Partie 2
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $60F0,1,5,I_KICK, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $40A0,2,5,I_SNARE, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $1E1E,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $1818,0,5,I_LEAD, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $1A1A,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $1E1E,0,5,I_LEAD, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2A2A,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2323,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w $1F1F,0,5,I_LEAD, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $2828,0,5,I_LEAD, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $3030,0,5,I_LEAD, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5 
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5 
    dc.w $40A0,2,5,I_SNARE, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5 

    ; PARTIE 3 : ARPEGE MATERIEL (12.8s / 640 ticks)
    dc.w $1F3F,1,5,I_ARP, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A4A,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2343,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A4A,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $3050,1,5,I_ARP, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $3050,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1F3F,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2343,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $2A4A,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A4A,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2343,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $1F3F,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $3050,1,5,I_ARP, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $3050,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $60F0,1,5,I_KICK, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $40A0,2,5,I_SNARE, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    dc.w $2343,1,5,I_ARP, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1E3E,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $1838,1,5,I_ARP, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1A3A,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $1E3E,1,5,I_ARP, CMD_SILENCE,5, $4747,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1F3F,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5
    dc.w $1F3F,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $2343,1,5,I_ARP, CMD_SILENCE,5, $5050,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $2A4A,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2A4A,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2343,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w $1F3F,1,5,I_ARP, CMD_SILENCE,5, $7E7E,0,5,I_BASS, CMD_SILENCE,5
    dc.w $2848,1,5,I_ARP, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w $3050,1,5,I_ARP, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $3050,1,5,I_ARP, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $6060,0,5,I_BASS, CMD_SILENCE,5
    dc.w $40A0,2,5,I_SNARE, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5

    ; PARTIE 4 : OUTRO CHAOS (12.8s / 640 ticks)
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $60F0,1,5,I_KICK, CMD_SILENCE,5
    dc.w CMD_SILENCE,5, CMD_SILENCE,5, $40A0,2,5,I_SNARE,CMD_SILENCE,5
    
    ; Note finale de destruction (160 ticks = 3.2s)
    ;dc.w $10C0, 8, 160, I_MAD
	dc.w CMD_SILENCE,25

    dc.w CMD_END, 0, 0, 0
	endif
		
 ifd MUSIC_KING
; =====================================================================
; MASQUES D'INSTRUMENTS DEMOSCENE - THEME DU ROI DE LA MONTAGNE
; =====================================================================
I_BASS_STAC equ $0006   ; Onde carrée dure, courte (Fuzz=6)
I_LEAD_FUZZ equ $0002   ; Onde mélodique perçante (Fuzz=2)
I_KICK      equ $6018   ; Chute abrupte (Step=6) + Bruit (Rand=1, Fuzz=8)
I_SNARE     equ $804A   ; Caisse claire saturée (Step=8, Rand=4, Fuzz=A)
I_HARD_ARP  equ $4100   ; Balayage cyclique matériel (Step=4, Wrap=1)
I_MADNESS   equ $514E   ; Chaos total (Step=5, Wrap=1, Rand=4, Fuzz=E)

CMD_SILENCE equ $FF00
CMD_END     equ $FFFF

Music_Demoscene:
    ; =====================================================================
    ; PARTIE 1 : THEME STACCATO PUR (7.68 secondes / 384 ticks)
    ; Durées strictes : Croche = 10 ticks + 2 silence. Noire = 20 + 4.
    ; =====================================================================
    ; Mesure 1
    dc.w $5454, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Si3
    dc.w $4B4B, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Do#4
    dc.w $4747, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Ré4
    dc.w $3F3F, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Mi4
    dc.w $3838, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Fa#4
    dc.w $4747, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Ré4
    dc.w $3838, 0, 20, I_BASS_STAC, CMD_SILENCE,4  ; Fa#4 (Noire)
    ; Mesure 2
    dc.w $3F3F, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Mi4
    dc.w $4B4B, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Do#4
    dc.w $3F3F, 0, 20, I_BASS_STAC, CMD_SILENCE,4  ; Mi4 (Noire)
    dc.w $4343, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Ré#4
    dc.w $5454, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Si3
    dc.w $4343, 0, 20, I_BASS_STAC, CMD_SILENCE,4  ; Ré#4 (Noire)
    ; Mesure 3 (Identique Mesure 1)
    dc.w $5454, 0, 10, I_BASS_STAC, CMD_SILENCE,2  
    dc.w $4B4B, 0, 10, I_BASS_STAC, CMD_SILENCE,2  
    dc.w $4747, 0, 10, I_BASS_STAC, CMD_SILENCE,2  
    dc.w $3F3F, 0, 10, I_BASS_STAC, CMD_SILENCE,2  
    dc.w $3838, 0, 10, I_BASS_STAC, CMD_SILENCE,2  
    dc.w $4747, 0, 10, I_BASS_STAC, CMD_SILENCE,2  
    dc.w $3838, 0, 20, I_BASS_STAC, CMD_SILENCE,4  
    ; Mesure 4 (Descente finale)
    dc.w $2A2A, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Si4
    dc.w $3030, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; La4
    dc.w $3838, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Fa#4
    dc.w $4747, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Ré4
    dc.w $4B4B, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Do#4
    dc.w $3F3F, 0, 10, I_BASS_STAC, CMD_SILENCE,2  ; Mi4
    dc.w $5454, 0, 20, I_BASS_STAC, CMD_SILENCE,4  ; Si3

    ; =====================================================================
    ; PARTIE 2 : MULTIPLEXAGE KICK DRUM (7.68 secondes / 384 ticks)
    ; Les silences sont remplacés par des frappes de grosse caisse.
    ; =====================================================================
    ; Mesure 1
    dc.w $5454, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3F3F, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 12, I_BASS_STAC, $60F0, 1, 12, I_KICK
    ; Mesure 2
    dc.w $3F3F, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3F3F, 0, 12, I_BASS_STAC, $60F0, 1, 12, I_KICK
    dc.w $4343, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $5454, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4343, 0, 12, I_BASS_STAC, $60F0, 1, 12, I_KICK
    ; Mesure 3
    dc.w $5454, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3F3F, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 12, I_BASS_STAC, $60F0, 1, 12, I_KICK
    ; Mesure 4
    dc.w $2A2A, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3030, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $3F3F, 0, 6, I_BASS_STAC, $60F0, 1, 6, I_KICK
    dc.w $5454, 0, 12, I_BASS_STAC, $60F0, 1, 12, I_KICK

    ; =====================================================================
    ; PARTIE 3 : LEAD SYNTH & SNARE (7.68 secondes / 384 ticks)
    ; Changement de timbre (I_LEAD_FUZZ) et introduction de la caisse claire.
    ; =====================================================================
    ; Mesure 1
    dc.w $5454, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $3F3F, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 12, I_LEAD_FUZZ, $80A0, 2, 12, I_SNARE
    ; Mesure 2
    dc.w $3F3F, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3F3F, 0, 12, I_LEAD_FUZZ, $80A0, 2, 12, I_SNARE
    dc.w $4343, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $5454, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4343, 0, 12, I_LEAD_FUZZ, $80A0, 2, 12, I_SNARE
    ; Mesure 3
    dc.w $5454, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $3F3F, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4747, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 12, I_LEAD_FUZZ, $80A0, 2, 12, I_SNARE
    ; Mesure 4
    dc.w $2A2A, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3030, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $4747, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $4B4B, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $3F3F, 0, 6, I_LEAD_FUZZ, $60F0, 1, 6, I_KICK
    dc.w $5454, 0, 12, I_LEAD_FUZZ, $80A0, 2, 12, I_SNARE

    ; =====================================================================
    ; PARTIE 4 : ARPEGES MATERIELS (7.68 secondes / 384 ticks)
    ; Remplacement des notes par I_HARD_ARP (Balayage matériel dissonant)
    ; =====================================================================
    ; Mesure 1
    dc.w $5484, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4B7B, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4777, 2, 6, I_HARD_ARP, $80A0, 2, 6, I_SNARE
    dc.w $3F6F, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3868, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4777, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3868, 2, 12, I_HARD_ARP, $80A0, 2, 12, I_SNARE
    ; Mesure 2
    dc.w $3F6F, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4B7B, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3F6F, 2, 12, I_HARD_ARP, $80A0, 2, 12, I_SNARE
    dc.w $4373, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $5484, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4373, 2, 12, I_HARD_ARP, $80A0, 2, 12, I_SNARE
    ; Mesure 3
    dc.w $5484, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4B7B, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4777, 2, 6, I_HARD_ARP, $80A0, 2, 6, I_SNARE
    dc.w $3F6F, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3868, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4777, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3868, 2, 12, I_HARD_ARP, $80A0, 2, 12, I_SNARE
    ; Mesure 4
    dc.w $2A5A, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3060, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3868, 2, 6, I_HARD_ARP, $80A0, 2, 6, I_SNARE
    dc.w $4777, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $4B7B, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $3F6F, 2, 6, I_HARD_ARP, $60F0, 1, 6, I_KICK
    dc.w $5484, 2, 12, I_HARD_ARP, $80A0, 2, 12, I_SNARE

    ; =====================================================================
    ; PARTIE 5 : ACCELERANDO DOUBLE VITESSE (7.68 secondes / 384 ticks)
    ; Le motif de 4 mesures est joué 2 fois. Les ticks sont divisés par 2.
    ; =====================================================================
Part5_Loop:
    ; Boucle interne répétée 2 fois (2 x 192 ticks = 384 ticks)
    ; Mesure 1 (Rapide)
    dc.w $5454, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    ; Mesure 2 (Rapide)
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $4343, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4343, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    ; Mesure 3 (Rapide)
    dc.w $5454, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    ; Mesure 4 (Rapide)
    dc.w $2A2A, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3030, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_LEAD_FUZZ, $80A0, 2, 3, I_SNARE
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    
    ; --- Seconde itération de la Partie 5 ---
    dc.w $5454, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $4343, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4343, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $5454, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE
    dc.w $2A2A, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3030, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_LEAD_FUZZ, $80A0, 2, 3, I_SNARE
    dc.w $4747, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 3, I_LEAD_FUZZ, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 6, I_LEAD_FUZZ, $80A0, 2, 6, I_SNARE

    ; =====================================================================
    ; PARTIE 6 : CHAOS (7.68 secondes / 384 ticks)
    ; Double vitesse conservée, utilisation de I_MADNESS (Fuzz extrême)
    ; =====================================================================
    ; Boucle 1 (192 ticks)
    dc.w $5454, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $4343, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4343, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $5454, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $2A2A, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3030, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_MADNESS, $80A0, 2, 3, I_SNARE
    dc.w $4747, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    ; Boucle 2 (192 ticks)
    dc.w $5454, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $4343, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4343, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $5454, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $80A0, 2, 3, I_SNARE
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4747, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE
    dc.w $2A2A, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3030, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3838, 0, 3, I_MADNESS, $80A0, 2, 3, I_SNARE
    dc.w $4747, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $4B4B, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $3F3F, 0, 3, I_MADNESS, $60F0, 1, 3, I_KICK
    dc.w $5454, 0, 6, I_MADNESS, $80A0, 2, 6, I_SNARE

    ; =====================================================================
    ; PARTIE 7 : BREAKDOWN (7.68 secondes / 384 ticks)
    ; Retour à la vitesse normale, batterie seule, puis accord final tenu
    ; =====================================================================
    ; Mesures 1 à 3 (Batterie pure sur le motif rythmique)
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $80A0, 2, 6, I_SNARE
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 12, $80A0, 2, 12, I_SNARE
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 12, $80A0, 2, 12, I_SNARE
    dc.w CMD_SILENCE, 6,  $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6,  $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 12, $80A0, 2, 12, I_SNARE
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $80A0, 2, 6, I_SNARE
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 6, $60F0, 1, 6, I_KICK
    dc.w CMD_SILENCE, 12, $80A0, 2, 12, I_SNARE
    
    ; =====================================================================
    ; PARTIE 8 : OUTRO "GAME OVER" (7.68 secondes / 384 ticks)
    ; Alarme matérielle destructrice simulant la capture par les Trolls.
    ; =====================================================================
    ; Accord d'alarme glissant (Wrap) maintenu sur 384 ticks (7.68s)
    ;dc.w $30F0, 8, 100, I_MADNESS
 
    ; =====================================================================
    ; FIN DE LA PISTE (Total : 61.44 secondes)
    ; =====================================================================
    dc.w CMD_END, 0, 0, 0

	endif

	ifd MUSIC_PROUT

; =====================================================================
; MASQUES D'INSTRUMENTS AVANCES (Format : Step/Wrap | Rand/Fuzz)
; =====================================================================
I_GLIDE     equ $2000   ; Lead mélodique : glisse vers la cible (Step=2)
I_BASS      equ $0006   ; Basse statique : saturée pour la profondeur (Fuzz=6)
I_KICK      equ $6018   ; Grosse caisse : chute de pitch (Step=6) + Bruit et Fuzz
I_SNARE     equ $804C   ; Caisse claire : chute abrupte (Step=8) + Fort Bruit
I_ARP       equ $5100   ; Arpège matériel pour le pont (Step=5, Wrap=1)

CMD_SILENCE equ $FF00
CMD_END     equ $FFFF

Music_Demoscene:
    ; =====================================================================
    ; PARTIE 1 : THEME PRINCIPAL - BASS & LEAD (12.8 Secondes / 640 ticks)
    ; Progression: Am -> F -> C -> G
    ; =====================================================================
    ; Motif 1 : La Mineur (Basse A3 = $60)
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead G4->A4
    dc.w $3028,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead A4->C5
    dc.w $282A,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead C5->B4
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead F4->G4
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead G4->A4
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead D4->E4
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead F4->G4
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 ; Lead B3->C4
    
    ; Motif 2 : Fa Majeur (Basse F3 = $)
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead E4->F4
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead G4->A4
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead F4->G4
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead D4->E4
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead E4->F4
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead B3->C4
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead D4->E4
    dc.w $6054,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 ; Lead A3->B3

    ; Motif 3 : Do Majeur (Basse C3 = $)
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead B4->C5
    dc.w $2420,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead D5->E5
    dc.w $2824,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead C5->D5
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead A4->B4
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead B4->C5
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead F4->G4
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead A4->B4
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 ; Lead G4->A4

    ; Motif 4 : Sol Majeur (Basse G3 = A)
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead F4->G4
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead A4->B4
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead G4->A4
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead E4->F4
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead F4->G4
    dc.w $5047,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead C4->D4
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead E4->F4
    dc.w $6A60,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 ; Lead G3->A3

    ; Répétition intégrale de la Partie
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3028,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $282A,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $6054,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2420,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2824,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5047,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $6A60,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 

    ; =====================================================================
    ; PARTIE 2 : DRUMS & LEAD (12.8 Secondes / 640 ticks)
    ; La basse est remplacée par le beat (Kick / Snare)
    ; =====================================================================
    ; Motif 1 (Am) avec Batterie
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $3028,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $282A,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    
    ; Motif 2 (F) avec Batterie
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK,  CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $6054,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; Motif 3 (C) avec Batterie
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2420,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2824,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; Motif 4 (G) avec Batterie
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $5047,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $6A60,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; Répétition Partie 2
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3028,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $282A,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $6054,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2420,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2824,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $5047,2,4,I_GLIDE, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $6A60,2,4,I_GLIDE, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; =====================================================================
    ; PARTIE 3 : DRUMS & ARPEGES MATERIELS (12.8 Secondes)
    ; La mélodie laisse place à des accords générés par le Wrap (I_ARP)
    ; =====================================================================
    ; Mesures 17-18 (La Mineur Arpégé)
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $4060,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    
    ; Mesures 19-20 (Fa Majeur Arpégé)
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $3C78,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; Mesures 21-22 (Do Majeur Arpégé)
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $2850,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; Mesures 23-24 (Sol Majeur Arpégé)
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $70C0,2,4,I_KICK, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 
    dc.w $356A,2,4,I_ARP, CMD_SILENCE,1, $5090,2,4,I_SNARE, CMD_SILENCE,1 

    ; =====================================================================
    ; PARTIE 4 & 5 : INTENSITE MAXIMALE ET FIN (25.6 Secondes)
    ; Reprise de la Partie 1 (Basse & Mélodie) suivie d'un accord final long.
    ; =====================================================================
    ; Répétition Partie 1 (Basse & Mélodie)
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3028,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $282A,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $6054,2,4,I_GLIDE, CMD_SILENCE,1, $7878,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2420,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2824,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $2A28,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $A0A0,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $302A,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5047,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3F3C,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $6A60,2,4,I_GLIDE, CMD_SILENCE,1, $6A6A,0,4,I_BASS, CMD_SILENCE,1 

    ; Répétition finale (Am) pour boucler la progression
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3028,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $282A,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3530,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $473F,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $3C35,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 
    dc.w $5450,2,4,I_GLIDE, CMD_SILENCE,1, $6060,0,4,I_BASS, CMD_SILENCE,1 

    ; Accord final d'arrêt (La mineur matériel) maintenu 1 seconde (50 ticks)
    ;dc.w $3060,4,50,I_ARP, CMD_SILENCE,10
    
    ; Fin
    dc.w CMD_END, 0, 0, 0
	endif