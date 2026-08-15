ColorPixelBlack		equ		$0000
ColorPixelBlue		equ		$0040
ColorPixelRed		equ		$0080
ColorPixelMagenta	equ		$00C0
ColorPixelGreen		equ		$8000
ColorPixelCyan		equ		$8040
ColorPixelYellow	equ		$8080
ColorPixelWhite		equ		$80C0

; G0 F0 G1 F1 G2 F2 G3 F3
; R0 B0 R1 B1 R2 B2 R3 B3
; =============================================================================
; PlotPixel 8 colors mode
; Input :
; 		d0 = X (0-255)
;		d1 = Y (0-255)
;		d2 = Color
;		a4 = ScreenBase
; Output : -
; Destroy : 
;		d0, d1, d2, d3
;		a0
; =============================================================================
PlotPixel:
				move.l	a4,a0
				
                move.w  d2,d3               ; d3 = Couleur (0-7)
                
                ; --- Calcul de l'adresse du mot horizontal (X) ---
                move.w  d0,d2               ; d2 = Copie de X
                lsr.w   #1,d2               ; d2 = X / 2
                andi.w  #$007E,d2           ; Force l'alignement sur un mot pair
                adda.w  d2,a0               ; a0 pointe sur le bon mot horizontal
                
                ; --- Calcul de l'adresse de la ligne verticale (Y) ---
                move.w  d1,d2               ; d2 = Copie de Y
                lsl.w   #7,d2               ; d2 = Y * 128 octets par ligne
                adda.w  d2,a0               ; a0 = Adresse mémoire finale du mot cible
                
                ; --- Préparation des masques de couleur ---
                lsl.w   #6,d3
                move.w  d3,d2
                lsl.w   #7,d2
                andi.w  #$8000,d2           ; Isole le bit Vert (Bit 15)
                andi.w  #$00C0,d3           ; Isole les bits Rouge et Bleu (Bits 7 et 6)
                or.w    d2,d3               ; d3 = Pixel brut configuré pour la position 0
                
                ; --- Positionnement intra-mot (Pixel 0, 1, 2 ou 3) ---
                andi.w  #3,d0               ; d0 = X modulo 4
                add.w   d0,d0               ; d0 = Facteur de rotation (0, 2, 4 ou 6 bits)
                
                ; --- Application directe avec correction du masque ---
                move.w  #$3F3F,d2           ; Correction : Nettoie TOUS les bits du pixel (y compris le Flash)
                ror.w   d0,d3               ; Décale les bits de couleur à la bonne position
                ror.w   d0,d2               ; Décale le masque de nettoyage à la bonne position
                
                and.w   d2,(a0)             ; Effacement chirurgical de l'ancien pixel
                or.w    d3,(a0)             ; Injection de la nouvelle couleur
                rts

; =============================================================================
; GetPixel 8 colors mode
; Input :
; 		d0 = X (0-255)
;		d1 = Y (0-255)
;		a4 = ScreenBase
; Output : -
;		d2 = Color
; Destroy : 
;		d0, d1, d2
;		a0
; =============================================================================

GetPixel:
				move.l	a4,a0
				
                ; --- Calcul de l'adresse du mot horizontal (X) ---
                move.w  d0,d2               ; d2 = Copie de X
                lsr.w   #1,d2               ; d2 = X / 2
                andi.w  #$007E,d2           ; Force l'alignement sur un mot pair
                adda.w  d2,a0               ; a0 pointe sur le bon mot horizontal
                
                ; --- Calcul de l'adresse de la ligne verticale (Y) ---
                move.w  d1,d2               ; d2 = Copie de Y
                lsl.w   #7,d2               ; d2 = Y * 128 octets par ligne
                adda.w  d2,a0               ; a0 = Adresse mémoire finale du mot cible
                
                ; --- Positionnement intra-mot (Pixel 0, 1, 2 ou 3) ---
                andi.w  #3,d0               ; d0 = X modulo 4
                add.w   d0,d0               ; d0 = Facteur de rotation (0, 2, 4 ou 6 bits)
                
                ; --- Application directe avec correction du masque ---
                move.w  #$80C0,d1           ; On va garder que les bits du pixel
                ror.w   d0,d1               ; Décale le masque à la bonne position

				move.w	(a0),d2				; Lit les 4 pixels du mot
				and.w	d1,d2				; On garde que les bits du pixel lu
				rol.w	d0,d2				; Remet les bits au pixel 0
                rts

; G0 F0 G1 F1 G2 F2 G3 F3 / R0 B0 R1 B1 R2 B2 R3 B3
;=============================================================================
; PlotPixel fixed color (assumes coordinates are 0-255)
; Input :
; 		d0.w = X (0-255)
;		d1.w = Y (0-255)
;		a4 = ScreenBase
; Output : -
; Destroy : 
;		d2, d3
;		a1
;
; Bits configuration for 4 pixels on 2 bytes (1 word)
; G0 F0 G1 F1 G2 F2 G3 F3
; R0 B0 R1 B1 R2 B2 R3 B3
;=============================================================================
		macro PlotPixelStart
			; Compute screen adress
				move.l  a4,a1
                move.w  d0,d2
                lsr.w   #2,d2
                lsl.w	#1,d2			; /4, 4 pixels per word. (faster than lsr 1 with and on the emulator)
                adda.w  d2,a1			; +x screen
                move.w  d1,d2
                lsl.w   #7,d2			; y*128
                adda.w  d2,a1			; +y screen
				
			; Clean pixel bits
                move.w  d0,d2
                andi.w  #3,d2
                add.w   d2,d2			; *2 lower 2 bits (2, 4, 6 or 8) for rotation -> for pixel X

                move.w  #$3F3F,d3
                ror.w   d2,d3
                and.w   d3,(a1)			; clear pixel X
		endm

		macro PlotPixelColor
                move.w  \1,d3
                ror.w   d2,d3
                or.w    d3,(a1)			; set bits for the color
		endm
		
PlotPixelBlack:
                PlotPixelStart
                rts
PlotPixelBlue:
                PlotPixelStart
				PlotPixelColor <#ColorPixelBlue>
                rts
PlotPixelRed:
                PlotPixelStart
                PlotPixelColor <#ColorPixelRed>
                rts
PlotPixelMagenta:
                PlotPixelStart
				PlotPixelColor <#ColorPixelMagenta>
				rts
PlotPixelGreen:
                PlotPixelStart
				PlotPixelColor <#ColorPixelGreen>
                rts
PlotPixelCyan:
                PlotPixelStart
				PlotPixelColor <#ColorPixelCyan>
                rts
PlotPixelYellow:
                PlotPixelStart
				PlotPixelColor <#ColorPixelYellow>
                rts
PlotPixelWhite:
                PlotPixelStart
				PlotPixelColor <#ColorPixelWhite>
                rts

;=============================================================================
; PlotPixel2 fixed color (assumes coordinates are 0-255)
; Plot Two screens at the same time
;=============================================================================

		macro PlotPixelStart2
			; Compute screen adress
				move.l  #$20000,a1
				move.l  #$28000,a4
                move.w  d0,d2
                lsr.w   #2,d2
                lsl.w	#1,d2			; /4, 4 pixels per word. (faster than lsr 1 with and on the emulator)
                adda.w  d2,a1			; +x screen
                adda.w  d2,a4			; +x screen
                move.w  d1,d2
                lsl.w   #7,d2			; y*128
                adda.w  d2,a1			; +y screen
                adda.w  d2,a4			; +y screen
				
			; Clean pixel bits
                move.w  d0,d2
                andi.w  #3,d2
                add.w   d2,d2			; *2 lower 2 bits (2, 4, 6 or 8) for rotation -> for pixel X

                move.w  #$3F3F,d3
                ror.w   d2,d3
                and.w   d3,(a1)			; clear pixel X
                and.w   d3,(a4)			; clear pixel X
		endm

		macro PlotPixelColor2
                move.w  \1,d3
                ror.w   d2,d3
                or.w    d3,(a1)			; set bits for the color
                or.w    d3,(a4)			; set bits for the color
		endm
		
PlotPixelBlack2:
                PlotPixelStart2
                rts
PlotPixelBlue2:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelBlue>
                rts
PlotPixelRed2:
                PlotPixelStart2
                PlotPixelColor2 <#ColorPixelRed>
                rts
PlotPixelMagenta2:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelMagenta>
				rts
PlotPixelGreen2:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelGreen>
                rts
PlotPixelCyan2:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelCyan>
                rts
PlotPixelYellow2:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelYellow>
                rts
PlotPixelWhite2:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelWhite>
                rts

PlotPixelBlack2x4:
                PlotPixelStart2
				add.w	#1,d0
                PlotPixelStart2
				add.w	#1,d1
                PlotPixelStart2
				sub.w	#1,d0
                PlotPixelStart2
                rts
PlotPixelBlue2x4:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelBlue>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelBlue>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelBlue>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelBlue>
                rts
PlotPixelRed2x4:
                PlotPixelStart2
                PlotPixelColor2 <#ColorPixelRed>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelRed>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelRed>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelRed>
                rts
PlotPixelMagenta2x4:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelMagenta>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelMagenta>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelMagenta>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelMagenta>
				rts
PlotPixelGreen2x4:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelGreen>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelGreen>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelGreen>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelGreen>
                rts
PlotPixelCyan2x4:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelCyan>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelCyan>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelCyan>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelCyan>
                rts
PlotPixelYellow2x4:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelYellow>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelYellow>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelYellow>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelYellow>
                rts
PlotPixelWhite2x4:
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelWhite>
				add.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelWhite>
				add.w	#1,d1
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelWhite>
				sub.w	#1,d0
                PlotPixelStart2
				PlotPixelColor2 <#ColorPixelWhite>
                rts
