; sound_test.asm -- takeover demo with music: bouncing dot + IPC melody
;
; Same bare-metal base as takeover/takeover.asm (TRAP #0, interrupts
; masked, VBL sync by polling the ZX8302 frame bit -- see docs/takeover.md)
; plus a melody player driven once per frame. The 8049 IPC plays each note
; autonomously; the CPU only bit-bangs a new 8-byte sound command when the
; current note's frame count runs out (routines: ipc_sound.asm, included
; at the end of this file).
;
; Melody encoding: a table of events, each
;       dc.w  frames                 ; time until the next event, 50 Hz frames
;       dc.b  p1,p2,il,ih,dl,dh,gw,rf  ; 8-byte IPC block for snd_beep
; A frame count of 0 ends the table (the player loops back to the start);
; a block whose pitch1 byte is 0 is a rest (snd_kill instead of snd_beep).
; The note macro below builds an event from (frames, pitch+1): the IPC
; duration is set to frames*250 units (~10% short of the frame time) so
; the 8049 ends each note itself, leaving an articulation gap even between
; repeated notes of the same pitch.
;
; Assemble: vasmm68k_mot -m68008 -Fbin -o sound_test_bin sound_test.asm

; hardware (pc_ipcwr/pc_ipcrd/pc_intr come from ipc_sound.asm)
mc_stat     equ     $18063          ; ZX8301 display control (write-only)
pc__frame   equ     3               ; $18021 bit 3 = 50/60 Hz frame interrupt
sys_vars    equ     $28000          ; system variables base (a6 for snd_clrint)

scr_base    equ     $20000          ; mode 4 screen: 512x256, 2bpp, 32 KB
scr_llen    equ     128             ; bytes per scan line
scr_size    equ     $8000

dot_w       equ     4               ; dot size in pixels
dot_h       equ     4
x_max       equ     512-dot_w       ; bounce limits (top-left position)
y_max       equ     256-dot_h

; note pitches, stored as BASIC pitch + 1 (freq ~ 11447/(10.6+pitch) Hz)
n_g3        equ     49
n_c4        equ     34
n_d4        equ     29
n_e4        equ     25
n_f4        equ     23
n_g4        equ     20
n_a4        equ     16

qn          equ     25              ; quarter note = half a second

; note <frames>,<pitch+1> -- one melody event, IPC-timed articulation
note        macro
        dc.w    \1
        dc.b    \2,\2,0,0
        dc.b    (\1*250)&$ff,((\1*250)>>8)&$ff
        dc.b    0,0
        endm

; rest <frames> -- silence (pitch1 = 0 makes the player call snd_kill)
rest        macro
        dc.w    \1
        dc.b    0,0,0,0,0,0,0,0
        endm

; ---------------------------------------------------------------- job header
start:
        bra.s   main
        dc.l    0
        dc.w    $4afb               ; "job name follows" flag
        dc.w    jobname_e-jobname
jobname:
        dc.b    'SoundTest'
jobname_e:
        even

; ----------------------------------------------------------------- take over
main:
        trap    #0                  ; QDOS: enter supervisor mode
        move.w  #$2700,sr           ; mask all interrupts -- QDOS is gone now
        lea     sv_stack_top(pc),sp ; run on our own supervisor stack
        lea     sys_vars,a6         ; snd_clrint reads the mask byte at $35(a6)

        move.b  #0,mc_stat          ; mode 4, screen at $20000, display on

        lea     scr_base,a0         ; clear the screen to black
        move.w  #scr_size/4-1,d0
        moveq   #0,d1
.clr:   move.l  d1,(a0)+
        dbf     d0,.clr

        lea     mel_state(pc),a2    ; arm the melody player: absolute pointers
        move.w  #1,(a2)             ; must be set at runtime (flat binary),
        lea     melody(pc),a3       ; count 1 = first note fires on frame 1
        move.l  a3,2(a2)

        moveq   #0,d4               ; x position
        moveq   #0,d5               ; y position
        moveq   #2,d6               ; x speed, pixels/frame (even: hits x_max)
        moveq   #1,d7               ; y speed, pixels/frame

; ---------------------------------------------------------------- frame loop
main_loop:
        move.b  #1<<pc__frame,pc_intr   ; ack frame interrupt
.wait:  btst    #pc__frame,pc_intr     ; ...and wait for the next one
        beq.s   .wait                   ; (bit 3 only: bits 7..5 always move)

        bsr     erase               ; remove dot at old position

        add.w   d6,d4               ; step and bounce horizontally
        tst.w   d4
        beq.s   .flipx
        cmp.w   #x_max,d4
        bne.s   .xok
.flipx: neg.w   d6
.xok:
        add.w   d7,d5               ; step and bounce vertically
        tst.w   d5
        beq.s   .flipy
        cmp.w   #y_max,d5
        bne.s   .yok
.flipy: neg.w   d7
.yok:
        bsr     draw                ; draw dot at new position
        bsr     mel_tick            ; advance the melody (usually a no-op)
        bra.s   main_loop

; ------------------------------------------------------------- melody player
; Once per frame: count down, and when the current event expires send the
; next one to the IPC (~2 ms of bit-banging, comfortably inside one frame).
mel_tick:
        lea     mel_state(pc),a2
        move.w  (a2),d0             ; frames left on current event
        subq.w  #1,d0
        move.w  d0,(a2)
        bne.s   .done
        move.l  2(a2),a3            ; next event
        move.w  (a3)+,d0            ; its frame count...
        bne.s   .play
        lea     melody(pc),a3       ; ...0 = end of table: loop the melody
        move.w  (a3)+,d0
.play:  move.w  d0,(a2)
        tst.b   (a3)                ; pitch1 = 0 -> rest
        beq.s   .rest
        bsr     snd_beep            ; sends the block, advances a3 past it
        bra.s   .store
.rest:  bsr     snd_kill
        addq.l  #8,a3               ; skip the block by hand
.store: move.l  a3,2(a2)
.done:  rts

; --------------------------------------------------------------- dot drawing
; Same routines as takeover/takeover.asm: 16-bit pixel mask split over two
; adjacent screen words, OR into both planes to draw white, AND to erase.

; calcpos: d4/d5 (x/y) -> a0 = screen word address, d3.w = pixel mask
calcpos:
        move.w  d5,d0
        lsl.w   #7,d0               ; y * 128
        move.w  d4,d1
        lsr.w   #3,d1               ; 8-pixel group...
        add.w   d1,d1               ; ...2 bytes each
        add.w   d1,d0
        lea     scr_base,a0
        adda.w  d0,a0               ; max offset 32382, fits signed word
        move.w  #$f000,d3           ; dot_w pixels at the far left...
        move.w  d4,d2
        and.w   #7,d2
        lsr.w   d2,d3               ; ...shifted to x within the two words
        rts

draw:                               ; OR the mask into both colour planes
        bsr     calcpos
        move.w  d3,d2
        lsr.w   #8,d2               ; d2 = mask for first word, d3 = second
        moveq   #dot_h-1,d0
.row:   or.b    d2,(a0)             ; green plane, first word
        or.b    d2,1(a0)            ; red plane -> white
        or.b    d3,2(a0)            ; green plane, second word
        or.b    d3,3(a0)            ; red plane
        lea     scr_llen(a0),a0
        dbf     d0,.row
        rts

erase:                              ; AND the inverted mask: back to black
        bsr     calcpos
        not.w   d3
        move.w  d3,d2
        lsr.w   #8,d2
        moveq   #dot_h-1,d0
.row:   and.b   d2,(a0)
        and.b   d2,1(a0)
        and.b   d3,2(a0)
        and.b   d3,3(a0)
        lea     scr_llen(a0),a0
        dbf     d0,.row
        rts

; ---------------------------------------------------------------------- data
        even
mel_state:
        dc.w    0                   ; frames left (armed at runtime)
        dc.l    0                   ; pointer to next event (set at runtime)

; Frere Jacques, one voice, looping (quarter = 25 frames = 0.5 s)
melody:
        note    qn,n_c4             ; Fre-re Jac-ques
        note    qn,n_d4
        note    qn,n_e4
        note    qn,n_c4
        note    qn,n_c4
        note    qn,n_d4
        note    qn,n_e4
        note    qn,n_c4
        note    qn,n_e4             ; dor-mez vous
        note    qn,n_f4
        note    2*qn,n_g4
        note    qn,n_e4
        note    qn,n_f4
        note    2*qn,n_g4
        note    12,n_g4             ; son-nez les ma-ti-nes
        note    12,n_a4
        note    13,n_g4
        note    13,n_f4
        note    qn,n_e4
        note    qn,n_c4
        note    12,n_g4
        note    12,n_a4
        note    13,n_g4
        note    13,n_f4
        note    qn,n_e4
        note    qn,n_c4
        note    qn,n_c4             ; ding dang dong
        note    qn,n_g3
        note    2*qn,n_c4
        note    qn,n_c4
        note    qn,n_g3
        note    2*qn,n_c4
        rest    qn                  ; breathe, then loop
        dc.w    0                   ; end of melody: player restarts

        even
sv_stack:
        ds.b    64                  ; private supervisor stack
sv_stack_top:

; IPC sound routines (must be last: the file ends with an "end" directive)
; ============================================================================
; Direct IPC sound access for the Sinclair QL - no QDOS traps
; ----------------------------------------------------------------------------
; Protocol verified against:
;   - Minerva 1.98 sources: inc/ipcmd, inc/pc, ip/int.asm, bp/beep.asm
;   - JS ROM disassembly:   L02F6E / L02F7C / L02F8E (send), L02F96 (receive)
;   - IPC 8049 disassembly: IPCOM $A "set sound" at $0300, kill at $031F
;
; HOW THE LINK WORKS
;   Send:    write %11d0 to $18003 (d = data bit, MSB first), then poll
;            bit 6 of $18020 until it drops = 8049 has taken the bit.
;   Receive: write %1110 to $18003 (must assert 1 to read), poll bit 6
;            of $18020, then bit 7 of $18020 is the data bit. MSB first.
;   A command starts with a 4-bit command nibble, followed by however
;   many parameter bits that command requires. Get the count wrong and
;   the 8049 hangs until reset - there is no error recovery.
;
; SOUND COMMAND ($A) PARAMETER STREAM - exactly 64 bits after the nibble:
;   byte  pitch1          (BASIC pitch + 1)
;   byte  pitch2          (BASIC pitch2 + 1)
;   word  step interval   LSB BYTE FIRST
;   word  duration        LSB BYTE FIRST, 0 = play forever
;   nib   pitch gradient  (signed 4-bit step)
;   nib   wrap
;   nib   random          (none unless msb set)
;   nib   fuzz            (none unless msb set)
;   The 8049 then plays the sound AUTONOMOUSLY - no further CPU needed.
;
; RULES
;   - Interrupts MUST be masked around every transaction: the QDOS 50Hz
;     polling interrupt also talks to the IPC (keyboard) and interleaved
;     transfers corrupt the link.
;   - If QDOS is still running, clear the IPC interrupt at $18021 after
;     each transfer (see snd_clrint). If you have taken over the machine
;     with level-2 interrupts masked, you can skip it - but then you must
;     also read the keyboard yourself via IPC command 9 (keyrow).
;   - Budget: ~68 bit transactions for a full beep = on the order of a
;     couple of milliseconds. Send at most one per frame; per-event is
;     the normal pattern. Kill is only 4 bits - essentially free.
; ============================================================================

pc_ipcwr equ    $18003          ; W: bit1=COMDATA, bits 2,3=1, bit0=0
pc_ipcrd equ    $18020          ; R: bit6=busy, bit7=data from IPC
pc_intr  equ    $18021          ; W: bit1 (+mask bits 7..5) clears IPC int
sv_pcint equ    $35             ; sysvar offset: interrupt mask byte

inso_cmd equ    10              ; start sound
kiso_cmd equ    11              ; kill sound
stat_cmd equ    1               ; read status (bit1 = sound playing)

; ----------------------------------------------------------------------------
; snd_beep - start a sound. The 8049 keeps playing it on its own.
; In:  a3 -> 8-byte parameter block:
;        +0  pitch1 (already +1)
;        +1  pitch2 (already +1)
;        +2  interval low byte    +3  interval high byte
;        +4  duration low byte    +5  duration high byte
;        +6  gradient<<4 | wrap
;        +7  random<<4  | fuzz
; Trashes d0-d2. Call with a3 pointing at one of your note/effect tables.
; ----------------------------------------------------------------------------
snd_beep
        move    sr,-(sp)
        ori     #$0700,sr       ; own the link exclusively
        moveq   #inso_cmd,d0
        bsr.s   ipc_nib         ; command nibble $A
        moveq   #6-1,d2
.bytes  move.b  (a3)+,d0
        bsr.s   ipc_byte        ; pitch1,pitch2,int_lo,int_hi,dur_lo,dur_hi
        dbf     d2,.bytes
        move.b  (a3)+,d0        ; gradient / wrap
        bsr.s   ipc_byte        ;   (two nibbles = one byte send)
        move.b  (a3)+,d0        ; random / fuzz
        bsr.s   ipc_byte
        bsr.s   snd_clrint      ; remove if you own the whole machine
        move    (sp)+,sr
        rts

; ----------------------------------------------------------------------------
; snd_kill - stop sound immediately. 4 bit transactions only.
; ----------------------------------------------------------------------------
snd_kill
        move    sr,-(sp)
        ori     #$0700,sr
        moveq   #kiso_cmd,d0
        bsr.s   ipc_nib
        bsr.s   snd_clrint
        move    (sp)+,sr
        rts

; ----------------------------------------------------------------------------
; snd_stat - read IPC status byte. Returns d0.b, bit1 set = still playing.
; Costs a full round trip (~12 bit transactions); counting frames against
; the duration you sent is usually cheaper in a game loop.
; ----------------------------------------------------------------------------
snd_stat
        move    sr,-(sp)
        ori     #$0700,sr
        moveq   #stat_cmd,d0
        bsr.s   ipc_nib
        moveq   #0,d0
        moveq   #8-1,d2
.rd     move.b  #%1110,pc_ipcwr ; assert 1 so the IPC can pull the line
.wait   btst    #6,pc_ipcrd
        bne.s   .wait
        move.b  pc_ipcrd,d1
        add.b   d1,d1           ; bit7 -> X
        addx.b  d0,d0           ; shift into result, MSB first
        dbf     d2,.rd
        bsr.s   snd_clrint
        move    (sp)+,sr
        rts

; ----------------------------------------------------------------------------
; ipc_byte - send d0.b to the IPC, MSB first (as two nibbles)
; ipc_nib  - send low nibble of d0.b to the IPC
; Interrupts must already be masked. Trashes d0/d1.
; Bit pattern per JS ROM L02F7C: shift nibble to bits 7..4, OR in bit 3
; as an end marker, then shift bits out until only the marker is left.
; ----------------------------------------------------------------------------
ipc_byte
        move.b  d0,-(sp)
        lsr.b   #4,d0
        bsr.s   ipc_nib         ; high nibble
        move.b  (sp)+,d0        ; low nibble falls through
ipc_nib
        lsl.b   #4,d0           ; nibble to bits 7..4 (junk above discarded)
        ori.b   #%00001000,d0   ; end marker in bit 3
.bit    lsl.b   #1,d0           ; next data bit -> X
        beq.s   .done           ; only the marker was left: all 4 bits sent
        moveq   #%11,d1
        roxl.b  #1,d1           ; %011d
        lsl.b   #1,d1           ; %11d0
        move.b  d1,pc_ipcwr
.wait   btst    #6,pc_ipcrd     ; wait for the 8049 to take the bit
        bne.s   .wait
        bra.s   .bit
.done   rts

; ----------------------------------------------------------------------------
; snd_clrint - clear the level-2 interrupt raised by talking to the IPC.
; Only needed while QDOS is alive and level-2 interrupts are in use.
; a6 must hold the system variables base ($28000) as usual in supervisor
; mode, or hard-code it if calling from your own environment.
; ----------------------------------------------------------------------------
snd_clrint
        moveq   #%10,d1         ; pc.intri
        or.b    sv_pcint(a6),d1 ; keep the enable mask bits 7..5
        move.b  d1,pc_intr
        rts

; ----------------------------------------------------------------------------
; Example note/effect tables
; interval and duration are in IPC time units (same as SuperBASIC BEEP);
; duration 0 = sustain until snd_kill or next snd_beep.
; ----------------------------------------------------------------------------
sfx_laser
        dc.b    5,80            ; pitch1+1, pitch2+1 (fast sweep pair)
        dc.b    2,0             ; interval = 2 (lo,hi)
        dc.b    $00,$04         ; duration = $0400 (lo,hi)
        dc.b    $10             ; gradient=1, wrap=0
        dc.b    $00             ; random=0, fuzz=0

note_a4
        dc.b    26,26           ; steady tone: pitch1 = pitch2
        dc.b    0,0             ; no stepping
        dc.b    $88,$13         ; duration $1388 = 5000 units
        dc.b    $00
        dc.b    $00

; Melody idea: table of 8-byte blocks + frame counts; in your VBlank
; handler decrement the count and snd_beep the next block when it hits 0.
; That is one ~2ms transfer every N frames - negligible.

        end