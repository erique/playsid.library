;APS00000000000000000000000000000000000000000000000000000000000000000000000000000000
    incdir  include:
    include exec/exec_lib.i
    include exec/tasks.i
    include dos/dos_lib.i
    include playsid_lib.i
    include playsidbase.i
    include hardware/custom.i
    include hardware/cia.i
    include hardware/dmabits.i
    include hardware/intbits.i

* Constants
PAL_CLOCK=3546895
SAMPLING_FREQ=22050
PAULA_PERIOD=(PAL_CLOCK+SAMPLING_FREQ/2)/SAMPLING_FREQ
SAMPLES_PER_FRAME=(SAMPLING_FREQ+25)/50 
SAMPLES_PER_HALF_FRAME=(SAMPLING_FREQ+50)/100

* f=c/p
* fp=c
* p=c/f

    bra     main
main_
    
    rts
    
    move.l  4.w,a6
    lea     DOSName,a1
    jsr     _LVOOldOpenLibrary(a6)
    move.l  d0,DOSBase

    bsr     createWorkerTask

.loop
    move.l  DOSBase,a6
    moveq   #1,d1
    jsr     _LVODelay(a6)
    btst    #6,$bfe001
    bne     .loop

    bsr     stopWorkerTask
    
    rts

createWorkerTask:
    lea     WorkerTaskStruct,a0
    move.b  #NT_TASK,LN_TYPE(a0)
    move.b  #-50,LN_PRI(a0)
    move.l  #WorkerTaskName,LN_NAME(a0)
    lea     WorkerTaskStack,a1
    move.l  a1,TC_SPLOWER(a0)
    lea     4096(a1),a1
    move.l  a1,TC_SPUPPER(a0)
    move.l  a1,TC_SPREG(a0)

    move.l  a0,a1
    lea     workerEntry(pc),a2
    sub.l   a3,a3
    move.l  4.w,a6
    jsr     _LVOAddTask(a6)
    rts

stopWorkerTask
    tst.b   WorkerStatus
    beq     .x
    move.b  #-1,WorkerStatus
.loop
    tst.b   WorkerStatus
    beq     .x
    move.l  DOSBase,a6
    moveq   #1,d1
    jsr     _LVODelay(a6)
    bra     .loop
.x 
    rts



WorkerTaskName
    dc.b    "Wrkr",0

WorkerStatus 
    ;0  = not running
    ;1  = running
    ;-1 = exiting
    dc.b    0
    even

WorkerTaskStruct
    ds.b    TC_SIZE

WorkerTaskStack
    ds.b    4096


workerEntry
    move.b  #1,WorkerStatus

    bsr     createSamples

    lea     $dff000,a0
    move.w  #INTF_AUD0!INTF_AUD1!INTF_AUD2!INTF_AUD3,intena(a0)
    move.w  #INTF_AUD0!INTF_AUD1!INTF_AUD2!INTF_AUD3,intreq(a0)
    move.w  #DMAF_AUD0!DMAF_AUD1!DMAF_AUD2!DMAF_AUD3,dmacon(a0)

    lea     dd1,a2
    lea     dd2,a3
    move.l  a2,$a0(a0) 
    exg     a2,a3
    
    move    #10000/2,$a4(a0)
    move    #500,$a6(a0)
    move    #64,$a8(a0)
    bsr     dmawait
    move    #DMAF_SETCLR!DMAF_AUD0,dmacon(a0)

    ; buffer A now plays
    ; interrupt will be triggered soon to queue the next sample
    ; wait for the interrupt and queue buffer B
    ; fill buffer B
    ; after A has played, B will start
    ; interrupt will be triggered
    ; queue buffer A
    ; fill A
    ; ... etc
.loop
    move.w  intreqr(a0),d0
    btst    #INTB_AUD0,d0
    beq.b   .1
    move.l  a2,$a0(a0)
    exg     a2,a3
    move.w  #INTF_AUD0,intreq(a0)
    move    #$0f0,$dff180
.1
    tst.b   WorkerStatus
    bpl     .loop
    clr.b   WorkerStatus
    rts


createSamples
    lea    dd1,a0
    move   #10000/2-1,d0
    moveq  #0,d1
.l  not.b  d1
    bne.b  .1
    move.b d0,d3
    not.b  d3
    move.b d3,(a0)+
    bra    .2
.1
    move.b d0,(a0)+
.2
    dbf    d0,.l


    lea    dd2,a0
    move   #10000/2-1,d0
    moveq  #0,d1
.ll 
    not.b  d1
    and    #$77,d1
    move.b d1,(a0)+
    dbf    d0,.ll
    rts
    
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

    bsr     copyHeader

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

copyHeader
    lea     Mod,a0
    lea     Header,a1
    moveq   #sidh_sizeof-1,d0
.c  move.b  (a0)+,(a1)+
    dbf     d0,.c
    rts
	
dmawait
	movem.l d0/d1,-(sp)
	moveq	#12-1,d1
.d	move.b	$dff006,d0
.k	cmp.b	$dff006,d0
	beq.b	.k
	dbf	d1,.d
	movem.l (sp)+,d0/d1
	rts

SIDName     
  ifd __VASM
            dc.b    "PROGDIR:"
            dc.b    "playsid.library",0
  else
	    dc.b    "asm:playsid-koobo/"
            dc.b    "playsid.library",0
  endif
DOSName     dc.b    "dos.library",0
SIDBase     dc.l    0
DOSBase     dc.l    0
Header      ds.b    sidh_sizeof
Mod         incbin  Terra_Cresta.dat
ModLen      = *-Mod

    section bss,bss_c

dd1      ds.b	10000
dd2      ds.b   10000
