10 MODE 8
20 CLS

50 REM ASSEMBLER FOR SUPER BASIC
60 REM Everything is done for mode 8 (8 colors)
60 REM No clipping for now

100 REM SCREEN COPY FROM/TO BUFFER SAMPLE
101 REM COPY FROM SCREEN OR TO SCREEN TO OR FROM A BUFFER
102 REM PARAM : x screen, y screen, x size, y size, buffer, 0 (copy from screen to buffer) or 1 (copy from buffer to screen)
120 LBYTES mdv1_rose3_bin, 131072
150 screencopy = RESPR(256)
160 savebuffer = RESPR(100*100/2)
170 LBYTES mdv1_screencopy_bin, screencopy
180 CALL screencopy,0,0,100,100,savebuffer,0
190 CALL screencopy,80,80,100,100,savebuffer,1

400 PAUSE

700 REM CLEAR SCREEN XY & SIZE SAMPLE
701 REM CLEAR SCREEN at X Y with X and Y SIZE
702 REM PARAM : Color, x screen, y screen, x size, y size
710 clearxysizeadr=RESPR(128)
720 LBYTES win1_clearscreen_xy_size_bin,clearxysizeadr
730 CALL clearxysizeadr, HEX("AAFF"), 8, 8, 64, 64
740 CALL clearxysizeadr, HEX("AAAA"), 48, 48, 84, 84

750 PAUSE

800 REM SCREEN COPY SAMPLE
801 REM COPY FROM SCREEN TO SCREEN DIRECTLY (overlapping can be a problem)
802 REM PARAM : x source, y source, x dest, y dest, x size, y size
810 screen2screen=RESPR(256)
820 LBYTES win1_screen2screen_bin,screen2screen
830 CALL screen2screen, 48, 128, 8, 8, 16, 16

900 PAUSE

1000 REM CLEAR SCREEN SAMPLE
1002 REM PARAM : Colors (see samples below)
1003 REM Full screen is quite optimized compared to the ClearScreen with X, Y and size.
1010 clearsreenadr=RESPR(128)
1020 LBYTES win1_clearscreen_bin,clearsreenadr
1100 CALL clearsreenadr, HEX("AAFFAAFF")
1105 PRINT "WHITE"
1110 PAUSE
1120 CALL clearsreenadr, HEX("AA55AA55")
1125 PRINT "CYAN"
1130 PAUSE
1140 CALL clearsreenadr, HEX("00550055")
1145 PRINT "BLUE"
1150 PAUSE
1160 CALL clearsreenadr, HEX("AAAAAAAA")
1165 PRINT "YELLOW"
1170 PAUSE
1180 CALL clearsreenadr, HEX("55555555")
1185 PRINT "MAGENTA"
1190 PAUSE
1200 CALL clearsreenadr, HEX("AA00AA00")
1205 PRINT "GREEN"
1210 PAUSE
1220 CALL clearsreenadr, HEX("00AA00AA")
1225 PRINT "RED"
1230 PAUSE
1240 CALL clearsreenadr, HEX("00000000")
1245 PRINT "BLACK"

2300 sprite=RESPR(1280)
2310 LBYTES mdv1_ghostred_bin,sprite
2350 displaysprite16x16=RESPR(512)
2370 LBYTES win1_displaysprite16x16_bin,displaysprite16x16
2380 CALL displaysprite16x16, 60, 64, sprite
2381 CALL displaysprite16x16, 61, 64+16*1, sprite
2382 CALL displaysprite16x16, 62, 64+16*2, sprite
2383 CALL displaysprite16x16, 63, 64+16*3, sprite
