; =============================================================================
;  ipc.s - talking to the IPC directly, without QDOS
;  To be included FIRST, before controls.asm and sound.s
; -----------------------------------------------------------------------------
;  WHY THIS FILE EXISTS. The keyboard and the sound both live in the IPC, and
;  the obvious way to reach it is QDOS's MT.IPCOM, trap #1 with d0 = $11. That
;  is what this game did, and it was wrong for a reason that has nothing to do
;  with either device : MT.IPCOM works from a6, the SYSTEM VARIABLES, and this
;  game clears $28000-$2FFFF for its second screen. The system variables are
;  gone. From the Minerva source of that very routine :
;
;      move.l  sv_chtop(a6),a0     get system extension address
;      lea     sx_ipcom(a0),a0
;      move.l  (a0),d6
;      beq.s   fronted
;      move.l  d6,a0
;      move.l  4(a0),a1
;      jsr     (a1)                call user's front end routine
;
;  -- a jsr through a pointer read out of what is now screen memory -- and
;
;      moveq   #pc.intri,d7
;      or.b    sv_pcint(a6),d7
;      move.b  d7,pc_intr-pc_ipcrd(a0)
;
;  -- the interrupt register written with a value half of which is a pixel.
;  The keyboard got away with it while those bytes happened to be black. Adding
;  sound doubled the number of calls a frame and the luck ran out.
;
;  THE PROTOCOL, from the Minerva headers. Two wires, one of them shared, so
;  the 68008 has to assert a one in order to see the IPC pull the line down :
;
;    send a bit : write %11x0 to pc_ipcwr, x being the bit, then wait for bit 6
;                 of pc_ipcrd to go to zero -- that is the IPC taking it
;    read a bit : send a one the same way, and when bit 6 goes to zero, bit 7
;                 of pc_ipcrd is the bit the IPC sent back
;
;  Everything travels most significant bit first. A command is one nibble, then
;  whatever parameter nibbles it takes, then whatever reply it gives.
;
;  Nothing here reads or writes a system variable, takes a trap, or needs an
;  interrupt. It is about thirty instructions and it cannot be derailed by what
;  is on the screen.
; =============================================================================

PC_IPCRD        equ     $18020                  ; bit 6 = handshake, bit 7 = data in
PC_IPCWR        equ     $18003                  ; %11x0 out
PC_INTR         equ     $18021                  ; bits 4..0 clear a pending interrupt
PC_INTRI        equ     1<<1                    ; ...this one being the IPC's

IPC_KEYROW      equ     9                       ; one nibble in : the row ; one byte back
IPC_BEEP        equ     10                      ; sixteen nibbles in, nothing back
IPC_KILLSND     equ     11                      ; nothing in, nothing back

; How long to wait for the IPC to take a bit before giving up on it. The chip is
; busy in its sound interrupt for most of a note, so a transfer can be slow ;
; but a wait with no way out turns any hiccup into a frozen machine, which is
; exactly what this game has already suffered once. A few thousand turns is far
; longer than any real exchange and still only a few milliseconds.
IPC_TIMEOUT     equ     4000

; -----------------------------------------------------------------------------
;  IpcNibble - four bits to the IPC, most significant first
;  In  : d0.b = the nibble in its low four bits
;        a0 = PC_IPCRD, a1 = PC_IPCWR
;  Destroys : d0, d1, d2
; -----------------------------------------------------------------------------
IpcNibble:
                moveq   #4-1,d2
.bit:
                moveq   #%1100,d1
                btst    #3,d0
                beq.s   .zero
                ori.b   #%0010,d1               ; the data bit rides in bit 1
.zero:
                move.b  d1,(a1)
                add.b   d0,d0                   ; next bit up to position 3
                move.w  #IPC_TIMEOUT,d1
.wait:
                btst    #6,(a0)                 ; taken by the IPC yet ?
                dbeq    d1,.wait
                dbra    d2,.bit
                rts

; -----------------------------------------------------------------------------
;  IpcByteIn - eight bits back from the IPC, most significant first
;  Reading is done by SENDING ones : the line is shared and only goes high if
;  both ends let it, so a one has to be asserted to see a zero come back.
;  In  : a0 = PC_IPCRD, a1 = PC_IPCWR
;  Out : d0.b = the byte
;  Destroys : d0, d1, d2
; -----------------------------------------------------------------------------
IpcByteIn:
                moveq   #0,d0
                moveq   #8-1,d2
.bit:
                move.b  #%1110,(a1)             ; a one, so the IPC can pull it down
                move.w  #IPC_TIMEOUT,d1
.wait:
                btst    #6,(a0)
                dbeq    d1,.wait
                add.b   d0,d0
                btst    #7,(a0)                 ; and here is its answer
                beq.s   .zero
                addq.b  #1,d0
.zero:
                dbra    d2,.bit
                rts

; -----------------------------------------------------------------------------
;  IpcStart / IpcEnd - the addresses, and the interrupt the exchange raises
;  Merely talking to the IPC sets its interrupt pending. Nothing here services
;  interrupts -- the game masks them all -- but the flag has to be cleared or it
;  stays raised for ever. The mask bits are written as zero on purpose : this
;  game wants no interrupts at all.
;  Destroys : a0, a1 (IpcStart), d0 (IpcEnd)
; -----------------------------------------------------------------------------
IpcStart:
                lea     PC_IPCRD,a0
                lea     PC_IPCWR,a1
                rts

IpcEnd:
                move.b  #PC_INTRI,PC_INTR
                rts
