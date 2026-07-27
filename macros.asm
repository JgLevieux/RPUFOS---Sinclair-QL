	macro DisplayOffForProfiling
				or.b #%00000010,$18063		; set bit 1 & 3
	endm

	macro DisplayOnForProfiling
				and.b #%11111101,$18063		; retset bit 1 & 3
	endm

	macro CleanVarB
		lea		\1(pc),\2 
		clr.b	(\2)
	endm
	
	macro CleanVarW
		lea		\1(pc),\2 
		clr.w	(\2)
	endm

	macro CleanVarL
		lea		\1(pc),\2 
		clr.l	(\2)
	endm

	macro DBGENABLE
		moveq #5,d1
		moveq #-26,d0
		trap #1
	endm

	macro DBGBREAK
		nop
		nop
		dc.w $AADF
		nop
		nop
	endm

	macro DBGLOG
		dc.w $AAE8
		dc.b "\1"
		dc.b 0
		CNOP 0,2
	endm

	macro DBGLOGBREAK
		dc.w $AAE9
		dc.b "\1"
		dc.b 0
		CNOP 0,2
	endm
