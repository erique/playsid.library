	section .data,data_p

DAT_002273d4
	dc.b	$00,$20,$20,$20,$20,$20,$20,$20,$20,$20,$28,$28,$28,$28,$28,$20
	dc.b	$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	dc.b	$20,$48,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	dc.b	$10,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$10,$10,$10,$10,$10
	dc.b	$10,$10,$81,$81,$81,$81,$81,$81,$01,$01,$01,$01,$01,$01,$01,$01
	dc.b	$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$10,$10,$10,$10
	dc.b	$10,$10,$82,$82,$82,$82,$82,$82,$02,$02,$02,$02,$02,$02,$02,$02
	dc.b	$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$10,$10,$10,$10
	dc.b	$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00

DAT_002273d0
	dc.l $00000000

	section .text,code_p

@AllocEmulAudio_impl
     subq.w     #$4,sp
     move.l     a6,-(sp)
     lea        (DAT_00227568,pc),a0
     lea        ($7,sp),a1
     move.b     (a0)+,(a1)+
     movea.l    ($4).w,a6
     jsr        (-$29a,a6)              ; _LVOCreateMsgPort
     movea.l    (_PlaySidBase).l,a0
     move.l     d0,($16c,a0)            ; psb_AudioMP
     beq.b      LAB_0022755c
     moveq      #$44,d0                 ; ioa_SIZEOF
     move.l     #$10001,d1              ; MEMF_PUBLIC!MEMF_CLEAR
     jsr        (-$c6,a6)               ; _LVOAllocMem
     tst.l      d0
     beq.b      LAB_0022755c
     movea.l    (_PlaySidBase).l,a0
     move.l     d0,($168,a0)            ; psb_AudioIO
     movea.l    d0,a1
     move.l     ($16c,a0),($e,a1)       ; psb_AudioMP,MN_REPLYPORT
     move.b     #$7f,($9,a1)            ; LN_PRI
     clr.w      ($20,a1)                ; ioa_AllocKey
     lea        ($7,sp),a0
     move.l     a0,($22,a1)             ; ioa_Data
     moveq      #$1,d1
     move.l     d1,($26,a1)             ; ioa_Length
     moveq      #$0,d0
     move.l     d0,d1
     lea        (audio_device,pc),a0
     jsr        (-$1bc,a6)              ; _LVOOpenDevice
     move.b     d0,d1
     ext.w      d1
     movea.l    (_PlaySidBase).l,a0
     move.w     d1,($166,a0)            ; psb_AudioDevice
     bne.b      LAB_0022755c
     moveq      #$0,d0
     bra.b      LAB_00227562
LAB_0022755c
      bsr.w      @FreeEmulAudio_impl
      moveq      #-$2,d0
LAB_00227562
      movea.l    (sp)+,a6
      addq.w     #$4,sp
      rts
DAT_00227568
      dc.b $0F
      dc.b $00
audio_device:
      dc.b         "audio.device",0
      even

@FreeEmulAudio_impl
    move.l     a6,-(sp)
    movea.l    (_PlaySidBase).l,a0
    tst.w      ($166,a0)                ; psb_AudioDevice
    bne.b      LAB_0022759e
    movea.l    ($168,a0),a1             ; psb_AudioIO
    movea.l    ($4).w,a6
    jsr        (-$1c2,a6)               ; _LVOCloseDevice
    movea.l    (_PlaySidBase).l,a0
    move.w     #$1,($166,a0)            ; psb_AudioDevice
LAB_0022759e
    movea.l    (_PlaySidBase).l,a0
    move.l     ($168,a0),d0             ; psb_AudioIO
    beq.b      LAB_002275c0
    movea.l    d0,a1
    moveq      #$44,d0                  ; ioa_SIZEOF
    movea.l    ($4).w,a6
    jsr        (-$d2,a6)                ; _LVOFreeMem
    movea.l    (_PlaySidBase).l,a0
    clr.l      ($168,a0)                ; psb_AudioIO
LAB_002275c0
    movea.l    (_PlaySidBase).l,a0
    move.l     ($16c,a0),d0             ; psb_AudioMP
    beq.b      LAB_002275e0
    movea.l    d0,a0
    movea.l    ($4).w,a6
    jsr        (-$2a0,a6)               ; _LVODeleteMsgPort
    movea.l    (_PlaySidBase).l,a0
    clr.l      ($16c,a0)                ; psb_AudioMP
LAB_002275e0
    movea.l    (sp)+,a6
    rts

@ReadIcon
	suba.w     #$98,sp
	movem.l    d7/a2-a6,-(sp)
	lea        (DAT_002273d4).l,a4
    moveq      #$0,d7
    move.l     a1,($24,sp)
    lea        (s_icon_library_0022780c,pc),a1
    moveq      #$21,d0
    movea.l    ($4).w,a6
    movea.l    a0,a2
    jsr        (-$228,a6)
    movea.l    d0,a5
    tst.l      d0
    bne.b      LAB_00227614
    moveq      #-$8,d0
    bra.w      LAB_00227802
LAB_00227614
    tst.b      (a2)
    beq.w      LAB_002277f2+2
    movea.l    a2,a0
    movea.l    a5,a6
    jsr        (-$4e,a6)
    movea.l    d0,a0
    move.l     d0,($1c,sp)
    beq.w      LAB_002277f2+2
    lea        ($28,sp),a3
    move.l     #$50534944,(a3)+
    move.w     #$2,(a3)+
    move.w     #$7c,(a3)+
    clr.w      ($9e,sp)
    movea.l    ($36,a0),a2
    movea.l    a2,a0
    lea        (s_SIDSONG_0022781a,pc),a1
    jsr        (-$60,a6)
    movea.l    d0,a3
    tst.l      d0
    beq.b      LAB_0022767c
    movea.l    a3,a0
    lea        (DAT_00227822,pc),a1
    bsr.w      FUN_00227878
    tst.l      d0
    bne.b      LAB_0022766c
    bset.b     #$0,($9f,sp)
    bra.b      LAB_0022767c
LAB_0022766c
    movea.l    a3,a0
    lea        (DAT_00227826,pc),a1
    bsr.w      FUN_00227878
    tst.l      d0
    beq.b      LAB_0022767c
    moveq      #-$7,d7
LAB_0022767c
    movea.l    a2,a0
    lea        (s_ADDRESS_0022782a,pc),a1
    jsr        (-$60,a6)
    tst.l      d0
    beq.b      LAB_002276c0
    pea        ($a4,sp)
    pea        ($ac,sp)
    pea        ($b4,sp)
    pea        (s_fmt_00227832,pc)
    move.l     d0,-(sp)
    bsr.w      FUN_002278d0
    subq.l     #$3,d0
    lea        ($14,sp),sp
    bne.b      LAB_002276c0
    move.l     ($ac,sp),d0
    lea        ($30,sp),a3
    move.w     d0,(a3)+
    move.l     ($a8,sp),d0
    move.w     d0,(a3)+
    move.l     ($a4,sp),d0
    move.w     d0,(a3)+
    bra.b      LAB_002276ca
LAB_002276c0
    btst.b     #$0,($9f,sp)
    bne.b      LAB_002276ca
    moveq      #-$7,d7
LAB_002276ca
    moveq      #$1,d0
    move.w     d0,($36,sp)
    move.w     d0,($38,sp)
    lea        (s_SONGS_0022783c,pc),a1
    movea.l    a2,a0
    jsr        (-$60,a6)
    movea.l    d0,a3
    tst.l      d0
    beq.b      LAB_00227732
    pea        ($a8,sp)
    pea        ($b0,sp)
    pea        (s_fmt2_00227842,pc)
    move.l     a3,-(sp)
    bsr.w      FUN_002278d0
    subq.l     #$2,d0
    lea        ($10,sp),sp
    bne.b      LAB_00227710
    move.l     ($ac,sp),d0
    move.w     d0,($36,sp)
    move.l     ($a8,sp),d0
    move.w     d0,($38,sp)
    bra.b      LAB_00227732
LAB_00227710
    pea        ($ac,sp)
    pea        (DAT_00227848,pc)
    move.l     a3,-(sp)
    bsr.w      FUN_002278d0
    subq.l     #$1,d0
    lea        ($c,sp),sp
    bne.b      LAB_0022772e+2
    move.l     ($ac,sp),d0
    move.w     d0,($36,sp)

LAB_0022772e
    cmpi.w     #$7ef9,d0
LAB_00227732
    btst.b     #$0,($9f,sp)
    beq.b      LAB_00227742
    moveq      #$1,d0
    move.l     d0,($3a,sp)
    bra.b      LAB_00227746
LAB_00227742
    clr.l      ($3a,sp)
LAB_00227746
    movea.l    a2,a0

    lea        (s_SPEED_0022784c,pc),a1
    jsr        (-$60,a6)
    tst.l      d0
    beq.b      LAB_00227774
    pea        ($ac,sp)
    pea        (DAT_00227852,pc)
    move.l     d0,-(sp)
    bsr.w      FUN_002278d0
    subq.l     #$1,d0
    lea        ($c,sp),sp
    bne.b      LAB_00227770+2
    move.l     ($ac,sp),($3a,sp)
LAB_00227770
    cmpi.w     #$7ef9,d0
LAB_00227774
    movea.l    a2,a0
    lea        (DAT_00227856,pc),a1
    jsr        (-$60,a6)
    movea.l    d0,a1
    tst.l      d0
    bne.b      LAB_00227788
    lea        (DAT_0022785c,pc),a1
LAB_00227788
    lea        ($3e,sp),a0
    moveq      #$1f,d0
    bsr.w      FUN_002278b8
    clr.b      ($5d,sp)
    lea        (s_AUTHOR_0022785e,pc),a1
    movea.l    a2,a0
    jsr        (-$60,a6)
    movea.l    d0,a1
    tst.l      d0
    bne.b      LAB_002277aa
    lea        (DAT_0022785c,pc),a1
LAB_002277aa
    lea        ($5e,sp),a0
    moveq      #$1f,d0
    bsr.w      FUN_002278b8
    clr.b      ($7d,sp)
    lea        (s_COPYRIGHT_00227866,pc),a1
    movea.l    a2,a0
    jsr        (-$60,a6)
    movea.l    d0,a1
    tst.l      d0
    bne.b      LAB_002277cc
    lea        (DAT_0022785c,pc),a1
LAB_002277cc
    lea        ($7e,sp),a0
    moveq      #$1f,d0
    bsr.w      FUN_002278b8
    clr.b      ($9d,sp)
    moveq      #$7b,d0
    lea        ($28,sp),a0
    movea.l    ($24,sp),a1
LAB_002277e4
    move.b     (a0)+,(a1)+
    dbf        d0,LAB_002277e4
    movea.l    ($1c,sp),a0
    jsr        (-$5a,a6)


LAB_002277f2
    cmpi.w     #$7efa,d0
    movea.l    a5,a1
    movea.l    ($4).w,a6
    jsr        (-$19e,a6)
    move.l     d7,d0
LAB_00227802
    movem.l    (sp)+,d7/a2-a6
    adda.w     #$98,sp
    rts


s_icon_library_0022780c
    dc.b         "icon.library",0
    dc.b         $00

s_SIDSONG_0022781a
    dc.b         "SIDSONG",0
DAT_00227822
    dc.b         "YES",0
DAT_00227826
    dc.b         "NO",0
    dc.b         $00
s_ADDRESS_0022782a
    dc.b         "ADDRESS",0
s_fmt_00227832
    dc.b         "%x,%x,%x",0
    dc.b         $00
s_SONGS_0022783c
    dc.b         "SONGS",0
s_fmt2_00227842
    dc.b         "%d,%d",0
DAT_00227848
    dc.b         "%d",0
    dc.b         $00
s_SPEED_0022784c
    dc.b         "SPEED",0
DAT_00227852
    dc.b         "%lx",0
DAT_00227856
    dc.b         "NAME",0
    dc.b         $00
DAT_0022785c
    dc.b         "?",0
s_AUTHOR_0022785e
    dc.b         "AUTHOR",0
    dc.b         $00
s_COPYRIGHT_00227866
    dc.b         "COPYRIGHT",0
    dc.b         $20
    dc.b         $6F
    dc.b         $00
    dc.b         $04
    dc.b         $22
    dc.b         $6F
    dc.b         $00
    dc.b         $08

    even

FUN_00227878
    moveq      #$0,d0
    moveq      #$0,d1
LAB_0022787c
    move.b     (a0)+,d0
    move.b     (a1)+,d1
    cmpi.b     #$61,d0
    blt.b      LAB_00227890
    cmpi.b     #$7a,d0
    bgt.b      LAB_00227890
    subi.b     #$20,d0
LAB_00227890
    cmpi.b     #$61,d1
    blt.b      LAB_002278a0
    cmpi.b     #$7a,d1
    bgt.b      LAB_002278a0
    subi.b     #$20,d1
LAB_002278a0
    sub.l      d1,d0
    bne.b      LAB_002278a8
    tst.b      d1
    bne.b      LAB_0022787c
LAB_002278a8
    rts
    dc.b         $00
    dc.b         $00
    dc.b         $22
    dc.b         $6F
    dc.b         $00
    dc.b         $08
    dc.b         $20
    dc.b         $6F
    dc.b         $00
    dc.b         $04
    dc.b         $20
    dc.b         $2F
    dc.b         $00
    dc.b         $0C


FUN_002278b8
    move.l     a0,d1
    bra.b      LAB_002278c0
LAB_002278bc
    move.b     (a1)+,(a0)+
    beq.b      LAB_002278c8
LAB_002278c0
    subq.l     #$1,d0
    bcc.b      LAB_002278bc
    bra.b      LAB_002278cc
LAB_002278c6
    clr.b      (a0)+
LAB_002278c8 
    subq.l     #$1,d0
    bcc.b      LAB_002278c6
LAB_002278cc
    move.l     d1,d0
    rts

FUN_002278d0
    movea.l    ($4,sp),a0
    clr.l      ($104,a4)
    move.l     a0,($108,a4)
    pea        ($c,sp)
    move.l     ($c,sp),-(sp)
    pea        ($104,a4)
    lea        (LAB_002278fa,pc),a0
    lea        (LAB_0022791a,pc),a1
    bsr.w      FUN_00227f66
    lea        ($c,sp),sp
    rts
LAB_002278fa
    lea        ($104,a4),a1
    addq.l     #$1,(a1)+
    movea.l    (a1),a0
    moveq      #$0,d0
    move.b     (a0)+,d0
    move.l     a0,(a1)
    moveq      #-$1,d1
    move.l     a0,(a1)+
    tst.l      d0
    beq.b      LAB_00227912
    move.l     d0,d1
LAB_00227912
    move.l     d1,d0
    rts
    dc.b         $20
    dc.b         $2F
    dc.b         $00
    dc.b         $04
LAB_0022791a
    subq.w     #$4,sp
    move.l     d0,(sp)
    subq.l     #$1,($104,a4)
    subq.l     #$1,($108,a4)
    addq.w     #$4,sp
    rts
    nop
    movea.l    ($4,sp),a0
    movea.l    ($8,sp),a1
    move.l     ($c,sp),($4,sp)
    move.l     ($10,sp),($8,sp)
    move.l     ($14,sp),($c,sp)
    move.l     ($18,sp),($10,sp)

FUN_0022794c:
    suba.w     #$10,sp
    movem.l	   d4-d7/a2-a3/a5-a6,-(sp)
    movea.l    ($3c,sp),a3
    movea.l    a1,a5
    movea.l    ($40,sp),a2
    moveq      #$0,d7
    moveq      #$0,d6
    moveq      #$0,d5
    move.l     a0,($24,sp)
    move.l     a3,d0
    beq.b      LAB_00227970+2
    moveq      #$1,d0
    move.l     d0,(a2)
LAB_00227970
    cmpi.w     #$4292,d0
    moveq      #$0,d0
    move.b     (a0),d0
    lea        ($1,a4),a0
    btst.b     #$2,($0,a0,d0.l)
    beq.b      LAB_002279b2
LAB_00227984
    moveq      #$f,d0
    lea        ($24,sp),a6
    movea.l    (a6),a0
    and.b      (a0)+,d0
    ext.w      d0
    ext.l      d0
    move.l     d7,d1
    asl.l      #$2,d1
    add.l      d7,d1
    add.l      d1,d1
    add.l      d0,d1
    move.l     d1,d7
    move.l     a0,(a6)
    moveq      #$0,d0
    movea.l    (a6)+,a0
    move.b     (a0),d0
    lea        ($1,a4),a0
    btst.b     #$2,($0,a0,d0.l)
    bne.b      LAB_00227984
LAB_002279b2
    movea.l    ($24,sp),a0
    move.b     (a0),d0
    moveq      #$6c,d1
    cmp.b      d1,d0
    beq.b      LAB_002279d2
    moveq      #$68,d1
    cmp.b      d1,d0
    bne.b      LAB_002279cc
    addq.l     #$1,($24,sp)
    moveq      #$1,d6
    bra.b      LAB_002279d8
LAB_002279cc
    moveq      #$4c,d1
    cmp.b      d1,d0
    bne.b      LAB_002279d8
LAB_002279d2
    addq.l     #$1,($24,sp)
    moveq      #$1,d5
LAB_002279d8
    move.l     d6,($28,sp)
    move.l     d5,($2c,sp)
    jsr        (a5)
    movea.l    ($24,sp),a0
    move.l     d0,d4
    move.b     (a0),d0
    moveq      #$63,d1
    cmp.b      d1,d0
    beq.b      LAB_00227a0e
    moveq      #$6e,d1
    cmp.b      d1,d0
    beq.b      LAB_00227a0e
    moveq      #$5b,d1
    cmp.b      d1,d0
    beq.b      LAB_00227a0e
    bra.b      LAB_00227a02
LAB_002279fe
    jsr        (a5)
    move.l     d0,d4
LAB_00227a02
    lea        ($1,a4),a0
    btst.b     #$3,($0,a0,d4.l)
    bne.b      LAB_002279fe
LAB_00227a0e
    moveq      #-$1,d0
    cmp.l      d0,d4
    bne.b      LAB_00227a20
    movea.l    ($38,sp),a0
    move.l     d4,(a0)
    moveq      #$0,d0
    bra.w      LAB_00227f40
LAB_00227a20
    movea.l    ($24,sp),a0
    moveq      #$0,d0
    move.b     (a0),d0
    moveq      #$58,d1
    sub.l      d1,d0
    blt.w      caseD_59
    cmpi.l     #$21,d0
    bge.w      caseD_59
    add.w      d0,d0
    move.w     (switchdataD_00227a44,pc,d0.w),d0
switchD
    jmp        (switchdataD_00227a46,pc,d0)
switchdataD_00227a44
    dc.w     $1FE
switchdataD_00227a46
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $362
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $300
    dc.w     $FE
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $78
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $40
    dc.w     $192
    dc.w     $1EE
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $332
    dc.w     $4E8
    dc.w     $DE
    dc.w     $4E8
    dc.w     $4E8
    dc.w     $1FE

caseD_6e
    moveq      #$0,d0
    move.l     d0,(a2)
    move.l     a3,d1
    beq.w      LAB_00227f32
    movea.l    ($34,sp),a2
    tst.l      d6
    bne.b      LAB_00227aa8
    tst.l      d5
    bne.b      LAB_00227aa8
    move.l     (a2),d1
    subq.l     #$1,d1
    movea.l    (a3),a0
    move.l     d1,(a0)
    bra.w      LAB_00227f32
LAB_00227aa8
    move.l     (a2),d5
    subq.l     #$1,d5
    tst.l      d6
    movea.l    (a3),a2
    beq.b      LAB_00227ab8
    move.w     d5,(a2)
    bra.w      LAB_00227f32
LAB_00227ab8
    move.l     d5,(a2)
    bra.w      LAB_00227f32
caseD_69
    moveq      #$0,d5
    tst.l      d7
    beq.b      LAB_00227aca
    moveq      #$1,d0
    cmp.l      d0,d7
    ble.b      LAB_00227ae8
LAB_00227aca
    moveq      #$2d,d0
    cmp.l      d0,d4
    beq.b      LAB_00227ad6
    moveq      #$2b,d1
    cmp.l      d1,d4
    bne.b      LAB_00227ae8
LAB_00227ad6
    cmp.l      d0,d4
    bne.b      LAB_00227adc+2
    moveq      #-$1,d0
LAB_00227adc
    cmpi.w     #$7000,d0
    move.l     d0,d5
    jsr        (a5)
    move.l     d0,d4
    subq.l     #$1,d7
LAB_00227ae8
    moveq      #$30,d0
    cmp.l      d0,d4
    bne.w      LAB_00227b6e
    jsr        (a5)
    lea        ($1,a4),a2
    adda.l     d0,a2
    move.l     d0,d4
    btst.b     #$1,(a2)
    beq.b      LAB_00227b06+2
    move.l     d4,d0
    moveq      #$20,d1
    sub.l      d1,d0
LAB_00227b06
    cmpi.w     #$2004,d0
    moveq      #$58,d1
    cmp.l      d1,d0
    beq.w      LAB_00227c4e
    btst.b     #$2,(a2)
    beq.b      LAB_00227b20
    moveq      #$38,d0
    cmp.l      d0,d4
    blt.w      LAB_00227bf0
LAB_00227b20
    moveq      #$0,d6
    bra.b      LAB_00227b9c
caseD_75
    moveq      #$0,d5
    moveq      #$2d,d0
    cmp.l      d0,d4
    beq.b      LAB_00227b32
    moveq      #$2b,d1
    cmp.l      d1,d4
    bne.b      LAB_00227b6e
LAB_00227b32
    cmp.l      d0,d4
    bne.b      LAB_00227b38+2
    moveq      #-$1,d0
LAB_00227b38
    cmpi.w     #$7000,d0
    move.l     d0,d5
    jsr        (a5)
    move.l     d0,d4
    bra.b      LAB_00227b6e
caseD_64
    moveq      #$0,d5
    tst.l      d7
    beq.b      LAB_00227b50
    moveq      #$1,d0
    cmp.l      d0,d7
    ble.b      LAB_00227b6e
LAB_00227b50
    moveq      #$2d,d0
    cmp.l      d0,d4
    beq.b      LAB_00227b5c
    moveq      #$2b,d1
    cmp.l      d1,d4
    bne.b      LAB_00227b6e
LAB_00227b5c
    cmp.l      d0,d4
    bne.b      LAB_00227b62+2
    moveq      #-$1,d0
LAB_00227b62
    cmpi.w     #$7000,d0
    move.l     d0,d5
    jsr        (a5)
    move.l     d0,d4
    subq.l     #$1,d7
LAB_00227b6e
    lea        ($1,a4),a0
    btst.b     #$2,($0,a0,d4.l)
    bne.b      LAB_00227b86
    movea.l    ($38,sp),a0
    move.l     d4,(a0)
    moveq      #$0,d0
    bra.w      LAB_00227f40
LAB_00227b86
    moveq      #$0,d6
LAB_00227b88
    moveq      #$f,d1
    and.l      d1,d4
    move.l     d6,d1
    asl.l      #$2,d1
    add.l      d6,d1
    add.l      d1,d1
    add.l      d4,d1
    move.l     d1,d6
    jsr        (a5)
    move.l     d0,d4
LAB_00227b9c
    subq.l     #$1,d7
    beq.b      LAB_00227bac
    lea        ($1,a4),a0
    btst.b     #$2,($0,a0,d4.l)
    bne.b      LAB_00227b88
LAB_00227bac
    move.l     a3,d0
    beq.w      LAB_00227f32
    tst.l      d5
    bpl.b      LAB_00227bb8
    neg.l      d6
LAB_00227bb8
    movea.l    (a3),a2
    tst.l      ($2c,sp)
    beq.b      LAB_00227bc6
    move.l     d6,(a2)
    bra.w      LAB_00227f32
LAB_00227bc6
    tst.l      ($28,sp)
    beq.b      LAB_00227bd2
    move.w     d6,(a2)
    bra.w      LAB_00227f32
LAB_00227bd2
    move.l     d6,(a2)
    bra.w      LAB_00227f32
caseD_6f
    moveq      #$30,d0
    cmp.l      d0,d4
    blt.b      LAB_00227be4
    moveq      #$37,d0
    cmp.l      d0,d4
    ble.b      LAB_00227bf0
LAB_00227be4
    movea.l    ($38,sp),a0
    move.l     d4,(a0)
    moveq      #$0,d0
    bra.w      LAB_00227f40
LAB_00227bf0
    moveq      #$0,d6
LAB_00227bf2
    moveq      #$7,d1
    and.l      d1,d4
    asl.l      #$3,d6
    add.l      d4,d6
    jsr        (a5)
    move.l     d0,d4
    subq.l     #$1,d7
    beq.b      LAB_00227c0e
    moveq      #$30,d0
    cmp.l      d0,d4
    blt.b      LAB_00227c0e
    moveq      #$37,d0
    cmp.l      d0,d4
    ble.b      LAB_00227bf2
LAB_00227c0e
    move.l     a3,d0
    beq.w      LAB_00227f32
    movea.l    (a3),a2
    tst.l      ($2c,sp)
    beq.b      LAB_00227c22
    move.l     d6,(a2)
    bra.w      LAB_00227f32
LAB_00227c22
    tst.l      ($28,sp)
    beq.b      LAB_00227c2e
    move.w     d6,(a2)
    bra.w      LAB_00227f32
LAB_00227c2e
    move.l     d6,(a2)
    bra.w      LAB_00227f32
caseD_70
    tst.l      d7
    bne.b      LAB_00227c3a
    moveq      #$8,d7
LAB_00227c3a
    clr.l      ($28,sp)
    moveq      #$1,d0
    move.l     d0,($2c,sp)
caseD_78
caseD_58
    moveq      #$1,d5
    moveq      #$2d,d0
    cmp.l      d0,d4
    bne.b      LAB_00227c52
    moveq      #-$1,d5
LAB_00227c4e
    jsr        (a5)
    move.l     d0,d4
LAB_00227c52
    movea.l    ($38,sp),a2
    move.l     d5,($20,sp)
    lea        ($1,a4),a0
    btst.b     #$7,($0,a0,d4.l)
    bne.b      LAB_00227c6e
    move.l     d4,(a2)
    moveq      #$0,d0
    bra.w      LAB_00227f40
LAB_00227c6e
    move.l     d4,d5
    jsr        (a5)
    move.l     d0,d4
    tst.l      d7
    beq.b      LAB_00227c7e
    moveq      #$2,d0
    cmp.l      d0,d7
    ble.b      LAB_00227cae
LAB_00227c7e
    moveq      #$30,d0
    cmp.l      d0,d5
    bne.b      LAB_00227cae
    moveq      #$78,d0
    cmp.l      d0,d4
    beq.b      LAB_00227c90
    moveq      #$58,d0
    cmp.l      d0,d4
    bne.b      LAB_00227cae
LAB_00227c90
    jsr        (a5)
    lea        ($1,a4),a0
    move.l     d0,d4
    btst.b     #$7,($0,a0,d0.l)
    bne.b      LAB_00227ca8
    move.l     d4,(a2)
    moveq      #$0,d0
    bra.w      LAB_00227f40
LAB_00227ca8
    moveq      #$0,d6
    subq.l     #$1,d7
    bra.b      LAB_00227d08
LAB_00227cae
    lea        ($1,a4),a2
    adda.l     d5,a2
    btst.b     #$2,(a2)
    beq.b      LAB_00227cc0
    move.l     d5,d6
    moveq      #$30,d0
    sub.l      d0,d6
LAB_00227cc0
    btst.b     #$0,(a2)
    beq.b      LAB_00227ccc
    move.l     d5,d6
    moveq      #$37,d0
    sub.l      d0,d6
LAB_00227ccc
    btst.b     #$1,(a2)
    beq.b      LAB_00227d08
    move.l     d5,d6
    moveq      #$57,d0
    sub.l      d0,d6
    bra.b      LAB_00227d08
LAB_00227cda
    asl.l      #$4,d6
    btst.b     #$2,(a2)
    beq.b      LAB_00227cea
    move.l     d4,d0
    moveq      #$30,d1
    sub.l      d1,d0
    or.l       d0,d6
LAB_00227cea
    btst.b     #$0,(a2)
    beq.b      LAB_00227cf8
    move.l     d4,d0
    moveq      #$37,d1
    sub.l      d1,d0
    or.l       d0,d6
LAB_00227cf8
    btst.b     #$1,(a2)
    beq.b      LAB_00227d04
    moveq      #$57,d1
    sub.l      d1,d4
    or.l       d4,d6
LAB_00227d04
    jsr        (a5)
    move.l     d0,d4
LAB_00227d08
    subq.l     #$1,d7
    beq.b      LAB_00227d18
    lea        ($1,a4),a2
    adda.l     d4,a2
    btst.b     #$7,(a2)
    bne.b      LAB_00227cda
LAB_00227d18
    move.l     a3,d0
    beq.w      LAB_00227f32
    move.l     ($20,sp),d0
    bpl.b      LAB_00227d26
    neg.l      d6
LAB_00227d26
    movea.l    (a3),a2
    tst.l      ($2c,sp)
    beq.b      LAB_00227d34
    move.l     d6,(a2)
    bra.w      LAB_00227f32
LAB_00227d34
    tst.l      ($28,sp)
    beq.b      LAB_00227d40
    move.w     d6,(a2)
    bra.w      LAB_00227f32
LAB_00227d40
    move.l     d6,(a2)
    bra.w      LAB_00227f32
caseD_63
    move.l     a3,d0
    beq.b      LAB_00227d60
    bra.b      LAB_00227d58
LAB_00227d4c
    jsr        (a5)
    move.l     d0,d4
    addq.l     #$1,d0
    beq.b      LAB_00227d64
    move.l     a3,d0
    beq.b      LAB_00227d60
LAB_00227d58
    movea.l    (a3),a0
    addq.l     #$1,(a3)
    move.l     d4,d0
    move.b     d0,(a0)
LAB_00227d60
    subq.l     #$1,d7
    bgt.b      LAB_00227d4c
LAB_00227d64
    moveq      #-$1,d0
    cmp.l      d0,d4
    bne.w      LAB_00227f38
    movea.l    ($38,sp),a0
    move.l     d4,(a0)
    moveq      #$0,d0
    bra.w      LAB_00227f40
caseD_73
    move.l     a3,d0
    beq.b      LAB_00227d82
    movea.l    (a3),a0
    addq.l     #$1,(a3)
    move.b     d4,(a0)
LAB_00227d82
    jsr        (a5)
    move.l     d0,d4
    addq.l     #$1,d0
    beq.b      LAB_00227d9a
    subq.l     #$1,d7
    beq.b      LAB_00227d9a
    lea        ($1,a4),a0
    btst.b     #$3,($0,a0,d4.l)
    beq.b      caseD_73
LAB_00227d9a
    move.l     a3,d0
    beq.w      LAB_00227f32
    movea.l    (a3),a0
    clr.b      (a0)
    bra.w      LAB_00227f32
caseD_5b
    addq.l     #$1,($24,sp)
    moveq      #$5e,d0
    movea.l    ($24,sp),a0
    cmp.b      (a0),d0
    bne.b      LAB_00227dc4
    lea        ($24,sp),a6
    moveq      #$1,d6
    addq.l     #$1,(a6)
    movea.l    (a6)+,a0
    move.l     a0,(a6)+
    bra.b      LAB_00227dca
LAB_00227dc4
    moveq      #$0,d6
    move.l     a0,($28,sp)
LAB_00227dca
    moveq      #$5d,d0
    cmp.b      (a0),d0
    bne.b      LAB_00227dea
    bra.b      LAB_00227de6
LAB_00227dd2
    movea.l    ($24,sp),a0
    tst.b      (a0)
    bne.b      LAB_00227de6
    movea.l    ($38,sp),a1
    move.l     d4,(a1)
    moveq      #$0,d0
    bra.w      LAB_00227f40
LAB_00227de6
    addq.l     #$1,($24,sp)
LAB_00227dea
    moveq      #$5d,d0
    movea.l    ($24,sp),a0
    cmp.b      (a0),d0
    bne.b      LAB_00227dd2
    tst.l      d6
    beq.w      LAB_00227ea8
LAB_00227dfa
    move.l     ($28,sp),($2c,sp)
    moveq      #$0,d6
    bra.b      LAB_00227e7c
LAB_00227e04
    movea.l    ($2c,sp),a0
    move.b     (a0),d0
    moveq      #$2d,d1
    cmp.b      d1,d0
    bne.b      LAB_00227e52
    tst.l      d6
    beq.b      LAB_00227e52
    lea        ($1,a0),a2
    movea.l    ($24,sp),a1
    cmpa.l     a2,a1
    beq.b      LAB_00227e52
    movea.l    a2,a6
    moveq      #$0,d5
    move.b     (a2),d5
    move.l     a6,($2c,sp)
    cmp.l      d5,d6
    bls.b      LAB_00227e34
    move.l     d6,d0
    move.l     d5,d6
    move.l     d0,d5
LAB_00227e34
    cmp.l      d6,d4
    bcs.b      LAB_00227e78
    cmp.l      d5,d4
    bhi.b      LAB_00227e78
    move.l     a3,d0
    beq.b      LAB_00227e44
    movea.l    (a3),a0
    clr.b      (a0)
LAB_00227e44
    movea.l    ($38,sp),a0
    move.l     d4,(a0)
    lea        ($1,a1),a0
    bra.w      LAB_00227f3e
LAB_00227e52
    moveq      #$0,d1
    move.b     d0,d1
    cmp.l      d4,d1
    bne.b      LAB_00227e74
    move.l     a3,d1
    beq.b      LAB_00227e62
    movea.l    (a3),a1
    clr.b      (a1)
LAB_00227e62
    movea.l    ($38,sp),a1
    move.l     d4,(a1)
    movea.l    ($24,sp),a1
    addq.l     #$1,a1
    move.l     a1,d0
    bra.w      LAB_00227f40
LAB_00227e74
    moveq      #$0,d6
    move.b     (a0),d6
LAB_00227e78
    addq.l     #$1,($2c,sp)
LAB_00227e7c
    movea.l    ($2c,sp),a0
    cmpa.l     ($24,sp),a0
    bne.w      LAB_00227e04
    move.l     a3,d0
    beq.b      LAB_00227e92
    movea.l    (a3),a0
    addq.l     #$1,(a3)
    move.b     d4,(a0)
LAB_00227e92
    jsr        (a5)
    move.l     d0,d4
    addq.l     #$1,d0
    beq.b      LAB_00227ea0
    subq.l     #$1,d7
    bne.w      LAB_00227dfa
LAB_00227ea0
    movea.l    (a3),a0
    clr.b      (a0)
    bra.w      LAB_00227f32
LAB_00227ea8
    move.l     ($28,sp),($2c,sp)
    moveq      #$0,d6
    bra.b      LAB_00227efe
LAB_00227eb2
    movea.l    ($2c,sp),a0
    move.b     (a0),d0
    moveq      #$2d,d1
    cmp.b      d1,d0
    bne.b      LAB_00227eea
    tst.l      d6
    beq.b      LAB_00227eea
    lea        ($1,a0),a2
    movea.l    ($24,sp),a1
    cmpa.l     a2,a1
    beq.b      LAB_00227eea
    movea.l    a2,a1
    moveq      #$0,d5
    move.b     (a2),d5
    move.l     a1,($2c,sp)
    cmp.l      d5,d6
    bls.b      LAB_00227ee2
    move.l     d6,d0
    move.l     d5,d6
    move.l     d0,d5
LAB_00227ee2
    cmp.l      d6,d4
    bcs.b      LAB_00227eea
    cmp.l      d5,d4
    bls.b      LAB_00227f12
LAB_00227eea
    movea.l    ($2c,sp),a0
    moveq      #$0,d6
    move.b     (a0),d6
    moveq      #$0,d0
    move.b     (a0),d0
    cmp.l      d4,d0
    beq.b      LAB_00227f12
    addq.l     #$1,($2c,sp)
LAB_00227efe
    movea.l    ($2c,sp),a0
    cmpa.l     ($24,sp),a0
    bne.b      LAB_00227eb2
    move.l     a3,d0
    beq.b      LAB_00227f32
    movea.l    (a3),a0
    clr.b      (a0)
    bra.b      LAB_00227f32
LAB_00227f12
    move.l     a3,d0
    beq.b      LAB_00227f1c
    movea.l    (a3),a0
    addq.l     #$1,(a3)
    move.b     d4,(a0)
LAB_00227f1c
    jsr        (a5)
    move.l     d0,d4
    addq.l     #$1,d0
    beq.b      LAB_00227f28
    subq.l     #$1,d7
    bne.b      LAB_00227ea8
LAB_00227f28
    movea.l    (a3),a0
    clr.b      (a0)
    bra.b      LAB_00227f32

caseD_5a
caseD_5c
caseD_5d
caseD_5e
caseD_5f
caseD_60
caseD_61
caseD_62
caseD_65
caseD_66
caseD_67
caseD_68
caseD_6a
caseD_6b
caseD_6c
caseD_6d
caseD_71
caseD_72
caseD_74
caseD_76
caseD_77
caseD_59
    moveq      #$0,d0
    bra.b      LAB_00227f40
LAB_00227f32
    movea.l    ($38,sp),a0
    move.l     d4,(a0)
LAB_00227f38
    movea.l    ($24,sp),a0
    addq.l     #$1,a0
LAB_00227f3e
    move.l     a0,d0
LAB_00227f40

	movem.l    (sp)+,d4-d7/a2-a3/a5-a6
    adda.w     #$10,sp
    rts

    nop
    movea.l    ($4,sp),a0
    movea.l    ($8,sp),a1
    move.l     ($c,sp),($4,sp)
    move.l     ($10,sp),($8,sp)
    move.l     ($14,sp),($c,sp)

FUN_00227f66
    suba.w     #$c,sp
    movem.l    d6-d7/a2-a3/a5,-(sp)
    moveq      #$0,d7
    move.l     ($2c,sp),($18,sp)
    movea.l    a1,a3
    movea.l    a0,a5
    bra.w      LAB_002280aa
LAB_00227f7e
    clr.l      ($14,sp)
    movea.l    ($28,sp),a0
    moveq      #$0,d6
    move.b     (a0)+,d6
    move.l     a0,($28,sp)
    lea        ($1,a4),a1
    btst.b     #$3,($0,a1,d6.l)
    bne.w      LAB_00228080
    moveq      #$25,d0
    cmp.l      d0,d6
    bne.w      LAB_00228050
    moveq      #$25,d0
    cmp.b      (a0),d0
    bne.b      LAB_00227fca
    addq.l     #$1,($28,sp)
LAB_00227fae
    jsr        (a5)
    move.l     d0,d6
    lea        ($1,a4),a0
    btst.b     #$3,($0,a0,d6.l)
    bne.b      LAB_00227fae
    moveq      #$25,d0
    cmp.l      d0,d6
    beq.w      LAB_002280aa
    bra.w      LAB_002280b4
LAB_00227fca
    moveq      #$2a,d0
    movea.l    ($28,sp),a0
    cmp.b      (a0),d0
    beq.b      LAB_00227fde
    movea.l    ($18,sp),a2
    addq.l     #$4,($18,sp)
    bra.b      LAB_00227fe4
LAB_00227fde
    addq.l     #$1,($28,sp)
    suba.l     a2,a2
LAB_00227fe4
    clr.l      ($1c,sp)
    pea        ($14,sp)
    movea.l    a5,a1
    move.l     a2,-(sp)
    pea        ($24,sp)
    move.l     ($30,sp),-(sp)
    movea.l    ($38,sp),a0
    bsr.w      FUN_0022794c
    tst.l      d0
    sne        d1
    lea        ($10,sp),sp
    neg.b      d1
    ext.w      d1
    movea.l    d0,a2
    ext.l      d1
    move.l     d1,d6
    beq.b      LAB_00228018
    move.l     a2,($28,sp)
LAB_00228018
    move.l     ($1c,sp),d0
    moveq      #-$1,d1
    cmp.l      d1,d0
    bne.b      LAB_00228036
    tst.l      d6
    beq.b      LAB_0022802a
    add.l      ($14,sp),d7
LAB_0022802a
    tst.l      d7
    bgt.w      LAB_002280b4
    move.l     d1,d0
    bra.w      LAB_002280b6
LAB_00228036
    move.l     ($1c,sp),d0
    cmp.l      d1,d0
    beq.b      LAB_00228046
    moveq      #$0,d1
    move.b     d0,d1
    move.l     d1,d0
    jsr        (a3)
LAB_00228046
    move.l     a2,d0
    beq.b      LAB_002280b4
    add.l      ($14,sp),d7
    bra.b      LAB_002280aa
LAB_00228050
    jsr        (a5)
    move.l     d0,($1c,sp)
    movea.l    ($1c,sp),a0
    move.l     a0,d0
    lea        ($1,a4),a1
    btst.b     #$3,($0,a1,d0.l)
    bne.b      LAB_00228050
    move.l     ($1c,sp),d0
    cmp.l      d0,d6
    beq.b      LAB_002280aa
    moveq      #-$1,d1
    cmp.l      d1,d0
    beq.b      LAB_002280aa
    moveq      #$0,d1
    move.b     d0,d1
    move.l     d1,d0
    jsr        (a3)
    bra.b      LAB_002280b4
LAB_00228080
    jsr        (a5)
    move.l     d0,($1c,sp)
    movea.l    ($1c,sp),a0
    move.l     a0,d0
    lea        ($1,a4),a1
    btst.b     #$3,($0,a1,d0.l)
    bne.b      LAB_00228080
    move.l     ($1c,sp),d0
    moveq      #-$1,d1
    cmp.l      d1,d0
    beq.b      LAB_002280aa
    moveq      #$0,d1
    move.b     d0,d1
    move.l     d1,d0
    jsr        (a3)
LAB_002280aa
    movea.l    ($28,sp),a0
    tst.b      (a0)
    bne.w      LAB_00227f7e
LAB_002280b4
    move.l     d7,d0
LAB_002280b6
	movem.l    (sp)+,d6-d7/a2-a3/a5
    adda.w     #$c,sp
    rts
