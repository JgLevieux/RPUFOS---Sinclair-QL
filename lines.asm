;=============================================================================
; Draw line for QLix
; Dedicated version for QLix with collision with background
; Input : - d0 = X1, d1 = Y1, d4 = X2, d5 = Y2, d6 = Color
; Output : a6 = 0 -> no collision, 1 = collision
; Destroy : Nothing
;
; Note : Original code generated with AI.
; Largely modified for Qix collision
;=============================================================================
; G0 F0 G1 F1 G2 F2 G3 F3
; R0 B0 R1 B1 R2 B2 R3 B3
	macro CollideAndSetPixel
		;DBGBREAK

		lea 	QLixCollision(pc),a5
		move.w	a3,d0
		lsr.w	#1,d0
		add.w	d0,a5

		
		move.w	a4,d0
		add.w   d0,d0
		;add.l   d0,d0
		lea		Table_96(pc),a2
		add.w  (a2,d0.w),a5
		;add.w	d0,a5

		;move.l	a4,d0
		;lsr.l	#1,d0
		;lsl.l	#6,d0
		;add.l	d0,a5
		;move.l	a4,d0
		;lsr.l	#1,d0
		;lsl.l	#5,d0
		;add.l	d0,a5

		;move.l	a4,d0
		;lsr.l	#1,d0
		;move.l	d0,a2
		;add.l	d0,d0
		;add.l	a2,d0
		;lsl.l	#5,d0
		;add.l	d0,a5

		;bra		.noc2\@		; Nothing -> no collision

		tst.b	(a5)		; Something in the background?
		beq		.noc2\@		; Nothing -> no collision

;COL_INFO_NOTHING	equ		0
;COL_INFO_WALL		equ		1
;COL_INFO_TRACING	equ		2
;COL_INFO_FILLING	equ		3
;COL_INFO_WAY		equ		4
;COL_INFO_WAS_A_WAY	equ		5

		;move.w	d3,a4
		;move.w	d4,a5		; Save d3/d4 if finally no collision
		;move.w	(a3),d4
		;moveq	#0,d3
		;cmp.w	#$3F3F,d2
		;beq.s	.endcollide\@
		;add.w	#2,d3
		;cmp.w	#$CFCF,d2
		;beq.s	.endcollide\@
		;add.w	#2,d3
		;cmp.w	#$F3F3,d2
		;beq.s	.endcollide\@
		;add.w	#2,d3
;.endcollide\@
		;not		d2
		;and.w	d2,d4
		;beq.s	.noc\@		; The dest pixel is black?
		;rol.w	d3,d4
		;DBGBREAK
		moveq	#0,d0
		move.b	(a5),d0
		move.l	d0,a6
	;DBGBREAK
		movem.l (sp)+,d0-d7/a0-a5
		rts
;.noc\@
		;not		d2
		;move.w	a4,d3
		;move.w	a5,d4
.noc2\@
		and.w   d2,(a1)		; Remove ALL bits of the pixel we want to write
		or.w    d3,(a1)		; Add ONLY bits of the color we want to write
	endm

Table_96:
    dc.w 0, 0, 96, 96, 192, 192, 288, 288, 384, 384, 480, 480, 576, 576, 672, 672
    dc.w 768, 768, 864, 864, 960, 960, 1056, 1056, 1152, 1152, 1248, 1248, 1344, 1344, 1440, 1440
    dc.w 1536, 1536, 1632, 1632, 1728, 1728, 1824, 1824, 1920, 1920, 2016, 2016, 2112, 2112, 2208, 2208
    dc.w 2304, 2304, 2400, 2400, 2496, 2496, 2592, 2592, 2688, 2688, 2784, 2784, 2880, 2880, 2976, 2976
    dc.w 3072, 3072, 3168, 3168, 3264, 3264, 3360, 3360, 3456, 3456, 3552, 3552, 3648, 3648, 3744, 3744
    dc.w 3840, 3840, 3936, 3936, 4032, 4032, 4128, 4128, 4224, 4224, 4320, 4320, 4416, 4416, 4512, 4512
    dc.w 4608, 4608, 4704, 4704, 4800, 4800, 4896, 4896, 4992, 4992, 5088, 5088, 5184, 5184, 5280, 5280
    dc.w 5376, 5376, 5472, 5472, 5568, 5568, 5664, 5664, 5760, 5760, 5856, 5856, 5952, 5952, 6048, 6048
    dc.w 6144, 6144, 6240, 6240, 6336, 6336, 6432, 6432, 6528, 6528, 6624, 6624, 6720, 6720, 6816, 6816
    dc.w 6912, 6912, 7008, 7008, 7104, 7104, 7200, 7200, 7296, 7296, 7392, 7392, 7488, 7488, 7584, 7584
    dc.w 7680, 7680, 7776, 7776, 7872, 7872, 7968, 7968, 8064, 8064, 8160, 8160, 8256, 8256, 8352, 8352
    dc.w 8448, 8448, 8544, 8544, 8640, 8640, 8736, 8736, 8832, 8832, 8928, 8928, 9024, 9024, 9120, 9120
    dc.w 9216, 9216, 9312, 9312, 9408, 9408, 9504, 9504, 9600, 9600, 9696, 9696, 9792, 9792, 9888, 9888
    dc.w 9984, 9984, 10080, 10080, 10176, 10176, 10272, 10272, 10368, 10368, 10464, 10464, 10560, 10560, 10656, 10656
    dc.w 10752, 10752, 10848, 10848, 10944, 10944, 11040, 11040, 11136, 11136, 11232, 11232, 11328, 11328, 11424, 11424
    dc.w 11520, 11520, 11616, 11616, 11712, 11712, 11808, 11808, 11904, 11904, 12000, 12000, 12096, 12096, 12192, 12192	
	
DrawLineQLix:
    movem.l d0-d7/a0-a5,-(sp)
	move.l	#0,a6
	lea     ScreenBase(pc),a1				; Screen dest.
	move.l  (a1),a1

	move.l	#0,a3
	move.l	#0,a4
	move.w	d0,a3							; X adr offset - Qlix Collision
	sub.w	#PLAYFIELD_START_X,a3
	move.w	d1,d2
	sub.w	#PLAYFIELD_START_Y,d2
	;lsl.w	#6,d2	; *64
	add.w	d2,a4
	;move.w	d1,d2
	;sub.w	#PLAYFIELD_START_Y,d2
	;lsl.w	#5,d2	; *32
	;add.w	d2,a4	; *96					; Y adr offset - Qlix Collision

    ; 1. deltas x/y
    sub.w   d0,d4
    sub.w   d1,d5

	; QLix col start adr
	;move.w	d1,d2
	;move.w	d1,d3
	;sub.l	#PLAYFIELD_START_Y,d2
	;sub.l	#PLAYFIELD_START_Y,d3
	;lsl.w	#6,d2		; y*64
	;lsl.w	#7,d3		; y*128
	;add.w	d3,a3
	;add.w	d2,a3		; +y*192
	;add.w	d0,a3		; +x
	;sub.l	#PLAYFIELD_START_X,a3

    ; 2. adresse de base (Y*128 + X/4*2)
    move.w  d1,d2
    lsl.w   #7,d2
    move.w  d0,d3
    lsr.w   #1,d3
    andi.w  #$fffe,d3
    add.w   d3,d2
    adda.w  d2,a1
    ;adda.w  d2,a3

    ; 3. sous-pixel et masques
    move.w  d0,d1
    andi.w  #3,d1
    move.w  d1,d0
    add.w   d0,d0

    move.w  #$3f3f,d2	; Bits for pixel 0
    ror.w   d0,d2

    move.w  d6,d3
    ror.w   d0,d3

    ; 4. dispatch
    tst.w   d4
    bmi     .x_neg
.x_pos:
    tst.w   d5
    bmi     .xp_yn
.xp_yp:
    cmp.w   d4,d5
    bgt     .y_maj_xp_yp

.x_maj_xp_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yp:
	CollideAndSetPixel
    ror.w   #2,d2
    ror.w   #2,d3
    addq.w  #1,a3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx1
    moveq   #0,d1
    addq.w  #2,a1
    ;addq.w  #2,a3
    ror.w   #8,d3
.nx1:
    sub.w   d5,d6
    bge.s   .ny1
    add.w   d4,d6
    lea     128(a1),a1
	add.l	#1,a4
.ny1:
    dbra    d7,.l_x_maj_xp_yp
    bra     .end

.y_maj_xp_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yp:
	CollideAndSetPixel
    lea     128(a1),a1
    add.l	#1,a4
    sub.w   d4,d6
    bge.s   .nx2
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.w  #1,a3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx2
    moveq   #0,d1
    addq.w  #2,a1
    ;addq.w  #2,a3
    ror.w   #8,d3
.nx2:
    dbra    d7,.l_y_maj_xp_yp
    bra     .end

.xp_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xp_yn

.x_maj_xp_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yn:
	CollideAndSetPixel
    ror.w   #2,d2
    ror.w   #2,d3
    addq.w  #1,a3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx3
    moveq   #0,d1
    addq.w  #2,a1
    ;addq.w  #2,a3
    ror.w   #8,d3
.nx3:
    sub.w   d5,d6
    bge.s   .ny3
    add.w   d4,d6
    lea     -128(a1),a1
    sub.l	#1,a4
.ny3:
    dbra    d7,.l_x_maj_xp_yn
    bra     .end

.y_maj_xp_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yn:
	CollideAndSetPixel
    lea     -128(a1),a1
    sub.l	#1,a4
    sub.w   d4,d6
    bge.s   .nx4
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.w  #1,a3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx4
    moveq   #0,d1
    addq.w  #2,a1
    ;addq.w  #2,a3
    ror.w   #8,d3
.nx4:
    dbra    d7,.l_y_maj_xp_yn
    bra     .end

.x_neg:
    neg.w   d4
    tst.w   d5
    bmi.w   .xn_yn
.xn_yp:
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yp

.x_maj_xn_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yp:
	CollideAndSetPixel
    rol.w   #2,d2
    rol.w   #2,d3
    subq.w  #1,a3
    subq.b  #1,d1
    bpl.s   .nx5
    moveq   #3,d1
    subq.w  #2,a1
    ;subq.w  #2,a3
    ror.w   #8,d3
.nx5:
    sub.w   d5,d6
    bge.s   .ny5
    add.w   d4,d6
    lea     128(a1),a1
    add.l	#1,a4
.ny5:
    dbra    d7,.l_x_maj_xn_yp
    bra     .end

.y_maj_xn_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yp:
	CollideAndSetPixel
    lea     128(a1),a1
    add.l	#1,a4
    sub.w   d4,d6
    bge.s   .nx6
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.w  #1,a3
    subq.b  #1,d1
    bpl.s   .nx6
    moveq   #3,d1
    subq.w  #2,a1
    ;subq.w  #2,a3
    ror.w   #8,d3
.nx6:
    dbra    d7,.l_y_maj_xn_yp
    bra     .end

.xn_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yn

.x_maj_xn_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yn:
	CollideAndSetPixel
    rol.w   #2,d2
    rol.w   #2,d3
    subq.w  #1,a3
    subq.b  #1,d1
    bpl.s   .nx7
    moveq   #3,d1
    subq.w  #2,a1
    ;subq.w  #2,a3
    ror.w   #8,d3
.nx7:
    sub.w   d5,d6
    bge.s   .ny7
    add.w   d4,d6
    lea     -128(a1),a1
    sub.l	#1,a4
.ny7:
    dbra    d7,.l_x_maj_xn_yn
    bra     .end

.y_maj_xn_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yn:
	CollideAndSetPixel
    lea     -128(a1),a1
    sub.l	#1,a4
    sub.w   d4,d6
    bge.s   .nx8
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.w  #1,a3
    subq.b  #1,d1
    bpl.s   .nx8
    moveq   #3,d1
    subq.w  #2,a1
    ;subq.w  #2,a3
    ror.w   #8,d3
.nx8:
    dbra    d7,.l_y_maj_xn_yn
.end:
    movem.l (sp)+,d0-d7/a0-a5
    rts

;=============================================================================
; Draw line
; Input : - d0 = X1, d1 = Y1, d4 = X2, d5 = Y2, d6 = Color
; Output : -
; Destroy : Nothing
;
; Note : Original code generated with AI.
; TODO : Probably possible to make it faster for black and white (no need to read VRAM?).
;=============================================================================

DrawLine:
    movem.l d0-d7/a0-a1,-(sp)
	lea     ScreenBase,a0
	move.l  (a0),a0

    ; 1. deltas x/y
    sub.w   d0,d4
    sub.w   d1,d5

    ; 2. adresse de base (Y*128 + X/4*2)
    move.w  d1,d2
    lsl.w   #7,d2
    move.w  d0,d3
    lsr.w   #1,d3
    andi.w  #$fffe,d3
    add.w   d3,d2
    move.l  a0,a1
    adda.w  d2,a1

    ; 3. sous-pixel et masques
    move.w  d0,d1
    andi.w  #3,d1
    move.w  d1,d0
    add.w   d0,d0

    move.w  #$3f3f,d2
    ror.w   d0,d2

    move.w  d6,d3
    ror.w   d0,d3

    ; 4. dispatch
    tst.w   d4
    bmi     .x_neg
.x_pos:
    tst.w   d5
    bmi     .xp_yn
.xp_yp:
    cmp.w   d4,d5
    bgt     .y_maj_xp_yp

.x_maj_xp_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx1
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx1:
    sub.w   d5,d6
    bge.s   .ny1
    add.w   d4,d6
    lea     128(a1),a1
.ny1:
    dbra    d7,.l_x_maj_xp_yp
    bra     .end

.y_maj_xp_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     128(a1),a1
    sub.w   d4,d6
    bge.s   .nx2
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx2
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx2:
    dbra    d7,.l_y_maj_xp_yp
    bra     .end

.xp_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xp_yn

.x_maj_xp_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx3
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx3:
    sub.w   d5,d6
    bge.s   .ny3
    add.w   d4,d6
    lea     -128(a1),a1
.ny3:
    dbra    d7,.l_x_maj_xp_yn
    bra     .end

.y_maj_xp_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     -128(a1),a1
    sub.w   d4,d6
    bge.s   .nx4
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx4
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx4:
    dbra    d7,.l_y_maj_xp_yn
    bra     .end

.x_neg:
    neg.w   d4
    tst.w   d5
    bmi.s   .xn_yn
.xn_yp:
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yp

.x_maj_xn_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx5
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx5:
    sub.w   d5,d6
    bge.s   .ny5
    add.w   d4,d6
    lea     128(a1),a1
.ny5:
    dbra    d7,.l_x_maj_xn_yp
    bra     .end

.y_maj_xn_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     128(a1),a1
    sub.w   d4,d6
    bge.s   .nx6
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx6
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx6:
    dbra    d7,.l_y_maj_xn_yp
    bra     .end

.xn_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yn

.x_maj_xn_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx7
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx7:
    sub.w   d5,d6
    bge.s   .ny7
    add.w   d4,d6
    lea     -128(a1),a1
.ny7:
    dbra    d7,.l_x_maj_xn_yn
    bra     .end

.y_maj_xn_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     -128(a1),a1
    sub.w   d4,d6
    bge.s   .nx8
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx8
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx8:
    dbra    d7,.l_y_maj_xn_yn

.end:
    movem.l (sp)+,d0-d7/a0-a1
    rts
	
