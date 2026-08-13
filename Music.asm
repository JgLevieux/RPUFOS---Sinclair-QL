; ====================================================================
; LECTEUR MUSICAL MT.IPCOM - SINCLAIR QL (MC68008)
; Version strictement relogeable (PIC - Position Independent Code)
; ====================================================================

;MUSIC_KING equ 1
MUSIC_TETRIS equ 1
;MUSIC_PROUT equ 1
; --------------------------------------------------------------------
; ROUTINE D'INITIALISATION
; Appeler une fois avant de lancer la musique
; a0 = Adresse de la table musicale (ex: Music_Demoscene)
; --------------------------------------------------------------------
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

; --------------------------------------------------------------------
; ROUTINE DE LECTURE (FRAME)
; À appeler à 50 Hz
; --------------------------------------------------------------------
PlayMusic:
        movem.l d0-d3/a0-a3,-(sp)

        lea     Music_Status(pc),a1
        tst.b   (a1)
        beq     .exit               ; Si 0, on quitte

        lea     Music_Timer(pc),a1
        tst.w   (a1)
        bgt.s   .decrement          ; Si oui, on décrémente

.read_next:
        lea     Music_Pointer(pc),a1
        move.l  (a1),a0            ; a0 pointe sur les données de la table
        move.w  (a0)+,d1           ; Lit le Mot 1

        cmp.w   #$FFFF,d1
        beq.s   .stop_music

        cmp.w   #$FF00,d1
        beq.s   .do_silence

.do_sound:
        ; Extraction et écriture des paramètres 
        lea     IPC_Sound_Params(pc),a1
        
        move.b  d1,1(a1)           ; Pitch 2 (Low byte)
        lsr.w   #8,d1
        move.b  d1,0(a1)           ; Pitch 1 (High byte)

        move.w  (a0)+,2(a1)        ; Interval

        move.w  (a0)+,d2           ; Duration
        lea     Music_Timer(pc),a2
        move.w  d2,(a2)            ; Met à jour le timer interne
        move.w  d2,4(a1)           ; Passe la durée au bloc IPC

        move.w  (a0)+,d1           ; Step, Wrap, Rand, Fuzz
        move.b  d1,7(a1)           
        lsr.w   #8,d1
        move.b  d1,6(a1)           

        lea     Music_Pointer(pc),a2
        move.l  a0,(a2)            ; Sauvegarde le pointeur avancé

        lea     IPC_Block_Sound(pc),a3
        moveq   #$11,d0
        trap    #1
        bra.s   .exit

.do_silence:
        ;addq.l  #2,a0              ; Ignore Intervalle
        lea     Music_Timer(pc),a1
        move.w  (a0)+,(a1)         ; Récupère Duration pour le timer interne
        ;addq.l  #2,a0              ; Ignore les paramètres avancés
        
        lea     Music_Pointer(pc),a1
        move.l  a0,(a1)            ; Sauvegarde le pointeur

        lea     IPC_Block_Kill(pc),a3
        moveq   #$11,d0
        trap    #1
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
        
        lea     IPC_Block_Kill(pc),a3
        moveq   #$11,d0
        trap    #1

.exit:
        movem.l (sp)+,d0-d3/a0-a3
        rts

; --------------------------------------------------------------------
; BLOCS DE DONNÉES IPC ET VARIABLES D'ÉTAT
; Inclus dans la section code pour garantir le calcul d'offset (PC)
; --------------------------------------------------------------------
IPC_Block_Sound:
        dc.b    $0A         ; Commande IPC : Initiate Sound
        dc.b    8           ; 8 octets de paramètres
        dc.l    $0000aaaa   ; Masque de bits (INCERTITUDE: vérifier format)
IPC_Sound_Params:
        dc.b    0,0         ; Pitch 1, Pitch 2
        dc.w    0           ; Interval
        dc.w    0           ; Duration
        dc.b    1           ; Step & Wrap
        dc.b    0           ; Rand & Fuzz
        dc.b	1			; No return parameters       
        even

IPC_Block_Kill:
        dc.b    $0B         ; Commande IPC : Kill Sound
        dc.b    0           ; 0 octet de paramètre
        dc.l    $0000aaaa   ; Masque de bits
        dc.b	1			; No return parameters       
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