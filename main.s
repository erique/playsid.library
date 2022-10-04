;APS00000000000000000000000000000000000000000000000000000000000000000000000000000000
    incdir  include:
    include exec/exec_lib.i
    include playsid_lib.i
    include playsidbase.i

main
    move.l  4.w,a6
    lea     SIDName,a1
    jsr     _LVOOldOpenLibrary(a6)
    move.l  d0,SIDBase
    beq     .x
    move.l  d0,a6

    jsr     _LVOAllocEmulResource(a6)
    tst.l   d0
    bne     .x

    lea     Mod,a0
    lea     Header,a1
    moveq   #sidh_sizeof-1,d0
.c  move.b  (a0)+,(a1)+
    dbf     d0,.c

    lea     Header,a0
    lea     Mod,a1
    move.l  #ModLen,d0
    jsr     _LVOSetModule(a6)

    moveq   #50,d0
    jsr     _LVOSetVertFreq(a6)

    moveq   #1,d0   
    jsr     _LVOStartSong(a6)

.loop
    btst    #6,$bfe001
    bne     .loop

    jsr     _LVOStopSong(a6)
    jsr     _LVOFreeEmulResource(a6)
.x
    move.l  SIDBase,d0
    beq     .y
    move.l  d0,a1
    move.l  4.w,a6
    jsr     _LVOCloseLibrary(a6)
.y
    rts

SIDName     
  ifd __VASM
            dc.b    "PROGDIR:"
  endif
            dc.b    "playsid.library",0
SIDBase     dc.l    0
Header      ds.b    sidh_sizeof
Mod         incbin  Terra_Cresta.dat
ModLen      = *-Mod
