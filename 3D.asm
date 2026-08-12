DATA_OLIPIX	equ		1

NUM_VERTICES    equ     20              ; Nombre de sommets du logo
NUM_EDGES       equ     14              ; Nombre d'arêtes du logo

COLOR_BLACK     equ     0               ; Couleur noire
num_sprites equ 30
step_x      equ 2
step_y      equ 2
speed_x     equ 1
speed_y     equ 2


; =============================================================================
; Draw 3D object
; =============================================================================
Draw3D:
			; SWAP
			
			;DBGBREAK
				lea		Projected(pc),a1

				lea		BufferNum(pc),a3
				tst.w	(a3)
				beq.s	.Buffer0
		
				lea		Projected1(pc),a2					; Use data buffer 1
				move.l	a2,(a1)
				bra		.Buffer1

.Buffer0:
				lea		Projected2(pc),a2					; Use data buffer 2
				move.l	a2,(a1)
.Buffer1:

				move.l	#$0,d6
				bsr     DrawEdges ; clear

                ; Update angles
                lea     AngleX(pc),a0
                lea     AngleY(pc),a1
                addq.w  #1,(a0)
                andi.w  #63,(a0)
                addq.w  #1,(a1)
                andi.w  #63,(a1)

                bsr     RotateAndProject
                
				move.l	#1,d6
                bsr     DrawEdges ; draw
				
				rts

	
; =============================================================================
; Rotation et Projection des Sommets
; =============================================================================
RotateAndProject:
				bsr		AnimateZoom
                lea     ZoomLevel(pc),a6
				;add.w	#1,(a6)


				lea 	AngleX(pc),a2
				lea 	AngleY(pc),a3
				lea 	SinX(pc),a4
				lea 	CosX(pc),a5

                ; Récupération du Sinus/Cosinus pour l'angle Y
                move.w  (a3),d0
                bsr     GetSinCos
                move.w  d1,(a4)         ; d1 = Sin(Y)
                move.w  d2,(a5)         ; d2 = Cos(Y)

                ; Récupération du Sinus/Cosinus pour l'angle X
                move.w  AngleX,d0
                bsr     GetSinCos
                move.w  d1,(a4)         ; d1 = Sin(X)
                move.w  d2,(a5)         ; d2 = Cos(X)

                lea     Vertices(pc),a0     ; Table des sommets initiaux (X, Y, Z)
                lea     Projected(pc),a1    ; Table de destination (ScreenX, ScreenY)
				move.l	(a1),a1
                move.w  #NUM_VERTICES-1,d7

.loop_points:
                ; Charger les coordonnées d'origine
                move.w  (a0)+,d0        ; d0 = X
                move.w  (a0)+,d1        ; d1 = Y
                move.w  (a0)+,d2        ; d2 = Z

                ; --- Rotation autour de l'axe Y (Angles 8.8) ---
                ; X' = (X * CosY - Z * SinY) / 256
                ; Z' = (X * SinY + Z * CosY) / 256
                move.w  d0,d3           ; d3 = X
                move.w  d2,d4           ; d4 = Z

                muls    (a5),d0         ; d0 = X * CosY
                muls    (a4),d2         ; d2 = Z * SinY
                sub.l   d2,d0           ; d0 = X*CosY - Z*SinY
                asr.l   #8,d0           ; Échelle 8.8 -> entier

                muls    (a4),d3         ; d3 = X * SinY
                muls    (a5),d4         ; d4 = Z * CosY
                add.l   d4,d3           ; d3 = X*SinY + Z*CosY
                asr.l   #8,d3           ; d3 = Z'

                move.w  d3,d2           ; d2 = Z' (Y reste dans d1)

                ; --- Rotation autour de l'axe X ---
                ; Y' = (Y * CosX - Z' * SinX) / 256
                ; Z'' = (Y * SinX + Z' * CosX) / 256
                move.w  d1,d3           ; d3 = Y
                move.w  d2,d4           ; d4 = Z'

                muls    (a5),d1         ; d1 = Y * CosX
                muls    (a4),d2         ; d2 = Z' * SinX
                sub.l   d2,d1           ; d1 = Y*CosX - Z'*SinX
                asr.l   #8,d1           ; d1 = Y'

                muls    (a4),d3         ; d3 = Y * SinX
                muls    (a5),d4         ; d4 = Z' * CosX
                add.l   d4,d3           ; d3 = Y*SinX + Z'*CosX
                asr.l   #8,d3           ; d3 = Z''

                move.w  d3,d2           ; d2 = Z''

                ; --- Projection Perspective 3D -> 2D ---
                ; ScreenX = CenterX + (X' * Distance) / (Z'' + OffsetZ)
                ; ScreenY = CenterY - (Y' * Distance) / (Z'' + OffsetZ)
                addi.w  #250,d2         ; OffsetZ
                ble.s   .clip_point

                ; Chargement du niveau de zoom dynamique
                move.w  (a6),d3

                ; --- Calcul de ScreenX ---
                ext.l   d0
                muls    d3,d0           ; X' * ZoomLevel (Remplace lsl.l #7,d0)
                divs    d2,d0
                addi.w  #128,d0         ; CenterX

                ; --- Calcul de ScreenY ---
                ext.l   d1
                muls    d3,d1           ; Y' * ZoomLevel (Remplace lsl.l #7,d1)
                divs    d2,d1
                move.w  #128+48,d4         ; CenterY (Utilise d4 car d3 contient ZoomLevel)
                sub.w   d1,d4
                move.w  d4,d1
                bra.s   .store

.clip_point:
                moveq   #0,d0
                moveq   #0,d1

.store:
                move.w  d0,(a1)+        ; Stocker ScreenX
                move.w  d1,(a1)+        ; Stocker ScreenY

                dbf     d7,.loop_points

                rts


; =============================================================================
; Dessin des Arêtes (Edges)
; =============================================================================
DrawEdges:
                movem.l d0-d4/a0-a2,-(sp)

                lea     Edges(pc),a0
                lea     Projected(pc),a1
				move.l	(a1),a1
                move.w  #NUM_EDGES-1,d7

.loop_edges:
                moveq   #0,d0
                moveq   #0,d1
                move.b  (a0)+,d0        ; Indice du point de départ A
                move.b  (a0)+,d1        ; Indice du point d'arrivée B

                ; Recherche des coordonnées 2D du point A dans le buffer
                lsl.w   #2,d0           ; Indice * 4 (chaque point projeté = 2 mots = 4 octets)
                moveq   #0,d2
                moveq   #0,d3
                move.w  (a1,d0.w),d4    ; X1
                move.w  2(a1,d0.w),d5   ; Y1

                ; Recherche des coordonnées 2D du point B dans le buffer
                lsl.w   #2,d1           ; Indice * 4
                move.w  (a1,d1.w),d0    ; X2
                move.w  2(a1,d1.w),d1   ; Y2

                bsr     DrawLine

                dbf     d7,.loop_edges

                movem.l (sp)+,d0-d4/a0-a2
                rts

;=============================================================================
; Draw line (Optimized for Sinclair QL - Green channel only)
; Input : - d0 = X1, d1 = Y1, d4 = X2, d5 = Y2, d6 = Color (0 = erase, >0 = draw)
; Output : -
; Destroy : Nothing
;=============================================================================

DrawLine:
    movem.l d0-d7/a0-a2,-(sp)

    ; 1. Calcul de l'adresse de base (Y * 128 + (X / 4) * 2)
    move.w  d1,d2
    lsl.w   #7,d2       ; Y1 * 128
    move.w  d0,d3
    lsr.w   #1,d3
    andi.w  #$fffe,d3   ; (X1 / 4) * 2
    add.w   d3,d2
    
    lea     ScreenBase,a0
    move.l  (a0),a0
    adda.w  d2,a0       ; a0 pointe EXACTEMENT sur l'octet pair (Vert/Flash)

    ; 2. Création du masque binaire pour le sous-pixel (Bit 7, 5, 3 ou 1)
    move.w  d0,d2
    andi.w  #3,d2       ; X1 % 4
    add.w   d2,d2       ; (X1 % 4) * 2
    move.l  #$80,d3
    lsr.b   d2,d3       ; d3 = $80, $20, $08, ou $02

    ; 3. Configuration des deltas et du pas Y (a2)
    move.w  #128,a2
    sub.w   d1,d5       ; dy = Y2 - Y1
    bge.s   .dy_pos
    neg.w   d5
    move.w  #-128,a2
.dy_pos:

    sub.w   d0,d4       ; dx = X2 - X1

    ; 4. Inversion du masque si la couleur est 0 (Mode "Erase")
    tst.w   d6
    bne.s   .dispatch_x
    not.b   d3          ; Masque d'effacement: $7F, $DF, $F7, $FD

.dispatch_x:
    tst.w   d4          ; dx est-il négatif ?
    bmi     .x_neg

    ; --- X POSITIF (Tracé vers la droite) ---
.x_pos:
    tst.w   d6
    beq     .er_right   ; Branchement selon la couleur (0 = Erase)

.dr_right:              ; Boucles DRAW (Couleur > 0)
    cmp.w   d4,d5
    bgt.s   .dr_y_maj

.dr_x_maj:
    move.w  d4,d7       ; d7 = compteur
    move.w  d4,d6
    lsr.w   #1,d6       ; d6 = erreur (dx / 2)
.l_dr_x_maj:
    or.b    d3,(a0)     ; Allume le pixel vert
    sub.w   d5,d6
    bge.s   .nx_dr_x
    add.w   d4,d6
    adda.w  a2,a0
.nx_dr_x:
    ror.b   #2,d3       ; $80 -> $20 -> $08 -> $02 -> $80 (Négatif !)
    bpl.s   .ny_dr_x    ; bpl intercepte le passage en négatif (frontière du mot)
    addq.w  #2,a0
.ny_dr_x:
    dbra    d7,.l_dr_x_maj
    bra     .end

.dr_y_maj:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_dr_y_maj:
    or.b    d3,(a0)
    adda.w  a2,a0
    sub.w   d4,d6
    bge.s   .nx_dr_y
    add.w   d5,d6
    ror.b   #2,d3
    bpl.s   .nx_dr_y
    addq.w  #2,a0
.nx_dr_y:
    dbra    d7,.l_dr_y_maj
    bra     .end


.er_right:              ; Boucles ERASE (Couleur = 0)
    cmp.w   d4,d5
    bgt.s   .er_y_maj

.er_x_maj:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_er_x_maj:
    and.b   d3,(a0)     ; Efface le pixel vert (masque inversé)
    sub.w   d5,d6
    bge.s   .nx_er_x
    add.w   d4,d6
    adda.w  a2,a0
.nx_er_x:
    ror.b   #2,d3       ; $7F -> $DF -> $F7 -> $FD -> $7F (Positif !)
    bmi.s   .ny_er_x    ; bmi intercepte le passage en positif
    addq.w  #2,a0
.ny_er_x:
    dbra    d7,.l_er_x_maj
    bra     .end

.er_y_maj:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_er_y_maj:
    and.b   d3,(a0)
    adda.w  a2,a0
    sub.w   d4,d6
    bge.s   .nx_er_y
    add.w   d5,d6
    ror.b   #2,d3
    bmi.s   .nx_er_y
    addq.w  #2,a0
.nx_er_y:
    dbra    d7,.l_er_y_maj
    bra     .end


    ; --- X NEGATIF (Tracé vers la gauche) ---
.x_neg:
    neg.w   d4          ; dx devient absolu
    tst.w   d6
    beq     .er_left

.dl_left:               ; Boucles DRAW (Couleur > 0)
    cmp.w   d4,d5
    bgt.s   .dl_y_maj

.dl_x_maj:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_dl_x_maj:
    or.b    d3,(a0)
    sub.w   d5,d6
    bge.s   .nx_dl_x
    add.w   d4,d6
    adda.w  a2,a0
.nx_dl_x:
    rol.b   #2,d3
    cmp.b   #$02,d3     ; Atteint $02 ? (franchissement à gauche)
    bne.s   .ny_dl_x
    subq.w  #2,a0
.ny_dl_x:
    dbra    d7,.l_dl_x_maj
    bra     .end

.dl_y_maj:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_dl_y_maj:
    or.b    d3,(a0)
    adda.w  a2,a0
    sub.w   d4,d6
    bge.s   .nx_dl_y
    add.w   d5,d6
    rol.b   #2,d3
    cmp.b   #$02,d3
    bne.s   .nx_dl_y
    subq.w  #2,a0
.nx_dl_y:
    dbra    d7,.l_dl_y_maj
    bra     .end


.er_left:               ; Boucles ERASE (Couleur = 0)
    cmp.w   d4,d5
    bgt.s   .el_y_maj

.el_x_maj:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_el_x_maj:
    and.b   d3,(a0)
    sub.w   d5,d6
    bge.s   .nx_el_x
    add.w   d4,d6
    adda.w  a2,a0
.nx_el_x:
    rol.b   #2,d3
    cmp.b   #$FD,d3     ; Atteint $FD pour le masque inversé ?
    bne.s   .ny_el_x
    subq.w  #2,a0
.ny_el_x:
    dbra    d7,.l_el_x_maj
    bra     .end

.el_y_maj:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_el_y_maj:
    and.b   d3,(a0)
    adda.w  a2,a0
    sub.w   d4,d6
    bge.s   .nx_el_y
    add.w   d5,d6
    rol.b   #2,d3
    cmp.b   #$FD,d3
    bne.s   .nx_el_y
    subq.w  #2,a0
.nx_el_y:
    dbra    d7,.l_el_y_maj

.end:
    movem.l (sp)+,d0-d7/a0-a2
    rts

; =============================================================================
;  Obtention Sinus / Cosinus (64 étapes pour 360°)
; =============================================================================
;  Entrée : d0 = Angle (0-63)
;  Sorties : d1 = Valeur de Sinus (format signé 8.8), d2 = Cosinus (format signé 8.8)
;  La table ne contient que le sinus. Le cosinus est calculé par décalage de phase :
;  Cos(x) = Sin(x + 90°) -> Dans notre cercle à 64 étapes, 90° correspond à 16 étapes.
; =============================================================================
GetSinCos:
                andi.w  #63,d0          ; Écrêtage de sécurité de l'angle d'entrée

                ; Extraction du Sinus
                move.w  d0,d1
                add.w   d1,d1           ; d1 * 2 pour indexation sur mots (16-bit)
                lea     SinTable(pc),a1
                move.w  (a1,d1.w),d1    ; d1 = Sin(Angle)

                ; Extraction du Cosinus
                move.w  d0,d2
                addi.w  #16,d2          ; Ajout du quart de période (90° / 16 étapes)
                andi.w  #63,d2          ; Écrêtage
                add.w   d2,d2
                move.w  (a1,d2.w),d2    ; d2 = Cos(Angle)

                rts

; =============================================================================
;  SOUS-ROUTINE : Animation du Zoom (Oscillation entre 50 et 200)
; =============================================================================
AnimateZoom:
                ; 1. Avancement de l'angle du zoom
                lea     ZoomAngle(pc),a0
                move.w  (a0),d0         ; d0 = Angle actuel
                addq.w  #1,d0           ; Vitesse de l'oscillation (+1 par trame)
                andi.w  #63,d0          ; Limite à l'espace de la table [0-63]
                move.w  d0,(a0)         ; Sauvegarde de l'angle mis à jour

                ; 2. Lecture de la valeur de Sinus
                add.w   d0,d0           ; Multiplié par 2 (indexation par mots de 16 bits)
                lea     SinTable(pc),a1
				moveq	#0,d1
                move.w  (a1,d0.w),d1    ; d0 = Valeur brute de Sinus (-256 à 256)
				add.w	#256+512,d1

                ; 3. Application de l'amplitude (Multiplication par 75)
                ;muls    #75,d0          ; d0 = Sinus * 75

                ; 4. Division par 256 (Conversion du format 8.8 vers entier)
                ; Sur 68008, un décalage de 8 bits via asr.l est plus rapide qu'un divs
                lsr.l   #2,d1           ; d0 = Amplitude réelle calculée [-75 à +75]

                ; 5. Ajout du point central (Offset 125)
                ;addi.w  #130,d0         ; d0 = 125 + [-75 à +75] -> [50 à 200]

                ; 6. Stockage du nouveau niveau de zoom
                lea     ZoomLevel(pc),a0
                move.w  d1,(a0)         ; ZoomLevel est prêt pour RotateAndProject
                rts
				

AngleX:         dc.w    0
AngleY:         dc.w    0

				even

; Stockage intermédiaire des valeurs de rotation courantes
SinX:           dc.w    0
CosX:           dc.w    0
SinY:           dc.w    0
CosY:           dc.w    0
ZoomLevel:		dc.w	50
ZoomAngle:		dc.w	0

; --- Table de Sinus prédéfinie (64 étapes, codée en 8.8 signé) ---
; Valeurs calculées selon : Sin(i * 2*Pi / 64) * 256. 256 représente 1.0 en virgule fixe.
SinTable:
                dc.w    0, 25, 50, 74, 98, 120, 142, 162
                dc.w    181, 198, 213, 226, 236, 244, 250, 254
                dc.w    256, 254, 250, 244, 236, 226, 213, 198
                dc.w    181, 162, 142, 120, 98, 74, 50, 25
                dc.w    0, -25, -50, -74, -98, -120, -142, -162
                dc.w    -181, -198, -213, -226, -236, -244, -250, -254
                dc.w    -256, -254, -250, -244, -236, -226, -213, -198
                dc.w    -181, -162, -142, -120, -98, -74, -50, -25

Vertices:
                ; --- Lettre 'O' (Points 0 à 3) ---
                dc.w    -55,  20,   0   ; 0 : Haut Gauche
                dc.w    -40,  20,   0   ; 1 : Haut Droite
                dc.w    -40, -20,   0   ; 2 : Bas Droite
                dc.w    -55, -20,   0   ; 3 : Bas Gauche

                ; --- Lettre 'L' (Points 4 à 6) ---
                dc.w    -30,  20,   0   ; 4 : Sommet du L
                dc.w    -30, -20,   0   ; 5 : Angle du L
                dc.w    -15, -20,   0   ; 6 : Base du L

                ; --- Lettre 'I' (Points 7 à 8) ---
                dc.w     -5,  20,   0   ; 7 : Sommet du premier I
                dc.w     -5, -20,   0   ; 8 : Base du premier I

                ; --- Lettre 'P' (Points 9 à 13) ---
                dc.w      5, -20,   0   ; 9 : Base du jambage
                dc.w      5,  20,   0   ; 10: Sommet du jambage
                dc.w     20,  20,   0   ; 11: Boucle Haut Droite
                dc.w     20,   0,   0   ; 12: Boucle Milieu Droite
                dc.w      5,   0,   0   ; 13: Intersection Milieu Jambage

                ; --- Lettre 'I' (Points 14 à 15) ---
                dc.w     30,  20,   0   ; 14: Sommet du second I
                dc.w     30, -20,   0   ; 15: Base du second I

                ; --- Lettre 'X' (Points 16 à 19) ---
                dc.w     40,  20,   0   ; 16: Branche 1 - Haut Gauche
                dc.w     55, -20,   0   ; 17: Branche 1 - Bas Droite
                dc.w     55,  20,   0   ; 18: Branche 2 - Haut Droite
                dc.w     40, -20,   0   ; 19: Branche 2 - Bas Gauche

; --- Connectivité des lignes pour écrire OLIPIX ---
Edges:
                ; Lettre 'O' (Un rectangle fermé)
                dc.b    0, 1
                dc.b    1, 2
                dc.b    2, 3
                dc.b    3, 0

                ; Lettre 'L'
                dc.b    4, 5
                dc.b    5, 6

                ; Lettre 'I'
                dc.b    7, 8

                ; Lettre 'P'
                dc.b    9, 10           ; Tracé vertical complet
                dc.b    10, 11          ; Haut de la boucle
                dc.b    11, 12          ; Flanc droit de la boucle
                dc.b    12, 13          ; Retour au centre du P

                ; Lettre 'I'
                dc.b    14, 15

                ; Lettre 'X' (Deux diagonales croisées)
                dc.b    16, 17
                dc.b    18, 19

                even	

Projected:		dc.l	0
Projected1:     ds.w    NUM_VERTICES*2
Projected2:     ds.w    NUM_VERTICES*2
                even	

