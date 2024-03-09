
*=======================================================================*
*									*
* 	C64 MUSIC EMULATOR FOR AMIGA					*
*	(C) 1990-1994 HÅKAN SUNDELL & RON BIRK				*
*									*
*=======================================================================*

* reSID settings and constants

; Set to 1 to enable the Paula 14-bit output
  ifnd ENABLE_14BIT
ENABLE_14BIT    = 1
  endif

; Set to 1 to save SID register dump into a file
ENABLE_REGDUMP  = 0
REGDUMP_SIZE    = 100000

; Set to 1 to do playback in interrupts.
; This makes the audio smooth and uninterruptible,
; but may hang the whole system if CPU runs low.

; Set to 0 to do playback in a task.
; This will not hang the system but music playback
; will easily be disturbed by other things happening 
; in the system. 
  ifnd ENABLE_LEV4PLAY
ENABLE_LEV4PLAY = 1
  endif


* Period should be divisible by 64 for bug free 14-bit output
PAULA_PERIOD=128    
PAL_CLOCK=3546895
* Sampling frequency: PAL_CLOCK/PAULA_PERIOD=27710.1171875
PLAYBACK_FREQ = PAL_CLOCK/PAULA_PERIOD

* "single speed"
* reSID update frequency 50 Hz:
* Samples per 1/50s = 554.20234375
* Samples per 1/50s as 22.10 FP = 567503.2
SAMPLES_PER_FRAME_50Hz =  567503

* "double speed"
* reSID update frequency 100 Hz:
* Samples per 1/100s = 277.10117
* Samples per 1/100s as 22.10 FP = 283751.59808
SAMPLES_PER_FRAME_100Hz = 283752

* "4-speed"
* reSID update frequency 200 Hz:
* Samples per 1/200s = 138.550585
* Samples per 1/200s as 22.10 FP = 141875.79904
SAMPLES_PER_FRAME_200Hz = 141876

* "8-speed"
* reSID update frequency 400 Hz:
* Samples per 1/400s = 69.275292
* Samples per 1/400s as 22.10 FP = 70937.9
SAMPLES_PER_FRAME_400Hz = 70938

* "12-speed"
* reSID update frequency 600 Hz:
* Samples per 1/600s = 46.18352864
* Samples per 1/600s as 22.10 FP = 47291.93333
SAMPLES_PER_FRAME_600Hz = 47292

* Output buffer size, this needs to be big enough, exact size not important.
* "single speed" buffer is 554 bytes
SAMPLE_BUFFER_SIZE = 600

* Enable debug logging into a console window
* Enable debug colors
DEBUG = 0
SERIALDEBUG = 0
COUNTERS = 0

* When playing samples with reSID scale ch4 volume with this factor
* to get it to reSID levels
CH4_RESID_VOLSCALE = $10

* Macro to print to debug console
DPRINT  macro
        ifne     DEBUG
        jsr      desmsgDebugAndPrint
        dc.b     \1,10,0
        even
        endc
        endm

SPRINT  macro
        ifne     SERIALDEBUG
        jsr      desmsgDebugAndPrint
        dc.b     \1,10,0
        even
        endc
        endm


  ifd __VASM
    ; Turn off optimizations for main playsid code
    opt o-
  endif


*=======================================================================*
*	INCLUDES							*
*=======================================================================*
	NOLIST
		include lvo/exec_lib.i
		include	exec/execbase.i
		include	exec/initializers.i
		include	exec/memory.i
		include	exec/libraries.i
		include	exec/resident.i
        include exec/tasks.i
		include intuition/intuition.i
		include	resources/cia.i
		include	lvo/cia_lib.i
		include	hardware/custom.i
		include	hardware/cia.i
		include	hardware/dmabits.i
		include	hardware/intbits.i
        include lvo/dos_lib.i
		include	playsid_libdefs.i
    	include	dos/dosextens.i
       	include	dos/var.i
        include lvo/timer_lib.i
        include devices/timer.i
        include	devices/ahi.i
        include lvo/ahi.i
    	include	dos/dostags.i

	LIST
*=======================================================================*
*	EXTERNAL REFERENCES						*
*=======================================================================*
		xref	_custom,_ciaa,_ciab
		xref	@AllocEmulAudio,@FreeEmulAudio,@ReadIcon

		xref	_sid_init,_sid_exit,_sid_write_reg_record,_sid_write_reg_playback

                xdef    _PlaySidBase
*=======================================================================*
*									*
*	CODE SECTION							*
*									*
*=======================================================================*
		section	.text,CODE
*-----------------------------------------------------------------------*

*=======================================================================*
*	LIBRARY STARTUP							*
*=======================================================================*
		moveq	#-1,d0
		rts

*=======================================================================*
*	RESIDENT ROMTAG STRUCTURE					*
*=======================================================================*
MYPRI		EQU	0

RomTagStruct	dc.w	RTC_MATCHWORD
		dc.l	RomTagStruct
		dc.l	EndOfLibrary
		dc.b	RTF_AUTOINIT
		dc.b	PSIDLIB_VERSION
		dc.b	NT_LIBRARY
		dc.b	MYPRI
		dc.l	LibraryName
		dc.l	LibraryIDString
		dc.l	AutoInitTable

LibraryName	PSIDLIB_NAME
LibraryIDString	PSIDLIB_IDSTRING
		PSIDLIB_COPYRIGHT
        even

AutoInitTable	dc.l	psb_SIZEOF
		dc.l	AutoInitVectors
		dc.l	AutoInitStructure
		dc.l	AutoInitFunction

AutoInitVectors	;***** Standard System Routines *****
		dc.l	@Open
		dc.l	@Close
		dc.l	@Expunge
		dc.l	@Null

		;****** Public Routines ******
		dc.l	@AllocEmulResource
		dc.l	@FreeEmulResource
		dc.l	@ReadIcon
		dc.l	@CheckModule
		dc.l	@SetModule
		dc.l	@StartSong
		dc.l	@StopSong
		dc.l	@PauseSong
		dc.l	@ContinueSong
		dc.l	@ForwardSong
		dc.l	@RewindSong
		dc.l	@SetVertFreq
		dc.l	@SetChannelEnable
		dc.l	@SetReverseEnable

		;****** Private Routines ******
		dc.l	@SetTimeSignal
		dc.l	@SetTimeEnable
		dc.l	@SetDisplaySignal
		dc.l	@SetDisplayEnable

		;****** New stuff, reSID support ******
        dc.l    @SetOperatingMode
        dc.l    @GetOperatingMode
        dc.l    @SetRESIDMode
        dc.l    @GetRESIDMode
        dc.l    @SetVolume
        dc.l    @SetResidFilter
        dc.l    @GetResidAudioBuffer
        dc.l    @MeasureResidPerformance
        dc.l    @GetSongSpeed
        dc.l    @SetAHIMode
        dc.l    @GetAHIMode
        dc.l    @SetResidBoost
		dc.l	-1

AutoInitStructure
		INITBYTE	LN_TYPE,NT_LIBRARY
		INITLONG	LN_NAME,LibraryName
		INITBYTE	LIB_FLAGS,LIBF_SUMUSED!LIBF_CHANGED
		INITWORD	LIB_VERSION,PSIDLIB_VERSION
		INITWORD	LIB_REVISION,PSIDLIB_REVISION
		INITLONG	LIB_IDSTRING,LibraryIDString
		dc.l	0

AutoInitFunction
		movem.l	a2/a5,-(a7)
		move.l	d0,a5
		move.l	a6,psb_SysLib(a5)
		move.l	a0,psb_SegList(a5)
		move.l	a5,_PlaySidBase
        move.l  #residData,psb_reSID(a5)
        move.l  #residData2,psb_reSID2(a5)
        move.l  #residData3,psb_reSID3(a5)

		lea	Display,a2
		move.l	a2,psb_DisplayData(a5)
		lea	Enve1,a2
		move.l	a2,psb_Enve1(a5)
		lea	Enve2,a2
		move.l	a2,psb_Enve2(a5)
		lea	Enve3,a2
		move.l	a2,psb_Enve3(a5)
		lea	Chan1,a2
		move.l	a2,psb_Chan1(a5)
		lea	Chan2,a2
		move.l	a2,psb_Chan2(a5)
		lea	Chan3,a2
		move.l	a2,psb_Chan3(a5)
		lea	Chan4,a2
		move.l	a2,psb_Chan4(a5)
		lea	VolumeTable,a2
		move.l	a2,psb_VolumeTable(a5)
		lea	AttackDecay,a2
		move.l	a2,psb_AttackDecay(a5)
		lea	SustainRelease,a2
		move.l	a2,psb_SustainRelease(a5)
		lea	SustainTable,a2
		move.l	a2,psb_SustainTable(a5)
		lea	AttackTable,a2
		move.l	a2,psb_AttackTable(a5)
		lea	AttDecRelStep,a2
		move.l	a2,psb_AttDecRelStep(a5)

		move.l	a5,d0
		movem.l	(a7)+,a2/a5
		rts

@Open		addq.w	#1,LIB_OPENCNT(a6)
		bclr	#LIBB_DELEXP,psb_Flags(a6)
		cmp.w	#1,LIB_OPENCNT(a6)
		bhi.s	.end

		clr.w	psb_EmulResourceFlag(a6)
		clr.w	psb_SongSetFlag(a6)
		clr.w	psb_IntVecAudFlag(a6)
		clr.w	psb_TimerAFlag(a6)
		clr.w	psb_TimerBFlag(a6)
		move.w	#PM_STOP,psb_PlayMode(a6)
		moveq	#$01,d0
		move.w	d0,psb_ChannelEnable(a6)
		move.w	d0,psb_ChannelEnable+2(a6)
		move.w	d0,psb_ChannelEnable+4(a6)
		move.w	d0,psb_ChannelEnable+6(a6)
		move.w	d0,psb_AudioDevice(a6)
        bsr     undefineSettings

		clr.w	psb_TimeSeconds(a6)		;Set time to 00:00
		clr.w	psb_TimeMinutes(a6)
		clr.w	psb_UpdateCounter(a6)

        DPRINT  "Open"

.end		move.l	a6,d0
		rts

@Close		moveq	#$00,d0
		subq.w	#1,LIB_OPENCNT(a6)
		bne.s	.1
		bsr	@FreeEmulResource
 if DEBUG
        jsr     CloseDebug
 endif
		btst	#LIBB_DELEXP,psb_Flags(a6)
		beq.s	.1
		bsr.s	@Expunge
.1		rts

@Expunge	movem.l	d2/a5/a6,-(a7)
		move.l	a6,a5
		move.l	psb_SysLib(a5),a6
		tst.w	LIB_OPENCNT(a5)
		beq.s	.1
		bset	#LIBB_DELEXP,psb_Flags(a5)
		moveq	#$00,d0
		bra.s	.2
.1		move.l	psb_SegList(a5),d2
		move.l	a5,a1
		CALLEXEC Remove
		moveq	#$00,d0
		move.l	a5,a1
		move.w	LIB_NEGSIZE(a5),d0
		sub.l	d0,a1
		add.w	LIB_POSSIZE(a5),d0
		CALLEXEC FreeMem
		move.l	d2,d0
.2		movem.l	(a7)+,d2/a5/a6
		rts

@Null		moveq	#$00,d0
		rts

*=======================================================================*
*	MAIN ROUTINES							*
*=======================================================================*
@AllocEmulResource
        DPRINT  "AllocEmulResource"
		;CALLEXEC Forbid
		movem.l	d2-d7/a2-a6,-(a7)
    
		tst.w	psb_EmulResourceFlag(a6)
		beq.s	.LibOK
		moveq	#SID_LIBINUSE,d0
		bra 	.Exit
.LibOK		
        move.l  a6,a5
        move.l  4.w,a6
        lea     _DOSName(pc),a1
        jsr     _LVOOldOpenLibrary(a6)
        move.l  d0,psb_DOSBase(a5)
        move.l  a5,a6
        bsr     GetEnvSettingsPre

        cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a6)
        bne.b   .noBlaster
        bsr     start_sid_blaster
		tst.l	d0
        bne    .Exit
.noBlaster

        bsr	    AllocEmulMem
		tst.l	d0
		bne  	.Exit
.MemOK		
        bsr	CheckCPU
		bsr	Make6502Emulator
		bsr	MakeMMUTable
		bsr	MakeVolume
		bsr	MakeSIDSamples
		bsr	MakeEnvelope
		move.w	#PM_STOP,psb_PlayMode(a6)
		move.w	#1,psb_EmulResourceFlag(a6)

        bsr     isResidActive
        beq     .1
        jsr     initResid
.1
        * Default volume
        moveq   #$40,d0
        jsr     @SetVolume
    
 ifne ENABLE_REGDUMP
        clr.l   regDumpOffset
 endif
        bsr     GetEnvSettingsPost

        move.l  4.w,a6
        cmp     #37,LIB_VERSION(a6)
        blo.b   .3
        jsr     _LVOCacheClearU(a6)
.3
        * Status: OK
        moveq	#0,d0
.Exit
        movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts


_DOSName:
    dc.b    "dos.library",0
    even

*-----------------------------------------------------------------------*
* Read environment variables for configuration
*-----------------------------------------------------------------------*

undefineSettings:
        move.w  #-1,psb_OperatingMode(a6) 
        move.w  #-1,psb_ResidMode(a6)
        clr.l   psb_AhiMode(a6)
        clr.w   psb_Debug(a6)
        rts

* Settings to set before initialization (AllocEmulResource)
GetEnvSettingsPre:
    DPRINT  "GetEnvSettingsPre"
    lea     -64(sp),sp
    move.l  sp,a4
    bsr     GetEnvMode
    bsr     GetEnvResidMode
    bsr     GetEnvResidAhi
    bsr     GetEnvDebugMode
    lea     64(sp),sp
    rts

* Settings to set after initialization (AllocEmulResource)
GetEnvSettingsPost:
    DPRINT  "GetEnvSettingsPost"
    lea     -64(sp),sp
    move.l  sp,a4
    bsr     GetEnvResidFilter
    bsr     GetEnvResidBoost
    lea     64(sp),sp
    rts

GetEnvMode:
    tst.l   psb_OperatingMode(a6)
    bge     .x
    lea     EnvMode(pc),a0
    lea     (a4),a1
    bsr     GetEnvVarString
    bmi     .1  * default
    bsr     get4
    cmp.l   #"norm",d0
    beq     .1    
    cmp.l   #"6581",d0
    beq     .2
    cmp.l   #"8580",d0
    beq     .3    
    cmp.l   #"auto",d0
    beq     .4    
    cmp.l   #"sidb",d0
    beq     .5
    bra     .1 * default
.x  rts

.1
    DPRINT  "PlaySIDMode=Norm"
    moveq   #OM_NORMAL,d0
    bsr     @SetOperatingMode
    rts
.2
    DPRINT  "PlaySIDMode=6581"
    moveq   #OM_RESID_6581,d0
    bsr     @SetOperatingMode
    rts
.3
    DPRINT  "PlaySIDMode=8580"
    moveq   #OM_RESID_8580,d0
    bsr     @SetOperatingMode
    rts
.4
    DPRINT  "PlaySIDMode=Auto"
    moveq   #OM_RESID_AUTO,d0
    bsr     @SetOperatingMode
    rts
.5
    DPRINT  "PlaySIDMode=SIDBlaster"
    moveq   #OM_SIDBLASTER_USB,d0
    bsr     @SetOperatingMode
    rts

GetEnvResidMode:
    tst.w   psb_ResidMode(a6)
    bge     .x
    lea     EnvResidMode(pc),a0
    lea     (a4),a1
    bsr     GetEnvVarString
    bmi     .1 * default
    bsr     get4
    cmp.l   #"norm",d0
    beq     .1    
    cmp.l   #"ovs2",d0
    beq     .2
    cmp.l   #"ovs3",d0
    beq     .3    
    cmp.l   #"ovs4",d0
    beq     .4
    bra     .1 * default
.x  rts

.1
    DPRINT  "PlaySIDreSIDMode=Norm"
    moveq   #REM_NORMAL,d0
    bsr     @SetRESIDMode
    rts
.2
    DPRINT  "PlaySIDreSIDMode=Ovs2"
    moveq   #REM_OVERSAMPLE2,d0
    bsr     @SetRESIDMode
    rts
.3
    DPRINT  "PlaySIDreSIDMode=Ovs3"
    moveq   #REM_OVERSAMPLE3,d0
    bsr     @SetRESIDMode
    rts
.4
    DPRINT  "PlaySIDreSIDMode=Ovs4"
    moveq   #REM_OVERSAMPLE4,d0
    bsr     @SetRESIDMode
    rts


GetEnvResidFilter:
    lea     EnvResidFilter(pc),a0
    lea     (a4),a1
    bsr     GetEnvVarString
    bmi     .x
    bsr     get4
    cmp.l   #"onin",d0
    beq     .1   
    lsr.l   #8,d0 
    cmp.l   #"off",d0
    beq     .3    
    lsr.l   #8,d0 
    cmp.l   #"on",d0
    beq     .2
.x  rts

.1
    DPRINT  "PlaySIDreSIDFilter=OnIn"
    moveq   #1,d0
    moveq   #0,d1
    bsr     @SetResidFilter
    rts
.2
    DPRINT  "PlaySIDreSIDFilter=On"
    moveq   #1,d0
    moveq   #1,d1
    bsr     @SetResidFilter
    rts
.3
    DPRINT  "PlaySIDreSIDFilter=Off"
    moveq   #0,d0
    moveq   #0,d1
    bsr     @SetResidFilter
    rts

GetEnvResidBoost:
    lea     EnvResidBoost(pc),a0
    lea     (a4),a1
    bsr     GetEnvVarString
    bmi     .x
    move.b  (a4),d0
    sub.b   #"0",d0
    bmi     .x
    cmp.b   #4,d0
    bhi     .x
    and.l   #$f,d0
    DPRINT  "PlaySIDreSIDBoost=%ld"
    bsr     @SetResidBoost
.x  rts

GetEnvResidAhi:
    tst.l   psb_AhiMode(a6)
    bne     .x
    lea     EnvResidAHI(pc),a0
    lea     (a4),a1
    bsr     GetEnvVarString
    bmi     .x
    lea     (a4),a0
    bsr     convertHexTextToNumber    
    DPRINT  "ResidAHI=%lx"
    bsr     @SetAHIMode
.x  rts

GetEnvDebugMode:
    lea     EnvDebugMode(pc),a0
    lea     (a4),a1
    bsr     GetEnvVarString
    bmi     .x
    bsr     get4
    lsr.l   #8,d0
    cmp.l   #"off",d0
    beq     .1    
    lsr.l   #8,d0
    cmp.l   #"on",d0
    beq     .2
.x  rts

.1
    DPRINT  "PlaySIDDebugMode=Off"
    move    #0,psb_Debug(a6)
    rts
.2
    DPRINT  "PlaySIDDebugMode=On"
    move    #1,psb_Debug(a6)
    rts

; Called before AllocEmulResource:
; - SetOperatingMode
; - SetRESIDMode
; - SetAHIMode
; During AllocEmulResource:
; - Settings from env variables
; Called after AllocEmulResource:
; - SetRESIDFilter
; - SetRESIDBoost

EnvMode         dc.b    "PlaySIDMode",0           ; Norm,6581,8580,Auto,Sidb(laster)
EnvResidMode    dc.b    "PlaySIDreSIDMode",0      ; Norm,Ovs2,Ovs3,Ovs4
EnvResidAHI     dc.b    "PlaySIDreSIDAHI",0       ; 00000000 (hex)
EnvResidBoost   dc.b    "PlaySIDreSIDBoost",0     ; 0,1,2,3,4
EnvResidFilter  dc.b    "PlaySIDreSIDFilter",0    ; onIn,on,off
EnvDebugMode    dc.b    "PlaySIDDebug",0          ; on,off
                even
* In:
*  a0 = name
*  a1 = output buffer
* Out:
*  d0 = -1 if failed
GetEnvVarString:
    move.l  a6,a5
    move.l  psb_DOSBase(a5),a6
    cmp     #36,LIB_VERSION(a6)
    blo     .fail
 if DEBUG
    move.l  a0,-(sp)
 endif
    clr.b   (a1)
    move.l  a0,d1               * variable name
    move.l  a1,d2               * output buffer
    moveq   #32,d3              * space available
    move.l  #GVF_GLOBAL_ONLY,d4 * global variable
    jsr     _LVOGetVar(a6)      * get it
 if DEBUG
    move.l  (sp)+,d1
    DPRINT  "GetVar=%ld: %s"
 endif
    tst.l   d0
.x  move.l  a5,a6
    rts    
.fail   
    moveq   #-1,d0
    bra     .x
    
* In:
*   a4 = text 
* Out:
*   d0 = 4 chars in lowercase
get4:
    lea     (a4),a0
    moveq   #4-1,d1
    moveq   #0,d0
.l  rol.l   #8,d0
    move.b  (a0)+,d0
	cmp.b	#'A',d0
	blo.b	.2
	cmp.b	#'Z',d0
	bhi.b	.2
	or.b	#$20,d0 * lower case alphabet
.2  dbf     d1,.l
    rts
    
* in:
*   a0 = 8 chars of text in hexadecimal
* out: 
*   d0 = number or NULL if error
convertHexTextToNumber:
  move.l a0,d0
   DPRINT "hex=%s"
	moveq	#8-1,d2
	moveq	#32-4,d1
	moveq	#0,d0
.loop
	moveq	#0,d3
	move.b	(a0)+,d3
    beq     .fail
	cmp.b	#"a",d3
	bhs.b	.hih 
	cmp.b	#"A",d3
	bhs.b	.hi 
	sub.b	#"0",d3
	bra.b	.lo
.hih
	sub.b	#"a"-10,d3
	bra.b	.lo
.hi
	sub.b	#"A"-10,d3
.lo
    and.b   #$f,d3
	lsl.l  d1,d3
	or.l   d3,d0
	subq   #4,d1
	dbf	d2,.loop
.x
	rts
.fail
    moveq   #0,d0
    rts
    
*-----------------------------------------------------------------------*
@FreeEmulResource
        DPRINT  "FreeEmulResource"
		;CALLEXEC Forbid
		movem.l	d2-d7/a2-a6,-(a7)
		tst.w	psb_EmulResourceFlag(a6)
		beq.s	.Exit
		bsr	@StopSong
		bsr	FreeEmulMem
		clr.w	psb_EmulResourceFlag(a6)

        ; Safe to call even if not initialized:
        bsr     stop_sid_blaster

        ; Not safe if initRESID has not been called earlier:    
        bsr     isResidActive
        beq     .1
        jsr     resetResid
.1  
        jsr     ahiStop

        * Undefine operating modes so that they will be determined again the next time.
        bsr     undefineSettings
.Exit		


  if ENABLE_REGDUMP
        move.l  a6,-(sp)
        move.l  psb_DOSBase(a6),a6
        jsr     saveDump
        move.l  (sp)+,a6
  endif

        move.l  psb_DOSBase(a6),a1
        move.l  4.w,a6
        jsr     _LVOCloseLibrary(a6)

        movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*

* To be called before AllocEmulResource
* in:
*   d0 = Operating mode
@SetOperatingMode
 if DEBUG
        ext.l   d0
        DPRINT  "SetOperatingMode=%ld"
 endif
    	move.w	d0,psb_OperatingMode(a6)
		rts

* To be called before AllocEmulResource
* in:
*   d0 = reSID mode
@SetRESIDMode
 if DEBUG
        ext.l   d0
        DPRINT  "SetRESIDMode=%ld"
 endif
    	move.w	d0,psb_ResidMode(a6)
		rts

@GetOperatingMode
        moveq   #0,d0
    	move.w	psb_OperatingMode(a6),d0
		rts

@GetRESIDMode
        moveq   #0,d0
    	move.w	psb_ResidMode(a6),d0
		rts

* Returns true is reSID operating mode is active
* Out:
*   Z-flag = clear/true, set/false
isResidActive:
        cmp.w   #OM_RESID_6581,psb_OperatingMode(a6)
        beq.b   .2
        cmp.w   #OM_RESID_8580,psb_OperatingMode(a6)
        beq.b   .2
        cmp.w   #OM_RESID_AUTO,psb_OperatingMode(a6)
        beq.b   .2
        * False
        or.b	#(1<<2),ccr  * Set Z
        rts
.2      * True
    	and.b	#~(1<<2),ccr * Clear Z
        rts


* In:
*  d0 = AHI mode to use for reSID, or NULL to not use.
@SetAHIMode
        DPRINT  "SetAHIMode=%lx"
        move.l  d0,psb_AhiMode(a6)
        move.l  d0,ahiMode
        rts

@GetAHIMode
        move.l  psb_AhiMode(a6),d0
        rts


*-----------------------------------------------------------------------*
@SetVertFreq	move.w	d0,psb_VertFreq(a6)
		rts

*-----------------------------------------------------------------------*
@SetTimeSignal	move.l	a0,psb_TimeSignalTask(a6)
		move.l	d0,psb_TimeSignalMask(a6)
		rts

*-----------------------------------------------------------------------*
@SetTimeEnable	move.w	d0,psb_TimeEnable(a6)
		rts

*-----------------------------------------------------------------------*
@SetDisplaySignal	
        move.l	a0,psb_DisplaySignalTask(a6)
		move.l	d0,psb_DisplaySignalMask(a6)
		rts

*-----------------------------------------------------------------------*
@SetDisplayEnable
		move.w	d0,psb_DisplayEnable(a6)
		rts

*-----------------------------------------------------------------------*
@SetReverseEnable
		move.w	d0,psb_ReverseEnable(a6)
		rts

*-----------------------------------------------------------------------*
@SetChannelEnable
		lea	psb_ChannelEnable(a6),a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		rts

*-----------------------------------------------------------------------*
@CheckModule	move.l	a0,d0				; null header?
		beq.s	.Error
		cmpi.l	#SID_HEADER,(a0)		; correct header?
		bne.s	.Error
		move.w	sidh_length(a0),d0
		cmp.w	#sidh_sizeof,d0			; header length?
		bhi.s	.Error
		cmp.w	#SID_VERSION,sidh_version(a0)	; version?
		bhi.s	.Error
		moveq	#0,d0
		rts
.Error		moveq	#SID_BADHEADER,d0
		rts

*-----------------------------------------------------------------------*
@SetModule	;CALLEXEC Forbid
        DPRINT  "SetModule"
        move.l  a1,-(sp)
		cmpi.l	#SID_HEADER,(a1)		; have header?
		bne.s	.1
		move.w	sidh_length(a1),d1		; skip header
		add.w	d1,a1
		sub.w	d1,d0
.1		move.l	a1,psb_SongLocation(a6)
		move.w	d0,psb_SongLength(a6)

		move.w	sidh_start(a0),psb_SongStart(a6)
		move.w	sidh_init(a0),psb_SongInit(a6)
		move.w	sidh_main(a0),psb_SongMain(a6)
		move.w	sidh_number(a0),psb_SongNumber(a6)
		move.w	sidh_defsong(a0),psb_SongDefault(a6)
		move.l	sidh_speed(a0),psb_SongSpeedMask(a6)

		moveq	#0,d0				; default song flags
		cmp.w	#2,sidh_version(a0)
		blo.s	.2
		move.w	sidh_flags(a0),d0
.2		move.w	d0,psb_SongFlags(a6)

		move.w	#1,psb_SongSetFlag(a6)
        move.l  (sp)+,a1

        bsr     getSid2Address
        bsr     getSid3Address
        bsr     getSidChipVersion

		;CALLEXEC Permit
		rts



* In:  
*   a0 = module
getSid2Address:
; +7A    BYTE secondSIDAddress
; Valid values:
; - 0x00 (PSID V2NG)
; - 0x42 - 0x7F, 0xE0 - 0xFE Even values only (Version 3+)
* Ranges 0x00-0x41 ($D000-$D410) and
* 0x80-0xDF ($D800-$DDF0) are invalid.
        clr     psb_Sid2Address(a6)
        cmp     #3,sidh_version(a0)
        blo.b   .x
        move.b  $7a(a1),d0
        btst    #0,d0
        bne.b   .x
        cmp.b   #$42,d0
        blo.b   .x
        cmp.b   #$7f,d0
        bls.b   .sid2      
        cmp.b   #$e0,d0
        blo.b   .x  
        cmp.b   #$fe,d0
        bls.b   .sid2    
.x
		rts
.sid2
        and.l   #$ff,d0
        lsl     #4,d0
        add.l   #$d000,d0
        move.w  d0,psb_Sid2Address(a6)
        DPRINT  "2nd SID at %lx"
        bsr     isResidActive
        beq     .3
        bsr     MakeMMUTable2
.3      rts



* In:  
*   a0 = module
getSid3Address:
; +7    BYTE secondSIDAddress
; Valid values:
; - 0x00 (PSID V2NG)
; - 0x42 - 0x7F, 0xE0 - 0xFE Even values only (Version 3+)
* Ranges 0x00-0x41 ($D000-$D410) and
* 0x80-0xDF ($D800-$DDF0) are invalid.
        clr     psb_Sid3Address(a6)
        cmp     #4,sidh_version(a0)
        blo.b   .x
        move.b  $7b(a1),d0
        btst    #0,d0
        bne.b   .x
        cmp.b   #$42,d0
        blo.b   .x
        cmp.b   #$7f,d0
        bls.b   .sid3      
        cmp.b   #$e0,d0
        blo.b   .x  
        cmp.b   #$fe,d0
        bls.b   .sid3
.x
		rts
.sid3
        and.l   #$ff,d0
        lsl     #4,d0
        add.l   #$d000,d0
        move.w  d0,psb_Sid3Address(a6)
        DPRINT  "3rd SID at %lx"
        bsr     isResidActive
        beq     .3
        bsr     MakeMMUTable3
.3      rts

* Detect SID version to use
* In:  
*   a0 = module
getSidChipVersion:
    move.w  #%01,psb_HeaderChipVersion(a6)
    cmp     #2,sidh_version(a0)
    blo     .v1
    ; Header v2
    ;Bits 4-5 specify the SID version (sidModel):
    ;00 = Unknown,
    ;01 = MOS6581,
    ;10 = MOS8580,
    ;11 = MOS6581 and MOS8580.
    moveq   #%11<<4,d0
    and     sidh_flags(a0),d0
    lsr     #4,d0
    move.w  d0,psb_HeaderChipVersion(a6)
.v1    
    rts


* Valid only after the emulated C64 code has set the timer values.
@GetSongSpeed
        moveq   #0,d0
        move.w	psb_TimerConstB(a6),d0
        bne.b   .1
        move    #28419/2,d1
.1      move.l  #(709379+28419/4),d0
        divu    d1,d0
        ext.l   d0
        move.l  d0,d1
        divu    #50,d0
        ext.l   d0
        divu    #10,d1
        mulu    #10,d1
        rts


*-----------------------------------------------------------------------*
@StartSong	;CALLEXEC Forbid 
 if DEBUG
        ext.l   d0
        DPRINT  "StartSong %ld"
 endif
		movem.l	d2-d7/a2-a6,-(a7)
		tst.w	psb_SongSetFlag(a6)
		bne.s	.SongOK
		moveq	#SID_NOMODULE,D0
		bra	.Exit

.SongOK		tst.w	d0				; Check tune number
		bne.s	.1
		move.w	psb_SongDefault(a6),d0		; If 0, use default tune
.1		subq.w	#1,d0
		cmp.w	psb_SongNumber(a6),d0
		blo.s	.2
		moveq	#SID_NOSONG,D0
		bra	.Exit
.2		move.w	d0,psb_SongTune(a6)

		tst.w	psb_EmulResourceFlag(a6)
		bne.s	.MemOK
		bsr	@AllocEmulResource
		tst.l	d0
		beq.s	.MemOK
		cmp.l	#SID_LIBINUSE,d0
		bne	.Exit

.MemOK		bsr	@StopSong
		bsr	@AllocEmulAudio
		tst.l	d0
		bne	.Exit
		bsr	OpenIRQ
		tst.l	d0
		beq.s	.IrqOK
		move.l	d0,d7
		bsr	@FreeEmulAudio
		move.l	d7,d0
		bra	.Exit
.IrqOK
		move.w	psb_SongTune(a6),d0			;Get tune speed
		move.l	psb_SongSpeedMask(a6),d1
		btst.l	d0,d1
		sne	d1
		ext	d1
		move.w	d1,psb_SongSpeed(a6)
		move.w	psb_SongMain(a6),psb_SongLoop(a6)	;Save loop address

		bsr	InitSpeed
		bsr	InitC64Memory
		bsr	FixSIDSong
		bsr	CalcStartAddr
		bsr	CopyC64File
		bsr	GetC64TimerA
		move.w	d0,psb_OldC64TimerA(a6)

		bsr	InitSID
		move.w	#RM_NONE,psb_RememberMode(a6)
		bsr	StartRemember
		move.l	psb_C64Mem(a6),a0
		add.l	#$D400,a0
		move.b	#$0f,sid_Volume(a0)

		bsr	CalcInitAddr
		bsr	Init64
		bsr	RememberRegs

		bsr	SelectVolume
		bsr	InitTimers
		bsr	CalcUpdateFreq
		bsr	ResetTime
		move.w	#PM_PLAY,psb_PlayMode(a6)
		moveq	#0,d0
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*
@StopSong	;CALLEXEC Forbid
        DPRINT  "StopSong"
		movem.l	d2-d7/a2-a6,-(a7)

		cmp.w	#PM_STOP,psb_PlayMode(a6)
		beq.s	.Exit
		cmp.w	#PM_PAUSE,psb_PlayMode(a6)
		beq.s	.Pause
		bsr	StopTimerB
		bsr	StopTimerA
		bsr	PlayDisable
		bsr	CloseIRQ
		bsr	@FreeEmulAudio
.Pause		bsr	FreeFourMem
		bsr	StopRemember
		move.w	#PM_STOP,psb_PlayMode(a6)
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*
@PauseSong	;CALLEXEC Forbid
        DPRINT "PauseSong"
		movem.l	d2-d7/a2-a6,-(a7)
		cmp.w	#PM_PLAY,psb_PlayMode(a6)
		bne.s	.Exit
		bsr	StopTimerB
		bsr	StopTimerA
		bsr	PlayDisable
		bsr	CloseIRQ
		bsr	@FreeEmulAudio
		move.w	#PM_PAUSE,psb_PlayMode(a6)
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*
@ContinueSong	;CALLEXEC Forbid
        DPRINT "ContinueSong"
		movem.l	d2-d7/a2-a6,-(a7)
		cmp.w	#PM_PAUSE,psb_PlayMode(a6)
		beq.s	.PauseOK
		moveq	#SID_NOPAUSE,D0
		bra	.Exit
.PauseOK	bsr	@AllocEmulAudio
		tst.l	d0
		bne	.Exit
		bsr	OpenIRQ
		tst.l	d0
		beq	.IrqOK
		move.l	d0,d7
		bsr	@FreeEmulAudio
		move.l	d7,d0
		bra	.Exit
.IrqOK		bsr	InitSIDCont
		bsr	InitTimers
		move.w	#PM_PLAY,psb_PlayMode(a6)
		moveq	#0,d0
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*
@ForwardSong	movem.l	d2-d7/a2-a6,-(a7)
		cmp.w	#PM_PLAY,psb_PlayMode(a6)
		bne.s	.Exit

		move.w	d0,d7
		subq.w	#1,d7
		bmi.s	.Exit

		bsr	StopTimerB
.loop		bsr	EmulNextStep
		dbf	d7,.loop

		bsr	DoSound
		bsr	CheckC64TimerA
		bsr	CalcTime
		bsr	StartTimerB
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		rts

*-----------------------------------------------------------------------*
@RewindSong	movem.l	d2-d7/a2-a6,-(a7)
		cmp.w	#PM_PLAY,psb_PlayMode(a6)
		bne.s	.Exit

		move.w	d0,d7
		subq.w	#1,d7
		bmi.s	.Exit

		bsr	StopTimerB
.loop		bsr	RewindRegs
		tst.l	d0
		bne	.1
		subq.w	#1,psb_UpdateCounter(a6)
		dbf	d7,.loop

.1		bsr	DoSound
		bsr	CalcTime
		bsr	StartTimerB
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		rts

*-----------------------------------------------------------------------*
AllocEmulMem
        DPRINT "AllocEmulMem"
		ALLOC	psb_PrgMem(a6),PRGMEM_SIZE,MEMF_PUBLIC
		beq	.Error
		ALLOC	psb_MMUMem(a6),MMUMEM_SIZE,MEMF_PUBLIC
		beq.s	.Error
		ALLOC	psb_C64Mem(a6),C64MEM_SIZE,MEMF_PUBLIC
		beq.s	.Error
		ALLOC	psb_EnvelopeMem(a6),ENVELOPEMEM_SIZE,MEMF_PUBLIC
		beq.s	.Error
		ALLOC	psb_SampleMem(a6),SAMPLEMEM_SIZE,MEMF_CHIP
		beq.s	.Error
        jsr     allocResidMemory
        beq.s   .Error
		moveq	#0,d0
		rts

.Error		bsr	FreeEmulMem
		moveq	#SID_NOMEMORY,D0
		rts

*-----------------------------------------------------------------------*
FreeEmulMem
        DPRINT  "FreeEmulMem"
		FREE	psb_PrgMem(a6),PRGMEM_SIZE
		FREE	psb_MMUMem(a6),MMUMEM_SIZE
		FREE	psb_C64Mem(a6),C64MEM_SIZE
		FREE	psb_EnvelopeMem(a6),ENVELOPEMEM_SIZE
		FREE	psb_SampleMem(a6),SAMPLEMEM_SIZE
        jsr     freeResidMemory
		rts

*-----------------------------------------------------------------------*
TimeRequest
		tst.w	psb_TimeEnable(a6)
		beq.s	.Exit
		move.l	psb_TimeSignalTask(a6),a1
		move.l	psb_TimeSignalMask(a6),d0
		move.l	a6,-(a7)
		CALLEXEC Signal
		move.l	(a7)+,a6
.Exit		rts

*-----------------------------------------------------------------------*
DisplayRequest
		tst.w	psb_DisplayEnable(a6)
		beq.s	.Exit
		move.l	psb_DisplaySignalTask(a6),a1
		move.l	psb_DisplaySignalMask(a6),d0
		move.l	a6,-(a7)
		CALLEXEC Signal
		move.l	(a7)+,a6
.Exit		rts

*-----------------------------------------------------------------------*
Init64	
        DPRINT "Init64"
        movem.l	d2-d7,-(a7)
		move.w	psb_SongTune(a6),d0
		moveq	#$00,d1
		moveq	#$00,d2
		moveq	#$00,d3
		moveq	#$00,d4
		moveq	#$00,d5
		move.w	psb_SongInit(a6),d6
		moveq	#-1,d7
		bsr	Jump6502Routine
		movem.l	(a7)+,d2-d7
		rts

*-----------------------------------------------------------------------*
Play64:
        bsr	EmulNextStep

        tst.w   psb_OperatingMode(a6)
        bne.b   .1
		bsr	    DoSound
		bsr	    ReadDisplayData
		bsr	    DisplayRequest
.1
        cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a6)
        bne.b	.2
		bsr	flush_sid_regs
.2
		bsr	CalcTime
		bsr	CheckC64TimerA

  ifne ENABLE_REGDUMP
        addq.w  #1,regDumpTime
  endif
		rts

*-----------------------------------------------------------------------*
EmulNextStep	movem.l	d2-d7/a5,-(a7)
		move.w	psb_RememberMode(a6),d0
		move.l	psb_C64Mem(a6),a5
		add.l	#$0000D400,a5
		clr.b	ext_Control(a5)
		cmp.w	#RM_PLAYBACK,d0
		beq	.2
		move.w	psb_SongLoop(a6),d6
		bne	.1
		bsr	GetIrqAdress
		move.w	d0,d6

.1
		moveq	#$00,d0
		moveq	#$00,d1
		moveq	#$00,d2
		moveq	#$00,d3
		moveq	#$00,d4
		moveq	#$00,d5
		moveq	#-1,d7
		bsr	Jump6502Routine
		move.w	psb_RememberMode(a6),d0
		cmp.w	#RM_REMEMBER,d0
		bne	.3
		bsr	RememberRegs
		bra	.3
.2		bsr	PlaybackRegs
.3		addq.w	#1,psb_UpdateCounter(a6)
		movem.l	(a7)+,d2-d7/a5
		rts

*-----------------------------------------------------------------------*
DoSound
		move.w	psb_RememberMode(a6),d0
		cmp.w	#RM_PLAYBACK,d0
		bne	.1
		bsr	InitSIDData
		bsr	DoEnvelope
.1		bsr	Sound
		rts

*-----------------------------------------------------------------------*
CalcStartAddr
		tst.w	psb_SongStart(a6)
		bne.s	.1
		move.l	psb_SongLocation(a6),a0
		move.b	1(a0),d0
		lsl.w	#8,d0
		move.b	(a0),d0
		move.w	d0,psb_SongStart(a6)
		addq.l	#2,a0
		move.l	a0,psb_SongLocation(a6)
		subq.w	#2,psb_SongLength(a6)
.1
		rts

*-----------------------------------------------------------------------*
CalcInitAddr
		tst.w	psb_SongInit(a6)
		bne.s	.1
		move.w	psb_SongStart(a6),psb_SongInit(a6)
.1
		rts

*-----------------------------------------------------------------------*
FixSIDSong	
		move.w	psb_SongFlags(a6),d0		; If SID file, copy player
		andi.w	#SIDF_SIDSONG,d0
		beq.s	.2
		lea	SidPlayer+2,a0
		move.l	psb_C64Mem(a6),a1
		add.l	#$0000C000,a1
		move.w	#$1FF,d0
.1		move.l	(a0)+,(a1)+
		dbf	d0,.1
		move.w	#$5FFE,psb_SongStart(a6)
		move.w	#$C7B0,psb_SongInit(a6)
		move.w	#$0000,psb_SongLoop(a6)
.2		rts

*-----------------------------------------------------------------------*
CopyC64File
		move.l	d2,-(a7)
		move.l	psb_SongLocation(a6),a0	;Copy C64 File to Memory
		move.l	psb_C64Mem(a6),a1
		moveq	#$00,d0
		moveq	#$00,d1
		move.w	psb_SongLength(a6),d0
		move.w	psb_SongStart(a6),d1
		add.l	d1,a1
		move.l	d1,d2
		add.l	d0,d2
		cmp.l	#$00010000,d2
		bls.s	.1
		move.l	#$00010000,d0
		sub.l	d1,d0
.1		move.b	(a0)+,(a1)+
		subq.l	#1,d0
		bne.s	.1
		move.l	(a7)+,d2
		rts

*-----------------------------------------------------------------------*
InitC64Memory
		move.l	psb_C64Mem(a6),a0		;Clear C64 Memory
		move.w	#($10000/4)-1,d0
.1		clr.l	(a0)+
		dbf	d0,.1
		move.l	psb_C64Mem(a6),a0
		move.b	#$2f,$0000(a0)
		move.b	#$37,$0001(a0)
		adda.l	#$E000,a0
		move.l	#$40404040,d0			;RTI
		move.w	#($2000/4)-1,d1
.2		move.l	d0,(a0)+
		dbf	d1,.2
		move.l	psb_C64Mem(a6),a0
		adda.l	#$10000,a0
		move.b	#$ff,$FFFFFFFF(a0)
		move.b	#$48,$FFFFFFFE(a0)
		move.b	#$ff,$FFFFFFFB(a0)
		move.b	#$f8,$FFFFFFFA(a0)
		move.b	#$6c,$FFFFFF48(a0)
		move.b	#$14,$FFFFFF49(a0)
		move.b	#$03,$FFFFFF4A(a0)
		rts

*-----------------------------------------------------------------------*
GetIrqAdress
		move.l	psb_C64Mem(a6),a0
		move.b	1(a0),d0
		andi.b	#$02,d0
		beq.s	.1
		move.b	$0315(a0),d0
		lsl.w	#8,d0
		move.b	$0314(a0),d0
		rts
.1
		add.l	#$10000,a0
		move.b	$FFFFFFFF(a0),d0
		lsl.w	#8,d0
		move.b	$FFFFFFFE(a0),d0
		rts

*-----------------------------------------------------------------------*
GetC64TimerA	move.l	psb_C64Mem(a6),a0
		add.l	#$0000DC04,a0
		move.b	1(a0),d0
		lsl.w	#8,d0
		move.b	(a0),d0
		rts

*-----------------------------------------------------------------------*
CheckC64TimerA
		tst.w	psb_SongSpeed(a6)
		beq	.1
		bsr	GetC64TimerA
		cmp.w	psb_OldC64TimerA(a6),d0
		beq	.1
      	move.w	d0,psb_OldC64TimerA(a6)
		mulu	psb_ConvClockConst(a6),d0
		swap	d0
		move.w	d0,psb_TimerConstB(a6)
		bsr	SetTimerB			;Timer B!
		bsr	CalcUpdateFreq       
        jsr calcSamplesAndCyclesPerFrameFromCIATicks
.1
		rts

*-----------------------------------------------------------------------*
CheckCPU	move.l	$4.w,a0
		move.w	AttnFlags(a0),psb_CPUVersion(a6)
		rts

*-----------------------------------------------------------------------*
ReadDisplayData
		tst.w	psb_DisplayEnable(a6)
		beq	.Exit
		movem.l	a2-a5,-(a7)
		move.l	psb_DisplayData(a6),a1
		move.l	psb_EnvelopeMem(a6),a2
		move.l	psb_VolumePointer(a6),a3
		moveq	#$00,d0
		move.l	psb_Enve1(a6),a0
		move.w	env_CurrentAddr(a0),d1
		move.b	0(a2,d1.w),d0
		move.b	0(a3,d0.w),d0		;Master volume calc
		move.w	d0,dd_Enve1(a1)
		move.l	psb_Enve2(a6),a0
		move.w	env_CurrentAddr(a0),d1
		move.b	0(a2,d1.w),d0
		move.b	0(a3,d0.w),d0		;Master volume calc
		move.w	d0,dd_Enve2(a1)
		move.l	psb_Enve3(a6),a0
		move.w	env_CurrentAddr(a0),d1
		move.b	0(a2,d1.w),d0
		move.b	0(a3,d0.w),d0		;Master volume calc
		move.w	d0,dd_Enve3(a1)
		move.l	psb_C64Mem(a6),a0
		add.l	#$d400,a0
		move.b	sid_Volume(a0),d0
		move.w	d0,dd_Volume(a1)

		move.l	psb_Chan1(a6),a0
		move.l	ch_SamAdrOld(a0),dd_Sample1(a1)
		move.w	ch_SamLenOld(a0),dd_Length1(a1)
		move.w	ch_SamPerOld(a0),dd_Period1(a1)
		move.w	ch_SyncLenOld(a0),dd_SyncLength1(a1)
		move.b	ch_SyncIndOld(a0),dd_SyncInd1(a1)
		move.l	psb_Chan2(a6),a0
		move.l	ch_SamAdrOld(a0),dd_Sample2(a1)
		move.w	ch_SamLenOld(a0),dd_Length2(a1)
		move.w	ch_SamPerOld(a0),dd_Period2(a1)
		move.w	ch_SyncLenOld(a0),dd_SyncLength2(a1)
		move.b	ch_SyncIndOld(a0),dd_SyncInd2(a1)
		move.l	psb_Chan3(a6),a0
		move.l	ch_SamAdrOld(a0),dd_Sample3(a1)
		move.w	ch_SamLenOld(a0),dd_Length3(a1)
		move.w	ch_SamPerOld(a0),dd_Period3(a1)
		move.w	ch_SyncLenOld(a0),dd_SyncLength3(a1)
		move.b	ch_SyncIndOld(a0),dd_SyncInd3(a1)
		move.l	psb_Chan4(a6),a0
		move.l	ch4_SamAdr(a0),dd_Sample4(a1)
		move.w	ch4_SamLen(a0),d0
		add.w	d0,d0
		move.w	d0,dd_Length4(a1)
		move.w	ch4_SamPer(a0),dd_Period4(a1)
		move.w	ch4_SamVol(a0),dd_Enve4(a1)
		lea	psb_ChannelEnable(a6),a0
		tst.w	0(a0)
		bne.s	.1
		clr.w	dd_Enve1(a1)
.1		tst.w	2(a1)
		bne.s	.2
		clr.w	dd_Enve2(a1)
.2		tst.w	4(a1)
		bne.s	.3
		clr.w	dd_Enve3(a1)
.3		tst.w	6(a1)
		bne.s	.4
		clr.w	dd_Enve4(a1)
.4		move.l	psb_Chan4(a6),a0
		tst.b	ch4_Active(a0)
		bne.s	.5
		clr.w	dd_Enve4(a1)
.5
		movem.l	(a7)+,a2-a5
.Exit		rts

*-----------------------------------------------------------------------*
InitSpeed
    DPRINT  "InitSpeed"
		movem.l	d2-d3,-(a7)
		tst.w	psb_SongSpeed(a6)
		beq.s	.1
		bra.s	.2
.1
		move.w	#INTTIMEPAL50,d0		;Vert sync.
		move.w	#INTTIMEPAL50,d1
		cmp.w	#50,psb_VertFreq(a6)
		beq.s	.3
		move.w	#INTTIMENTSC60,d0
		move.w	#INTTIMENTSC50,d1
		bra.s	.3
.2
		move.w	#INTTIMEPAL60,d0		;60 Hz and 
		move.w	#INTTIMEPAL50,d1		;variable sync.
		cmp.w	#50,psb_VertFreq(a6)
		beq.s	.3
		move.w	#INTTIMENTSC60,d0
		move.w	#INTTIMENTSC50,d1
.3
		move.w	d0,psb_TimerConstB(a6)		;Play Timer
		move.w	d1,psb_TimerConst50Hz(a6)
		move.l	#CalcFreqData1,d0
		move.w	#ENVTIMEPAL,d1
		move.w	#CONVCLOCKPAL,d2
		move.w	#CONVFOURPAL,d3
		cmp.w	#50,psb_VertFreq(a6)
		beq.s	.4
		move.l	#CalcFreqData2,d0
		move.w	#ENVTIMENTSC,d1
		move.w	#CONVCLOCKNTSC,d2
		move.w	#CONVFOURNTSC,d3
.4
		move.l	d0,psb_CalcFTable(a6)		;Freq Calc Table
		move.w	d1,psb_TimerConstA(a6)		;Envelope Timer
		move.w	d2,psb_ConvClockConst(a6)	;Convert Clock C64 to Amiga
		move.w	d3,psb_ConvFourConst(a6)	;Convert C64 Four Sample speed to Amiga period

        jsr calcSamplesAndCyclesPerFrameFromCIATicks

		movem.l	(a7)+,d2-d3
		rts

*-----------------------------------------------------------------------*
InitSID		
        DPRINT "InitSID"
        movem.l	a2-a3,-(a7)
		move.l	psb_Enve1(a6),a0
		move.w	#env_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Enve2(a6),a0
		move.w	#env_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Enve3(a6),a0
		move.w	#env_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan1(a6),a0
		move.w	#ch_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan2(a6),a0
		move.w	#ch_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan3(a6),a0
		move.w	#ch_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan4(a6),a0
		move.w	#ch4_SIZEOF,d0
		bsr	.Clear

		move.l	psb_C64Mem(a6),a0
		add.l	#$0000D400,a0
		move.w	#$0080,d0
		bsr	.Clear

		move.l	psb_Enve1(a6),a1
		move.l	psb_Enve2(a6),a2
		move.l	psb_Enve3(a6),a3
		move.w	#EM_QUIET,env_Mode(a1)
		move.w	#EM_QUIET,env_Mode(a2)
		move.w	#EM_QUIET,env_Mode(a3)
		moveq	#$00,d0
		move.w	d0,env_CurrentAddr(a1)
		move.w	d0,env_CurrentAddr(a2)
		move.w	d0,env_CurrentAddr(a3)
		move.l	psb_AttackDecay(a6),a0
		move.l	(a0),env_Attack(a1)
		move.l	(a0),env_Attack(a2)
		move.l	(a0),env_Attack(a3)
		move.l	4(a0),env_Decay(a1)
		move.l	4(a0),env_Decay(a2)
		move.l	4(a0),env_Decay(a3)
		move.l	psb_SustainRelease(a6),a0
		move.w	(a0),env_Sustain(a1)
		move.w	(a0),env_Sustain(a2)
		move.w	(a0),env_Sustain(a3)
		move.l	4(a0),env_Release(a1)
		move.l	4(a0),env_Release(a2)
		move.l	4(a0),env_Release(a3)

		move.l	psb_Chan1(a6),a0
		move.w	#-1,ch_SamPer(a0)
		move.w	#4,ch_SamLen(a0)
		move.l	psb_Chan2(a6),a0
		move.w	#-1,ch_SamPer(a0)
		move.w	#4,ch_SamLen(a0)
		move.l	psb_Chan3(a6),a0
		move.w	#-1,ch_SamPer(a0)
		move.w	#4,ch_SamLen(a0)

        bsr     SetCh4VolMultiplier
        bsr     isResidActive
        beq     .1
        jsr     resetResid
.1  
    	movem.l	(a7)+,a2-a3
		rts
.Clear
		clr.b	(a0)+
		subq.w	#1,d0
		bne.s	.Clear
        
        ;; Missing RTS added
        rts

SetCh4VolMultiplier:
		move.l	psb_Chan4(a6),a0
        move.w  #$40,ch4_SamVolMultiplier(a0)   * No scaling

        bsr     isResidActive
        beq     .1

        * Scale the 4ch sample volume accordingly too
        moveq   #CH4_RESID_VOLSCALE,d0
        move.l  psb_reSID(a6),a1
        move.l  sid_outputBoost(a1),d1
        beq.b   .3
        mulu    d1,d0
        cmp.w   #$40,d0
        bls.b   .3
        moveq   #$40,d0
.3
        move.w  d0,ch4_SamVolMultiplier(a0)
.1
        rts

   
*-----------------------------------------------------------------------*
InitSIDCont	move.l	psb_Chan1(a6),a0
		move.w	#ch_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan2(a6),a0
		move.w	#ch_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan3(a6),a0
		move.w	#ch_SIZEOF,d0
		bsr	.Clear
		move.l	psb_Chan4(a6),a0
		move.w	#ch4_SIZEOF,d0
		bsr	.Clear

		move.l	psb_Chan1(a6),a0
		move.w	#-1,ch_SamPer(a0)
		move.w	#4,ch_SamLen(a0)
		move.l	psb_Chan2(a6),a0
		move.w	#-1,ch_SamPer(a0)
		move.w	#4,ch_SamLen(a0)
		move.l	psb_Chan3(a6),a0
		move.w	#-1,ch_SamPer(a0)
		move.w	#4,ch_SamLen(a0)

        bsr     SetCh4VolMultiplier

		rts
.Clear
		clr.b	(a0)+
		subq.w	#1,d0
		bne.s	.Clear

        ;; Missing RTS added
        rts

*-----------------------------------------------------------------------*
CalcUpdateFreq
		move.l	d2,-(a7)
		moveq	#$00,d0
		moveq	#$00,d1
		move.w	psb_TimerConst50Hz(a6),d0	;~50hz !
		move.w	psb_TimerConstB(a6),d1
		mulu	#50,d0
		move.l	d1,d2
		lsr.l	#1,d2
		add.l	d2,d0
		divu	d1,d0
		move.w	d0,psb_UpdateFreq(a6)
		move.l	(a7)+,d2
		rts

*-----------------------------------------------------------------------*
ResetTime
		clr.w	psb_TimeSeconds(a6)		;Set time to 00:00
		clr.w	psb_TimeMinutes(a6)
		clr.w	psb_UpdateCounter(a6)
		bsr	TimeRequest
		rts

*-----------------------------------------------------------------------*
CalcTime
		move.w	psb_UpdateCounter(a6),d0
		bmi	.3
		move.w	psb_UpdateFreq(a6),d1
		cmp.w	d0,d1
		bhi.s	.2
		sub.w	d1,d0
		move.w	d0,psb_UpdateCounter(a6)
		moveq	#60,d1
		move.w	psb_TimeSeconds(a6),d0
		addq.w	#1,d0
		cmp.w	d0,d1
		bhi.s	.1
		sub.w	d1,d0
		addq.w	#1,psb_TimeMinutes(a6)
.1		move.w	d0,psb_TimeSeconds(a6)
		bsr	TimeRequest
.2		rts
.3		add.w	psb_UpdateFreq(a6),d0
		move.w	d0,psb_UpdateCounter(a6)
		moveq	#60,d1
		move.w	psb_TimeSeconds(a6),d0
		subq.w	#1,d0
		bpl.s	.1
		add.w	d1,d0
		subq.w	#1,psb_TimeMinutes(a6)
		bra.s	.1
		
*-----------------------------------------------------------------------*

*=======================================================================*
*	SOUND REMEMBER ROUTINES						*
*=======================================================================*
StartRemember
		tst.w	psb_ReverseEnable(a6)
		beq.s	.1
		move.l	#srp_SIZEOF,d0
		move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
		move.l	a6,-(a7)
		CALLEXEC AllocMem
		move.l	(a7)+,a6
		move.l	d0,psb_SoundRemPars(a6)
		move.w	#RM_REMEMBER,psb_RememberMode(a6)
		clr.l	psb_PlayBackPars(a6)
.1		rts

StopRemember
		cmp.w	#RM_NONE,psb_RememberMode(a6)
		beq	.3
		move.l	psb_SoundRemPars(a6),d0
		beq	.2
		move.l	d0,a1
		move.l	srp_SoundRemList(a1),-(a7)
		move.l	#srp_SIZEOF,d0
		move.l	a6,-(a7)
		CALLEXEC FreeMem
		move.l	(a7)+,a6
		clr.l	psb_SoundRemPars(a6)
.1		move.l	(a7)+,d0
		tst.l	d0
		beq	.2
		move.l	d0,a1
		move.l	srl_Next(a1),-(a7)
		move.l	#srl_SIZEOF,d0
		move.l	a6,-(a7)
		CALLEXEC FreeMem
		move.l	(a7)+,a6
		bra	.1
.2
		move.l	psb_PlayBackPars(a6),d0
		beq	.3
		move.l	d0,a1
		move.l	#psp_SIZEOF,d0
		move.l	a6,-(a7)
		CALLEXEC FreeMem
		move.l	(a7)+,a6
		clr.l	psb_PlayBackPars(a6)
.3		move.w	#RM_NONE,psb_RememberMode(a6)
		rts
 
AllocNewRemBlock
		move.l	a4,-(a7)
		move.l	psb_SoundRemPars(a6),a4
		addq.w	#1,srp_NextFree_Block(a4)
		move.l	srp_NextFree_Base(a4),d0
		beq	.1
		cmp.w	#srl_SIZEOF-rrl_SIZEOF,srp_NextFree_Offset(a4)
		beq	.1
		add.w	#rrl_SIZEOF,srp_NextFree_Offset(a4)
		bra	.4

.1		move.l	#srl_SIZEOF,d0
		add.l	d0,srp_MemoryUsage(a4)
		move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
		move.l	a6,-(a7)
		CALLEXEC AllocMem
		move.l	(a7)+,a6
		move.l	srp_NextFree_Base(a4),d1
		move.l	d0,srp_NextFree_Base(a4)
		tst.l	srp_SoundRemList(a4)
		bne	.2
		move.l	d0,srp_SoundRemList(a4)
.2
		move.l	d0,a0
		move.l	d1,srl_Preceed(a0)
		tst.l	d1
		beq	.3
		move.l	d1,a0
		move.l	d0,srl_Next(a0)
.3
		move.w	#srl_Registers,srp_NextFree_Offset(a4)
.4
		move.l	(a7)+,a4
		rts

RememberRegs
		movem.l	d2-d5/a2-a5,-(a7)
		move.l	psb_C64Mem(a6),a5
		cmp.w	#RM_REMEMBER,psb_RememberMode(a6)
		bne	.5
		move.l	psb_SoundRemPars(a6),a4
		lea	RememberTable,a3
		lea	srp_D400_Data(a4),a2
		moveq	#-1,d3
		moveq	#$00,d2
		tst.l	srp_Step(a4)
		bne	.8
.6		move.w	(a3)+,d2
		beq	.7
		move.b	0(a5,d2.l),(a2)+
		bra	.6
.7
		lea	RememberTable,a3
		lea	srp_D400_Data(a4),a2
.8		addq.l	#1,srp_Step(a4)
.1
		addq.l	#1,d3
		move.w	(a3)+,d2
		beq	.5
		move.b	0(a5,d2.l),d1
		move.b	(a2)+,d0
		cmp.b	d1,d0
		bne	.2
		addq.b	#1,srp_D400_Repeat-srp_D400_Data-1(a2)
		bne	.1
		st	srp_D400_Repeat-srp_D400_Data-1(a2)
.2
		move.l	d3,d4
		add.l	d4,d4
		move.l	d4,d5
		add.l	d4,d4
		move.l	srp_D400_Base(a4,d4.l),d0
		bne	.3
		bsr	AllocNewRemBlock
		move.l	srp_NextFree_Base(a4),a0
		add.w	srp_NextFree_Offset(a4),a0
		move.l	a0,srp_D400_Base(a4,d4.l)
		lea	srp_D400_Blocks(a4),a1
		move.w	srp_NextFree_Block(a4),0(a1,d5.l)
		lea	srp_D400_Offset(a4),a1
		move.w	#rrl_RegData,0(a1,d5.l)
.3
		lea	srp_D400_Offset(a4),a1
		cmp.w	#rrl_SIZEOF,0(a1,d5.l)
		bne	.4
		move.w	#rrl_RegData,0(a1,d5.l)
		move.l	srp_D400_Base(a4,d4.l),-(a7)
		bsr	AllocNewRemBlock
		move.l	srp_NextFree_Base(a4),a0
		add.w	srp_NextFree_Offset(a4),a0
		move.l	a0,srp_D400_Base(a4,d4.l)
		lea	srp_D400_Blocks(a4),a1
		move.w	0(a1,d5.l),rrl_PrecBlock(a0)
		move.l	(a7)+,a0
		move.w	srp_NextFree_Block(a4),rrl_NextBlock(a0)
		move.w	srp_NextFree_Block(a4),0(a1,d5.l)
.4
		move.l	srp_D400_Base(a4,d4.l),a0
		lea	srp_D400_Offset(a4),a1
		add.w	0(a1,d5.l),a0
		move.b	-1(a2),rd_Data(a0)
		move.b	srp_D400_Repeat-srp_D400_Data-1(a2),rd_Repeats(a0)
		add.w	#rd_SIZEOF,0(a1,d5.l)
		move.b	0(a5,d2.l),-1(a2)
		move.b	#1,srp_D400_Repeat-srp_D400_Data-1(a2)
		bra	.1
.5
		movem.l	(a7)+,d2-d5/a2-a5
		rts

RewindRegs	movem.l	d2-d5/a2-a4,-(a7)
		cmp.w	#RM_NONE,psb_RememberMode(a6)
		beq	.13
		cmp.w	#RM_PLAYBACK,psb_RememberMode(a6)
		beq	.3
		cmp.w	#RM_REMEMBER,psb_RememberMode(a6)
		bne	.13
		move.w	#RM_PLAYBACK,psb_RememberMode(a6)
		move.l	psb_PlayBackPars(a6),d0
		bne	.0
		move.l	#psp_SIZEOF,d0
		move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
		move.l	a6,-(a7)
		CALLEXEC AllocMem
		move.l	(a7)+,a6
		move.l	d0,psb_PlayBackPars(a6)
.0		move.l	d0,a1
		move.l	psb_SoundRemPars(a6),a0
		lea	srp_ORDINARY(a0),a0
		move.w	#psp_EXTRA-1,d0
.1		move.b	(a0)+,(a1)+
		dbf	d0,.1
		move.w	#BLOCKS_SET-1,d0
		move.l	psb_PlayBackPars(a6),a0
		lea	psp_D400_Counts(a0),a1
		lea	psp_D400_Repeat(a0),a0
.2		move.b	(a0)+,(a1)
		subq.b	#1,(a1)+
		dbf	d0,.2

.3		move.l	psb_PlayBackPars(a6),a4
		move.l	psp_Step(a4),d0
		beq	.13
		cmp.l	#1,d0
		beq	.13
		subq.l	#1,psp_Step(a4)

		moveq	#BLOCKS_SET,d3
		lea	psp_D400_Counts(a4),a2
.4		subq.l	#1,d3
		bmi	.12
		tst.b	0(a2,d3.w)
		beq	.5
		subq.b	#1,0(a2,d3.w)
		bra	.4
.5
		move.l	d3,d4
		add.l	d4,d4
		move.l	d4,d5
		add.l	d4,d4
		lea	psp_D400_Offset(a4),a0
		lea	psp_D400_Base(a4),a1
		cmp.w	#rrl_RegData,0(a0,d5.w)
		bne	.10
		move.l	0(a1,d4.l),a3
		move.w	rrl_PrecBlock(a3),d2
		lea	psp_D400_Blocks(a4),a0
		move.w	d2,0(a0,d5.w)
		move.l	psp_NextFree_Base(a4),a0
		move.w	psp_NextFree_Offset(a4),d1
		move.w	psp_NextFree_Block(a4),d0
		sub.w	d2,d0
.6		cmp.w	#BLOCKS_SET,d0
		bls	.8
		subi.w	#BLOCKS_SET,d0
		move.l	srl_Preceed(a0),a0
		bra	.6
.7		subi.w	#rrl_SIZEOF,d1
.8		tst.w	d0
		beq	.9
		subq.w	#1,d0
		cmp.w	#srl_Registers,d1
		bne	.7
		move.l	srl_Preceed(a0),a0
		move.w	#srl_SIZEOF,d1
		bra	.7
.9
		add.w	d1,a0
		move.l	a0,0(a1,d4.w)
		lea	psp_D400_Offset(a4),a0
		move.w	#rrl_SIZEOF,0(a0,d5.w)

.10		sub.w	#rd_SIZEOF,0(a0,d5.w)
		move.l	0(a1,d4.w),a3
		add.w	0(a0,d5.w),a3
		lea	psp_D400_Data(a4),a0
		move.b	(a3)+,0(a0,d3.w)
		lea	psp_D400_Repeat(a4),a0
		move.b	(a3),0(a0,d3.w)
		move.b	(a3),0(a2,d3.w)
		subq.b	#1,0(a2,d3.w)
		bra	.4
.12
		moveq	#$00,d0
		movem.l	(a7)+,d2-d5/a2-a4
		rts
.13
		moveq	#-1,d0
		movem.l	(a7)+,d2-d5/a2-a4
		rts

PlaybackRegs	movem.l	d2-d5/a2-a4,-(a7)
		cmp.w	#RM_NONE,psb_RememberMode(a6)
		beq	.10
		cmp.w	#RM_PLAYBACK,psb_RememberMode(a6)
		bne	.10
		move.l	psb_SoundRemPars(a6),a3
		move.l	psb_PlayBackPars(a6),a4
		move.l	srp_Step(a3),d0
		subq.l	#1,d0
		cmp.l	psp_Step(a4),d0
		bne	.1
		move.w	#RM_REMEMBER,psb_RememberMode(a6)
.1
		addq.l	#1,psp_Step(a4)
		moveq	#-1,d3
		lea	psp_D400_Counts(a4),a2
.2		addq.l	#1,d3
		cmp.w	#BLOCKS_SET,d3
		beq	.10
		addq.b	#1,0(a2,d3.l)
		move.b	0(a2,d3.l),d0
		cmp.b	psp_D400_Repeat-psp_D400_Counts(a2,d3.l),d0
		beq	.3
		bra	.2
.3
		move.b	#$00,0(a2,d3.l)
		move.l	d3,d4
		add.l	d4,d4
		move.l	d4,d5
		add.l	d4,d4
		lea	psp_D400_Offset(a4),a0
		lea	srp_D400_Offset(a3),a1
		move.w	0(a0,d5.l),d0
		addi.w	#rd_SIZEOF,d0
		move.w	d0,0(a0,d5.l)
		cmp.w	0(a1,d5.l),d0
		bne	.4
		move.l	psp_D400_Base(a4,d4.l),d0
		cmp.l	srp_D400_Base(a3,d4.l),d0
		bne	.4
		lea	psp_D400_Data(a4),a0
		lea	srp_D400_Data(a3),a1
		move.b	0(a1,d3.l),0(a0,d3.l)
		move.b	srp_D400_Repeat-srp_D400_Data(a1,d3.l),psp_D400_Repeat-psp_D400_Data(a0,d3.l)
		bra	.2
.4
		lea	psp_D400_Offset(a4),a1
		cmp.w	#rrl_SIZEOF,0(a1,d5.l)
		bne	.9
		move.w	#rrl_RegData,0(a1,d5.l)
		move.l	psp_D400_Base(a4,d4.l),a0
		move.w	rrl_NextBlock(a0),d2
		move.l	psp_NextFree_Base(a4),a0
		move.w	psp_NextFree_Offset(a4),d1
		move.w	psp_NextFree_Block(a4),d0
		sub.w	d2,d0
.5		cmp.w	#BLOCKS_SET,d0
		bls	.7
		subi.w	#BLOCKS_SET,d0
		move.l	srl_Preceed(a0),a0
		bra	.5
.6		subi.w	#rrl_SIZEOF,d1
.7		tst.w	d0
		beq	.8
		subq.w	#1,d0
		cmp.w	#srl_Registers,d1
		bne	.6
		move.l	srl_Preceed(a0),a0
		move.w	#srl_SIZEOF,d1
		bra	.6
.8
		add.w	d1,a0
		move.l	a0,psp_D400_Base(a4,d4.l)
		lea	psp_D400_Blocks(a4),a1
		move.w	d2,0(a1,d5.l)
.9
		move.l	psp_D400_Base(a4,d4.l),a0
		lea	psp_D400_Offset(a4),a1
		add.w	0(a1,d5.l),a0
		lea	psp_D400_Data(a4),a1
		move.b	rd_Data(a0),0(a1,d3.l)
		move.b	rd_Repeats(a0),psp_D400_Repeat-psp_D400_Data(a1,d3.l)
		bra	.2
.10
		movem.l	(a7)+,d2-d5/a2-a4
		rts

InitSIDData	movem.l	a2-a3,-(a7)
		move.l	psb_C64Mem(a6),a3
		move.l	psb_PlayBackPars(a6),a2
		lea	RememberTable,a1
		lea	psp_D400_Data(a2),a0
		moveq	#$00,d0
.1		move.w	(a1)+,d0
		beq	.2
		move.b	(a0)+,0(a3,d0.l)
		bra	.1
.2
		movem.l	(a7)+,a2-a3
		rts

*=======================================================================*
*	SOUND EMULATION ROUTINES					*
*=======================================================================*
Sound		movem.l	d2-d7/a2-a5,-(a7)
		move.l	psb_C64Mem(a6),a5
		add.l	#$0000D400,a5
		lea	_custom,a4		;HardwareBase
		move.l	psb_Chan1(a6),a0
		moveq	#$00,d0
		lea	psb_ChannelEnable(a6),a1
		tst.w	0(a1)
		beq.s	.NoChan1
		move.b	sid_Voice1FreqHigh(a5),d0
		lsl.w	#8,d0
		move.b	sid_Voice1FreqLow(a5),d0
.NoChan1	bsr	CalcFreq
		move.l	psb_Chan2(a6),a0
		moveq	#$00,d0
		lea	psb_ChannelEnable(a6),a1
		tst.w	2(a1)
		beq.s	.NoChan2
		move.b	sid_Voice2FreqHigh(a5),d0
		lsl.w	#8,d0
		move.b	sid_Voice2FreqLow(a5),d0
.NoChan2	bsr	CalcFreq
		move.l	psb_Chan3(a6),a0
		moveq	#$00,d0
		lea	psb_ChannelEnable(a6),a1
		tst.w	4(a1)
		beq.s	.NoChan3
		move.b	sid_Voice3FreqHigh(a5),d0
		lsl.w	#8,d0
		move.b	sid_Voice3FreqLow(a5),d0
.NoChan3	bsr	CalcFreq

		move.l	psb_SIDSampleFree(a6),a3
		lea	psb_NewFreq(a6),a0
		and.w	#$0400,(a0)
		adda.w	(a0),a3
		eor.w	#$0400,(a0)
		lea	(a3),a1
		move.l	psb_Chan1(a6),a0
		move.l	psb_Chan3(a6),a2
		move.b	sid_Voice1Control(a5),d0
		move.b	sid_Voice1PulseHigh(a5),d1
		lsl.w	#8,d1
		move.b	sid_Voice1PulseLow(a5),d1
		move.w	#$0000,d2
		bsr	CreateSample
		move.l	psb_Chan2(a6),a0
		lea	$800(a3),a1
		move.l	psb_Chan1(a6),a2
		move.b	sid_Voice2Control(a5),d0
		move.b	sid_Voice2PulseHigh(a5),d1
		lsl.w	#8,d1
		move.b	sid_Voice2PulseLow(a5),d1
		move.w	#$0400,d2
		bsr	CreateSample
		move.l	psb_Chan3(a6),a0
		lea	$1000(a3),a1
		move.l	psb_Chan2(a6),a2
		move.b	sid_Voice3Control(a5),d0
		move.b	sid_Voice3PulseHigh(a5),d1
		lsl.w	#8,d1
		move.b	sid_Voice3PulseLow(a5),d1
		move.w	#$0800,d2
		bsr	CreateSample

		moveq	#DMAF_AUD0,d3
		move.w	#INTF_AUD0,d2
		move.l	psb_Chan1(a6),a0
		lea	AUD0LC(a4),a2
		lea	level4H1List,a1
		bsr	StartSample
		moveq	#DMAF_AUD1,d3
		move.w	#INTF_AUD1,d2
		move.l	psb_Chan2(a6),a0
		lea	AUD1LC(a4),a2
		lea	level4H2List,a1
		bsr	StartSample
		moveq	#DMAF_AUD2,d3
		move.w	#INTF_AUD2,d2
		move.l	psb_Chan3(a6),a0
		lea	AUD2LC(a4),a2
		lea	level4H3List,a1
		bsr	StartSample

		bsr	CreateFour

		move.l	psb_Chan3(a6),a0
		move.l	ch_SamAdrNew(a0),a1
		move.w	ch_SamLenNew(a0),d0
		clr.l	d1
		move.w	$dff006,d1
		rol.w	#8,d1
		divu	d0,d1
		swap	d1
		add.w	d1,a1
		move.b	(a1),d0
		addi.b	#$80,d0
		move.b	d0,sid_Osc3Random(a5)
		move.l	psb_Enve3(a6),a0
		move.w	env_CurrentAddr(a0),d0
		move.l	psb_EnvelopeMem(a6),a0
		move.b	0(a0,d0.w),sid_Enve3Output(a5)

		movem.l	(a7)+,d2-d7/a2-a5
		rts

*-----------------------------------------------------------------------*
CalcFreq			;A0=Channeldata,D0=VoiceFreq64
		move.l	d2,-(a7)
		move.w	d0,ch_Freq64New(a0)
		cmp.w	ch_Freq64Old(a0),d0
		beq.s	.3
		moveq	#$04,d1
		moveq	#-1,d2
		tst.w	d0
		beq.s	.2
		move.l	psb_CalcFTable(a6),a1
.1		addq.l	#6,a1
		move.l	(a1)+,d1
		cmp.l	d1,d0
		bls	.1
		lea	-20(a1),a1
		move.w	(a1)+,d1
		move.l	(a1)+,d2
		divu	d0,d2
.2
		move.w	d1,ch_SamLen(a0)
		move.w	d2,ch_SamPer(a0)
		move.w	ch_Freq64New(a0),ch_Freq64Old(a0)
.3		move.l	(a7)+,d2
		rts

*-----------------------------------------------------------------------*
*		0000	Pulse waveform ($0C00)
*		0C00	Sawtooth waveform ($0700)
*		1300	Triangle waveform ($0700)
*		1A00	TriSaw waveform ($0700)
*		2100	TriPul waveform ($0700)
*		2800	Noise waveform ($4000)
*		6800	Work waveform Chan 1 ($0800)
*		7000	Work waveform Chan 2 ($0800)
*		7800	Work waveform Chan 3 ($0800)
*		8000	Fourth waveform ($0400)
*		8400	Fourth convert table ($0300)
*-----------------------------------------------------------------------*
MakeSIDSamples
		movem.l	d2-d5/a2,-(a7)
		move.l	psb_SampleMem(a6),a0
		move.l	a0,psb_SIDSamplePulse(a6)
		lea	$0C00(a0),a1
		move.l	a1,psb_SIDSampleSaw(a6)
		lea	$1300(a0),a1
		move.l	a1,psb_SIDSampleTri(a6)
		lea	$1A00(a0),a1
		move.l	a1,psb_SIDSampleTSaw(a6)
		lea	$2100(a0),a1
		move.l	a1,psb_SIDSampleTPul(a6)
		lea	$2800(a0),a1
		move.l	a1,psb_SIDSampleNoise(a6)
		lea	$6800(a0),a1
		move.l	a1,psb_SIDSampleFree(a6)
		move.l	a0,a1
		add.l	#$8000,a1
		move.l	a1,psb_SIDSampleFour(a6)
		move.l	a0,a1
		add.l	#$8400,a1
		move.l	a1,psb_SIDSampleFConv(a6)

		move.l	psb_SIDSamplePulse(a6),a0	;Making Pulse Waveform
		moveq	#$02,d1
		move.w	#$00ff,d0		;Even Samples
MakeSIDSPul	move.b	#$80,(a0)+
		dbf	d0,MakeSIDSPul

		move.w	#$00ff,d0
.1		move.b	#$7f,(a0)+
		dbf	d0,.1

		move.w	#$0100,d0		;Odd Samples
.2		move.b	#$80,(a0)+
		dbf	d0,.2

		move.w	#$00fe,d0
.3		move.b	#$7f,(a0)+
		dbf	d0,.3
		move.w	#$00ff,d0
		dbf	d1,MakeSIDSPul

		move.l	psb_SIDSampleSaw(a6),a0	;Making Sawtooth Waveform
		lea	MakeSIDSData2,a1
		move.w	(a1)+,d2
		move.l	#$AAAAAAAA,d5
MakeSIDSSaw	move.w	d2,d3
		move.l	#$00010000,d4
		divu	d3,d4
		subq.w	#1,d3
		move.w	#$7f00,d1
.1		move.w	d1,d0
		lsr.w	#8,d0
		move.b	d0,(a0)+
		sub.w	d4,d1
		dbf	d3,.1
		lsr.l	#1,d5
		bcc.s	MakeSIDSSaw
		move.w	(a1)+,d2
		bne.s	MakeSIDSSaw

		move.l	psb_SIDSampleTri(a6),a0	;Making Triangle Waveform
		lea	MakeSIDSData2,a1
		move.w	(a1)+,d2
		move.l	#$AAAAAAAA,d5
MakeSIDSTri	move.w	d2,d3
		lsr.w	#1,d3
		move.l	#$00010000,d4
		divu	d3,d4
		subq.w	#1,d3
		move.w	#$8000,d1
.1		move.w	d1,d0
		lsr.w	#8,d0
		move.b	d0,(a0)+
		add.w	d4,d1
		dbf	d3,.1
		move.w	d2,d3
		lsr.w	#1,d3
		subq.w	#1,d3
		move.w	#$7f00,d1
.2		move.w	d1,d0
		lsr.w	#8,d0
		move.b	d0,(a0)+
		sub.w	d4,d1
		dbf	d3,.2
		lsr.l	#1,d5
		bcc.s	MakeSIDSTri
		move.w	(a1)+,d2
		bne.s	MakeSIDSTri

		move.l	psb_SIDSampleTSaw(a6),a0	;Making TriSaw Waveform
		move.l	psb_SIDSampleSaw(a6),a1
		move.l	psb_SIDSampleTri(a6),a2
		move.l	#$80808080,d1
		move.w	#$01bf,d0
MakeSIDSTSaw	move.l	(a2)+,d2
		move.l	(a1)+,d3
		eor.l	d1,d2
		eor.l	d1,d3
		and.l	d2,d3
		eor.l	d1,d3
		move.l	d3,(a0)+
		dbf	d0,MakeSIDSTSaw

		move.l	psb_SIDSampleNoise(a6),a0	;Making Noise Waveform
		lea	$4000(a0),a1
		moveq	#$00,d0
		move.l	#$8d921,D1
MakeSIDSNoise	move.l	d1,d0
		lsr.l	#$2,d0
		andi.b	#$1,d0
		move.l	d1,d2
		lsr.l	#$3,d2
		andi.b	#$2,d2
		or.l	d2,d0
		move.l	d1,d2
		lsr.l	#$5,d2
		andi.b	#$4,d2
		or.l	d2,d0
		move.l	d1,d2
		moveq	#$8,d3
		lsr.l	d3,d2
		andi.b	#$8,d2
		or.l	d2,d0
		move.l	d1,d2
		moveq	#$9,d3
		lsr.l	d3,d2
		andi.b	#$10,d2
		or.l	d2,d0
		move.l	d1,d2
		moveq	#$b,d3
		lsr.l	d3,d2
		andi.b	#$20,d2
		or.l	d2,d0
		move.l	d1,d2
		moveq	#$e,d3
		lsr.l	d3,d2
		andi.b	#$40,d2
		or.l	d2,d0
		move.l	d1,d2
		moveq	#$f,d3
		lsr.l	d3,d2
		andi.b	#-$80,d2
		or.l	d2,d0
		eori.b	#-$80,d0
		move.b	d0,(a0)+
		move.l	d1,d0
		moveq	#$16,d3
		lsr.l	d3,d0
		andi.b	#$1,d0
		move.l	d1,d2
		moveq	#$11,d3
		lsr.l	d3,d2
		andi.b	#$1,d2
		eor.l	d2,d0
		add.l	d1,d1
		or.b	d0,d1
		cmpa.l	a0,a1
		bne.w	MakeSIDSNoise

		move.l	psb_SIDSampleTri(a6),a0	;Making TriPul Waveform
		move.l	psb_SIDSampleTPul(a6),a1
		lea	MakeSIDSData1,a2	;Convert Table
		move.w	#$06ff,d0
		moveq	#$00,d1
MakeSIDSTPul	move.b	(a0)+,d1
		eor.b	#$80,d1
		cmp.b	#$77,d1
		bhi.s	.1
		moveq	#$00,d1
		bra.s	.2
.1		subi.b	#$78,d1
		move.b	0(a2,d1.w),d1
.2		eori.b	#$80,d1
		move.b	d1,(a1)+
		dbf	d0,MakeSIDSTPul

		move.l	psb_SIDSampleFour(a6),a0
		lea	MakeSIDSData3,a1
		moveq	#$00,d0
MakeSIDSFour	moveq	#$3f,d1
		moveq	#$00,d2
.1		move.b	0(a1,d2.w),(a0)+
		add.w	d0,d2
		andi.w	#$000f,d2
		dbf	d1,.1
		addq.w	#$01,d0
		andi.w	#$000f,d0
		bne.s	MakeSIDSFour

		move.l	psb_SIDSampleFConv(a6),a0
		moveq	#$0f,d0				;Low Byte
MakeSIDSFConv
		lea	MakeSIDSData3,a1
		moveq	#$0f,d1
.1		move.b	(a1)+,(a0)+
		dbf	d1,.1
		dbf	d0,MakeSIDSFConv
		lea	MakeSIDSData3,a1
		moveq	#$0f,d0				;High Byte
.2		move.b	(a1)+,d2
		moveq	#$0f,d1
.3		move.b	d2,(a0)+
		dbf	d1,.3
		dbf	d0,.2
		moveq	#$00,d0				;Sum Low+High
.4		move.b	d0,d1
		move.b	d0,d2
		andi.b	#$0f,d1
		lsr.b	#4,d2
		add.b	d2,d1
		move.b	d1,(a0)+
		addq.b	#1,d0
		bne.s	.4

		movem.l	(a7)+,d2-d5/a2
		rts

*-----------------------------------------------------------------------*
StartSample					;A0=Channeldata
						;A1=ChanProgList
						;A2=Hardwareadress
						;A4=HardwareBase
						;A6=PlaySidBase
						;D2=IrqMask
						;D3=DmaMask
		move.w	DMACONR(a4),d4
		and.w	d3,d4
		beq.s	StartSInit			;DMA not enabled!

		cmp.b	#$01,ch_SyncIndNew(a0)
		beq	StartSSync			;Sync
		cmp.b	#$02,ch_SyncIndNew(a0)
		beq	StartSRing			;Ring
		cmp.b	#$03,ch_SyncIndNew(a0)
		beq	StartSRSync			;Ring+Sync

		move.b	ch_WaveOld(a0),d4		;Old Waveform
		bmi.s	StartSBreak			;Noise Waveform !
		tst.b	ch_SyncIndOld(a0)
		bne.s	StartSBreak			;Old sync irq
		cmp.b	ch_WaveNew(a0),d4		;New Waveform
		bne.s	StartSBreak
		move.w	ch_SamLenNew(a0),d4
		cmp.w	ch_SamLenOld(a0),d4
		beq.s	StartSNormal
		cmp.w	#$0040,ch_SamLenOld(a0)
		bls	StartSWait

StartSBreak
		move.w	d2,INTENA(a4)
		move.w	d3,DMACON(a4)
		move.w	d2,INTREQ(a4)
		clr.w	ac_dat(a2)
		move.w	#$0001,ac_per(a2)
		bsr	StartSUpdaReg
		move.b	#CAI_START,ch_AudIRQType(a0)	;Start New wave IRQ
		bsr	SetChanProg
		ori.w	#INTF_SETCLR,d2
		move.w	d2,INTENA(a4)
		rts

StartSInit
		bsr	StartSUpdaReg
		move.b	#CAI_START,ch_AudIRQType(a0)	;Start New wave IRQ
		bsr	SetChanProg
		ori.w	#INTF_SETCLR,d2
		move.w	d2,INTREQ(a4)
		move.w	d2,INTENA(a4)
		rts

StartSNormal
		bsr	StartSUpdaReg
		move.b	#CAI_NONE,ch_AudIRQType(a0)
		move.l	ch_SamAdrOld(a0),d0
		move.w	ch_SamLenOld(a0),d1
		lsr.w	#1,d1
		swap	d1
		move.w	ch_SamPerOld(a0),d1
		move.w	#INTF_INTEN,INTENA(a4)
		move.w	d2,INTREQ(a4)
		movem.l	d0/d1,(a2)
		move.w	INTREQR(a4),d4
		move.w	#INTF_SETCLR+INTF_INTEN,INTENA(a4)
		and.w	d2,d4
		bne	StartSBreak
		rts

StartSWait
		move.w	ch_SamPerOld(a0),-(a7)
		bsr	StartSUpdaReg
		move.b	#CAI_START,ch_AudIRQType(a0)	;Start New wave IRQ
		bsr	SetChanProg
		move.l	ch_SamAdrOld(a0),d0
		move.w	ch_SamLenOld(a0),d1
		lsr.w	#1,d1
		swap	d1
		move.w	(a7)+,d1
		move.w	#INTF_INTEN,INTENA(a4)
		move.w	d2,INTREQ(a4)
		movem.l	d0/d1,(a2)
		move.w	INTREQR(a4),d4
		move.w	#INTF_SETCLR+INTF_INTEN,INTENA(a4)
		and.w	d2,d4
		bne	StartSBreak
		ori.w	#INTF_SETCLR,d2
		move.w	d2,INTENA(a4)
		rts

StartSUpdaReg
		move.w	ch_SamPerNew(a0),ch_SamPerOld(a0)
		move.w	ch_SamLenNew(a0),ch_SamLenOld(a0)
		move.l	ch_SyncLenNew(a0),d4
		lsr.l	#1,d4
		move.l	d4,ch_SyncLenOld(a0)
		move.b	ch_WaveNew(a0),ch_WaveOld(a0)
		move.b	ch_SyncIndNew(a0),ch_SyncIndOld(a0)
		move.l	ch_SamAdrNew(a0),ch_SamAdrOld(a0)
		rts

StartSSync
		move.b	ch_WaveNew(a0),d4
		cmp.b	ch_WaveOld(a0),d4
		bne	.1
		move.w	ch_SamLenNew(a0),d4
		cmp.w	ch_SamLenOld(a0),d4
		bne	.1
		cmp.b	#CAI_SYNC,ch_AudIRQType(a0)
		bne	.1
		bsr	StartSUpdaReg
		move.w	ch_SamPerNew(a0),ac_per(a2)
		rts
.1
		move.w	d2,INTENA(a4)
		move.w	d3,DMACON(a4)
		move.w	d2,INTREQ(a4)
		clr.w	ac_dat(a2)
		move.w	#$0001,ac_per(a2)
		bsr	StartSUpdaReg
		move.l	ch_SamLenOld(a0),d4
		clr.w	d4
		lsr.l	#1,d4
		move.l	d4,ch_SamLenDec(a0)
		move.l	ch_SyncLenOld(a0),ch_SamIndStop(a0)
		move.b	#CAI_SYNC,ch_AudIRQType(a0)		;Sync IRQ
		bsr	SetChanProg
		ori.w	#INTF_SETCLR,d2
		move.w	d2,INTENA(a4)
		rts

StartSRing
		move.b	ch_WaveNew(a0),d4
		cmp.b	ch_WaveOld(a0),d4
		bne	.1
		move.w	ch_SamLenNew(a0),d4
		cmp.w	ch_SamLenOld(a0),d4
		bne	.1
		cmp.b	#CAI_RING,ch_AudIRQType(a0)
		bne	.1
		bsr	StartSUpdaReg
		move.w	ch_SamPerNew(a0),ac_per(a2)
		rts
.1
		move.w	d2,INTENA(a4)
		move.w	d3,DMACON(a4)
		move.w	d2,INTREQ(a4)
		clr.w	ac_dat(a2)
		move.w	#$0001,ac_per(a2)
		bsr	StartSUpdaReg
		move.l	ch_SamLenOld(a0),d4
		clr.w	d4
		lsr.l	#1,d4
		move.l	d4,ch_SamLenDec(a0)
		lsr.l	#1,d4
		move.l	d4,ch_SamLenHDec(a0)
		clr.l	ch_SamIndStart(a0)
		move.l	ch_SyncLenOld(a0),ch_SamIndStop(a0)
		move.b	#CAI_RING,ch_AudIRQType(a0)		;Ring IRQ
		bsr	SetChanProg
		ori.w	#INTF_SETCLR,d2
		move.w	d2,INTENA(a4)
		rts

StartSRSync
		move.b	ch_WaveNew(a0),d4
		cmp.b	ch_WaveOld(a0),d4
		bne	.1
		move.w	ch_SamLenNew(a0),d4
		cmp.w	ch_SamLenOld(a0),d4
		bne	.1
		cmp.b	#CAI_RINGSYNC,ch_AudIRQType(a0)
		bne	.1
		bsr	StartSUpdaReg
		move.w	ch_SamPerNew(a0),ac_per(a2)
		rts
.1
		move.w	d2,INTENA(a4)
		move.w	d3,DMACON(a4)
		move.w	d2,INTREQ(a4)
		clr.w	ac_dat(a2)
		move.w	#$0001,ac_per(a2)
		bsr	StartSUpdaReg
		move.l	ch_SamLenOld(a0),d4
		clr.w	d4
		lsr.l	#1,d4
		move.l	d4,ch_SamLenDec(a0)
		lsr.l	#1,d4
		move.l	d4,ch_SamLenHDec(a0)
		clr.b	ch_RSyncToggle(a0)
		clr.l	ch_SamIndStart(a0)
		move.l	ch_SyncLenOld(a0),ch_SamIndStop(a0)
		move.b	#CAI_RINGSYNC,ch_AudIRQType(a0)	;Ring Sync IRQ
		bsr	SetChanProg
		ori.w	#INTF_SETCLR,d2
		move.w	d2,INTENA(a4)
		rts

SetChanProg
		moveq	#$00,d0
		move.b	ch_AudIRQType(a0),d0
		add.w	d0,d0
		add.w	d0,d0
		move.l	0(a1,d0.w),ch_ProgPointer(a0)
		rts

*-----------------------------------------------------------------------*

SetCh4Vol: 
    move.l  d0,-(sp)
    move.w  ch4_SamVolMultiplier(a1),d0

    cmp.w   #$40,d0
    beq.b   .1

    mulu.w  ch4_SamVol(a1),d0
    lsr.w   #6,d0
    
    * Main volume
    mulu.w  psb_Volume(a6),d0
    lsr.w   #6,d0
    move.w  d0,AUD3VOL(a0)
    move.l  (sp)+,d0
    rts

.1
    * Main volume
    move.w  ch4_SamVol(a1),d0
    mulu.w  psb_Volume(a6),d0
    lsr.w   #6,d0
    move.w  d0,AUD3VOL(a0)
    move.l  (sp)+,d0
    rts

CreateFour
		move.l	psb_Chan4(a6),a1
		lea	psb_ChannelEnable(a6),a0
		tst.w	6(a0)
		beq	StopFourHuels
		cmp.b	#CC_START,ext_Control(a5)
		beq	CreateFourHuels
		cmp.b	#CC_STARTHALF,ext_Control(a5)
		beq	CreateFourHuels
		cmp.b	#CC_STARTQUART,ext_Control(a5)
		beq	CreateFourHuels
		cmp.b	#CC_STOP,ext_Control(a5)
		beq	StopFourHuels
		tst.b	ext_Counter(a5)
		bne.s	CreateFourGalway
		rts

CreateFourGalway
		tst.b	ch4_Active(a1)			;Four Active
		beq.s	.1
		rts
.1
		move.b	ext_Counter(a5),ch4_Counter(a1)	;Four Counter
		move.w	#INTF_AUD3,INTENA(a4)
		move.w	#DMAF_AUD3,DMACON(a4)
		move.w	#$0001,AUD3PER(a4)
		move.w	#$0000,AUD3VOL(a4)	;Null Volume
		clr.b	ext_Counter(a5)
		moveq	#$00,d0
		move.b	ext_AdrHigh(a5),d0
		lsl.w	#8,d0
		move.b	ext_AdrLow(a5),d0
		tst.w	d0
		beq	.3
		move.l	psb_C64Mem(a6),a0
		add.l	d0,a0
		move.l	a0,ch4_Adress(a1)		;Four Address
		moveq	#$00,d0
		move.b	ext_Period(a5),d0
		beq	.3
		mulu	psb_ConvFourConst(a6),d0
		divu	#8192,d0
		move.w	d0,ch4_LoopWait(a1)		;Four LoopWait
		moveq	#$00,d0
		move.b	ext_PeriodNull(a5),d0
		beq	.3
		mulu	psb_ConvFourConst(a6),d0
		divu	#8192,d0
		move.w	d0,ch4_NullWait(a1)		;Four Nullwait
		moveq	#$00,d0
		move.b	ext_Volume(a5),d0
		beq	.3
		mulu	#$0040,d0
		move.l	psb_SIDSampleFour(a6),a0
		add.w	d0,a0
		moveq	#$00,d0
		move.b	ext_ToneLen(a5),d0
		beq	.3
		addq.w	#1,d0
		lsr.w	#1,d0
		move.l	a0,ch4_SamAdr(a1)
		move.w	d0,ch4_SamLen(a1)
		st.b	ch4_Active(a1)			;Four Active
		lea	GalwayFourStart,a0
		move.l	a0,ch4_ProgPointer(a1)
		move.b	ch4_Mode(a1),d0
		move.b	#FM_GALWAYON,ch4_Mode(a1)	;Four Mode= Galway on
		move.b	#$08,ch4_AverageVol(a1)	;Average Volume = 8
		move.w	#$40,ch4_SamVol(a1)
		cmp.b	#FM_NONE,d0
		beq.s	.2
		move.w	#INTF_SETCLR+INTF_AUD3,INTENA(a4)	;Enable IRQ
		rts
.2
		move.w	#INTF_SETCLR+INTF_AUD3,INTENA(a4)
		move.w	#INTF_SETCLR+INTF_AUD3,INTREQ(a4)
.3		rts

StopFourHuels
		move.w	#INTF_AUD3,INTENA(a4)
		move.w	#DMAF_AUD3,DMACON(a4)
		move.w	#$0001,AUD3PER(a4)
		move.w	#$0000,AUD3VOL(a4)	;Null Volume
		clr.b	ch4_Active(a1)		;Four Not Active
		clr.b	ext_Control(a5)
		rts

CreateFourHuels
		tst.b	ch4_Active(a1)
		beq.s	.1
		cmp.b	#FM_GALWAYON,ch4_Mode(a1)
		bne.s	.1
		rts
.1		move.w	#INTF_AUD3,INTENA(a4)
		move.w	#DMAF_AUD3,DMACON(a4)
		move.w	#$0001,AUD3PER(a4)
		move.w	#$0000,AUD3VOL(a4)	;Null Volume
		st.b	ch4_Active(a1)		;Four Active
		move.b	ext_Control(a5),d4
		clr.b	ext_Control(a5)
		move.b	ext_AdrHigh(a5),d0		;Sample Start
		lsl.w	#8,d0
		move.b	ext_AdrLow(a5),d0
		move.b	ext_EndAdrHigh(a5),d1		;Sample End
		lsl.w	#8,d1
		move.b	ext_EndAdrLow(a5),d1
		cmp.w	d0,d1
		bls	.5
		move.b	ext_Octave(a5),d2	;Octav
		move.b	ext_SamOrder(a5),d3	;Mode
		bsr	GetFourSample
		tst.l	d0
		beq	.5			;Out of Memory ?
		move.l	d0,d5
		move.l	d1,d6
		moveq	#$00,d2
		moveq	#$00,d3
		move.b	ext_RepAdrHigh(a5),d2
		lsl.w	#8,d2
		move.b	ext_RepAdrLow(a5),d2
		move.b	ext_AdrHigh(a5),d3
		lsl.w	#8,d3
		move.b	ext_AdrLow(a5),d3
		tst.w	d3
		beq.s	.1b
		sub.l	d3,d2
		bmi.s	.1b
		add.l	d2,d2
		moveq	#$00,d3
		move.b	ext_Octave(a5),d3
		beq.s	.1a
		add.w	d3,d3
		divu	d3,d2
.1a		add.l	d2,d5
		lsr.w	#1,d2
		sub.w	d2,d6
.1b		move.l	d5,ch4_SamRepAdr(a1)
		move.w	d6,ch4_SamRepLen(a1)
		move.b	ext_PeriodHigh(a5),d2		;Period
		lsl.w	#8,d2
		move.b	ext_PeriodLow(a5),d2
		mulu	psb_ConvFourConst(a6),d2
		divu	#8192,d2
		tst.w	d2
		beq	.5
		bmi	.5
		swap	d1
		move.w	d2,d1
		move.b	ext_Repeat(a5),ch4_Repeat(a1)	;Repeat
		move.l	d0,ch4_SamAdr(a1)		;Sample
		move.l	d1,ch4_SamLen(a1)		;Length & Period
		lea	HuelsFourStart,a0
		move.l	a0,ch4_ProgPointer(a1)
		move.w	#$40,ch4_SamVol(a1)
		cmp.b	#CC_START,d4
		beq	.2
		move.w	#$20,ch4_SamVol(a1)
		cmp.b	#CC_STARTHALF,d4
		beq	.2
		move.w	#$10,ch4_SamVol(a1)
		cmp.b	#CC_STARTQUART,d4
		beq	.2
		nop
.2		move.b	ch4_Mode(a1),d0
		move.b	#FM_HUELSON,ch4_Mode(a1)		;Four Mode=Huels on
		cmp.b	#FM_HUELSON,d0
		beq.s	.3
		cmp.b	#FM_NONE,d0
		beq.s	.4
		move.w	#INTF_SETCLR+INTF_AUD3,INTENA(a4)	;Enable IRQ
		rts

.3		move.w	#INTF_SETCLR+INTF_AUD3,INTENA(a4)
		rts

.4		move.w	#INTF_SETCLR+INTF_AUD3,INTENA(a4)
		move.w	#INTF_SETCLR+INTF_AUD3,INTREQ(a4)
		rts

.5		clr.b	ch4_Active(a1)			;Not Active
		rts				;Out of Memory


GetFourSample	;D0=Start,D1=End,D2=Octav,D3=Mode
		movem.l		d2-d3/a0,-(a7)
		lea		psb_FourMemList(a6),a0
.1		tst.l		(a0)
		beq		.2
		move.l		fml_Next(a0),a0
		cmp.w		fml_Adr(a0),d0
		bne.s		.1
		cmp.w		fml_EndAdr(a0),d1
		bne.s		.1
		cmp.b		fml_Octave(a0),d2
		bne.s		.1
		cmp.b		fml_SamOrder(a0),d3
		bne.s		.1
		move.w		fml_Len(a0),d1
		move.b		fml_AverageVol(a0),d2
		lea		fml_Sample(a0),a0
		move.l		a0,d0
		lea		Chan4,a0
		move.b		d2,ch4_AverageVol(a0)
		movem.l		(a7)+,d2-d3/a0
		rts
.2		andi.l		#$0000ffff,d0
		andi.l		#$0000ffff,d1
		andi.l		#$000000ff,d2
		andi.l		#$000000ff,d3
		movem.l		d4-d7/a1-a6,-(a7)
		movem.l		d0-d3,-(a7)
		sub.w		d0,d1
		add.w		d1,d1
		tst.b		d2
		beq.s		.3
		add.w		d2,d2
		divu		d2,d1
.3		move.l		d1,d0
		move.l		d1,d4
		lsr.w		#1,d4
		addq.l		#8,d0
		addq.l		#2,d0
		bsr		AllocFourMem
		move.l		d0,d5
		move.l		d0,a0
		movem.l		(a7)+,d0-d3
		tst.l		d5
		beq		.10
		move.w		d0,(a0)+
		move.w		d1,(a0)+
		move.b		d2,(a0)+
		move.b		d3,(a0)+
		move.w		d4,(a0)+
		addq.l		#2,a0
		moveq		#$00,d5
		move.l		psb_C64Mem(a6),a1
		move.l		a1,a2
		add.l		d0,a1
		add.l		d1,a2
		moveq		#$00,d0
		moveq		#$00,d1
		move.l		a6,-(a7)
		move.l		psb_SIDSampleFConv(a6),a4	;Low byte
		lea		$0100(a4),a5		;High byte
		lea		$0200(a4),a6		;Sum Low+High

		move.l		a0,a3
		tst.b		d2
		bne.s		.6
		cmp.b		#SO_HIGHLOW,d3
		beq.s		.5
.4		move.b		(a1)+,d0
		move.b		0(a4,d0.w),(a3)+	;Low
		move.b		0(a5,d0.w),(a3)+	;High
		move.b		0(a6,d0.w),d0		;Sum
		add.l		d0,d5
		cmp.l		a1,a2
		bhi.s		.4
		bra		.9

.5		move.b		(a1)+,d0
		move.b		0(a5,d0.w),(a3)+	;High
		move.b		0(a4,d0.w),(a3)+	;Low
		move.b		0(a6,d0.w),d0		;Sum
		add.l		d0,d5
		cmp.l		a1,a2
		bhi.s		.5
		bra		.9

.6		cmp.b		#SO_HIGHLOW,d3
		beq.s		.8
.7		move.b		(a1),d0
		move.b		0(a4,d0.w),(a3)+	;Low
		andi.b		#$0f,d0
		add.l		d0,d5
		add.l		d2,a1
		cmp.l		a1,a2
		bhi.s		.7
		bra		.9

.8		move.b		(a1),d0
		move.b		0(a5,d0.w),(a3)+	;High
		lsr.b		#4,d0
		add.l		d0,d5
		add.l		d2,a1
		cmp.l		a1,a2
		bhi.s		.8

.9		move.w		-4(a0),d1
		lsr.l		#1,d5
		move.w		d1,d0
		lsr.w		#1,d0
		add.l		d0,d5
		divu		d1,d5
		move.b		d5,-2(a0)		;Average Volume
		move.l		(a7)+,a6
		move.l		psb_Chan4(a6),a1
		move.b		d5,ch4_AverageVol(a1)
.10		move.l		a0,d0
		movem.l		(a7)+,d4-d7/a1-a6
		movem.l		(a7)+,d2-d3/a0
		rts

AllocFourMem	;D0=Length, Result:D0=Address or 0!
		movem.l		d1/a0-a1,-(a7)
		addq.l		#3,d0
		andi.l		#$fffffffc,d0
		addq.l		#8,d0
		move.l		d0,-(a7)
		move.l		#MEMF_PUBLIC+MEMF_CHIP,d1
		move.l		a6,-(a7)
		CALLEXEC	AllocMem
		move.l		(a7)+,a6
		move.l		(a7)+,d1
		tst.l		d0
		beq.s		.3			;Out of Memory
		lea		psb_FourMemList(a6),a0
.1		tst.l		(a0)
		beq.s		.2
		move.l		(a0),a0
		bra.s		.1
.2		addq.l		#4,d0
		move.l		d0,(a0)
		move.l		d0,a0
		clr.l		(a0)
		move.l		d1,-(a0)
		addq.l		#4,d0
.3		movem.l		(a7)+,d1/a0-a1
		rts

FreeFourMem
		lea		psb_FourMemList(a6),a0
		move.l		(a0),d0
		clr.l		(a0)
.1		tst.l		d0
		beq.s		.2
		move.l		d0,a1
		move.l		(a1),-(a7)
		move.l		-(a1),d0
		move.l		a6,-(a7)
		CALLEXEC	FreeMem
		move.l		(a7)+,a6
		move.l		(a7)+,d0
		bra.s		.1
.2		rts

*-----------------------------------------------------------------------*
CreateSample		;A0=Channeldata,A1=Sampledata,A2=SyncChanneldata
			;D0=ControlReg,D1=PulseWidth,D2=PulseOffset
		movem.l	d2-d7/a2-a6,-(a7)
		move.w	d2,psb_PulseOffset(a6)
		clr.b	ch_SyncIndNew(a0)	;Clear Sync or Ring ind.
		andi.b	#$fe,d0
		move.b	d0,ch_WaveNew(a0)	;New Waveform
		move.w	ch_SamLen(a0),d2	;Sample Length
		move.w	d2,ch_SamLenNew(a0)
		move.w	ch_SamPer(a0),d3
		move.w	d3,ch_SamPerNew(a0)
		cmp.w	#$0400,d3
		bhi	CreateSClear		;Freq 0 - No Waveform
		btst	#3,d0
		bne	CreateSClear		;Test Bit - No Waveform
		move.b	d0,d3
		andi.b	#$f0,d3
		beq	CreateSClear		;No Waveform
		bmi	CreateSNoise		;Noise
		btst	#4,d0
		beq	.1			;Not Triangle
		btst	#2,d0
		beq	.1			;Not Ring Modulation
		btst	#1,d0
		bne	CreateSRSync		;And Synchronize
		bra	CreateSRing

.1		btst	#1,d0
		bne	CreateSSync		;Synchronize
		bra	CreateSNormal

CreateSNoise					;Noise Creation
		move.w	psb_LastNoise(a6),d1
		move.l	psb_SIDSampleNoise(a6),a5
		andi.w	#$3fff,d1
		cmp.w	#$3f00,d1
		bls.s	.0
		subi.w	#$3f00,d1
.0		add.w	d1,a5
		move.w	#$0100,ch_SamLenNew(a0)	;Sample length=$100
		lea	$100(a1),a4
		move.l	a1,a3
		swap	d2
		clr.w	d2
		lsr.l	#4,d2
		move.l	d2,d4
		swap	d2
		tst.w	d2
		beq.s	.7
		tst.w	d4
		beq.s	.3
		moveq	#$00,d5
.1		moveq	#-1,d3
		add.w	d4,d5
		addx.w	d2,d3
		move.b	(a5)+,d0
.2		move.b	d0,(a3)+
		dbf	d3,.2
		cmpa.l	a3,a4
		bhi.s	.1
		move.l	a3,d0
		sub.l	a4,d0
		add.w	d0,$32(a0)
		bra.s	.6
.3		subq.w	#1,d2
		beq.s	.7
.4		move.w	d2,d3
		move.b	(a5)+,d0
.5		move.b	d0,(a3)+
		dbf	d3,.5
		cmpa.l	a3,a4
		bhi.s	.4
		move.l	a3,d0
		sub.l	a4,d0
		add.w	d0,$32(a0)
.6		move.l	a5,d0
		sub.l	psb_SIDSampleNoise(a6),d0
		add.w	d0,psb_LastNoise(a6)
		bra	CreateSExit
.7		move.l	a5,a1
		addi.w	#$0100,psb_LastNoise(a6)
		bra	CreateSExit

CreateSNormal					;Get Pulse,Saw or Tri
		bsr	GetWaveform
		move.l	d0,a1
		bra	CreateSExit

CreateSRSync
		move.w	d2,d7
		tst.w	ch_Freq64New(a2)
		beq.s	CreateSNormal
		mulu	ch_Freq64New(a0),d7
		lsr.l	#1,d7
		divu	ch_Freq64New(a2),d7
		beq	.10
		move.l	d7,d6
		clr.w	d6
		divu	ch_Freq64New(a2),d6
		swap	d7
		move.w	d6,d7
		move.l	d7,ch_SyncLenNew(a0)
		bsr	GetWaveform
		lea	$0200(a1),a5
		move.l	a1,a3
		move.l	d0,a1
		cmp.l	a1,a3
		bne	.2
		add.w	d2,a3			;Must make wave two
		move.l	a1,a4
		move.w	d2,d0
		addq.w	#2,d0
		lsr.w	#2,d0
		subq.w	#1,d0
.1		move.l	(a4)+,(a3)+
		dbf	d0,.1
.2		cmp.l	#$000bffff,d7
		bls	.3
		move.b	#$03,ch_SyncIndNew(a0)		;Start Ring Sync IRQ
		bra	CreateSExit
.3		cmp.w	#$000c,d2
		bhi	.5
		lea	-$200(a5),a3
		moveq	#$03,d0
		move.w	d2,d1
		lsr.w	#1,d1
		subq.w	#1,d1
		move.w	d1,d3
		move.l	a1,a4
.4		move.w	(a4)+,(a3)+
		dbf	d1,.4
		move.w	d3,d1
		move.l	a1,a4
		dbf	d0,.4
		lea	-$200(a5),a1
.5		move.l	a5,a3
		lea	$100(a5),a6
		move.l	a1,a4
		swap	d2
		clr.w	d2
		move.l	d2,d3
		lsr.l	#1,d3
		move.l	d3,d4
		swap	d4
		moveq	#$00,d5
		moveq	#$00,d6
		move.w	#$aaaa,d0
.6		add.l	d7,d6
		move.l	d6,d1
		sub.l	d5,d1
		clr.w	d1
		add.l	d1,d5
		swap	d1
		subq.w	#1,d1
.7		move.b	(a4)+,(a3)+
		dbf	d1,.7
		add.l	d3,d5
		add.l	d3,d6
		add.w	d4,a4
.8		cmp.l	d5,d2
		bhi	.9
		sub.l	d2,d5
		sub.l	d2,d6
		sub.w	d4,a4
		sub.w	d4,a4
		bra	.8
.9		ror.w	#1,d0
		bcc	.6
		move.l	a1,a4
		clr.l	d5
		andi.l	#$0000ffff,d6
		cmp.l	a3,a6
		bhi	.6
		move.l	a5,a1
		move.l	a3,d1
		sub.l	a5,d1
		move.w	d1,ch_SamLenNew(a0)
		bra	CreateSExit
.10
		move.w	ch_SamPer(a2),ch_SamPerNew(a0)
		move.w	ch_SamLen(a2),d2
		move.w	d2,ch_SamLenNew(a0)
		bra	CreateSNormal

CreateSRing					;Ring Modulation with Triangle
		move.w	d2,d7
		tst.w	ch_Freq64New(a2)
		beq	CreateSNormal
		mulu	ch_Freq64New(a0),d7
		lsr.l	#1,d7
		divu	ch_Freq64New(a2),d7
		beq	.10
		move.l	d7,d6
		clr.w	d6
		divu	ch_Freq64New(a2),d6
		swap	d7
		move.w	d6,d7
		move.l	d7,ch_SyncLenNew(a0)
		bsr	GetWaveform
		lea	$0200(a1),a5
		move.l	a1,a3
		move.l	d0,a1
		cmp.l	a1,a3
		bne	.2
		add.w	d2,a3			;Must make wave two
		move.l	a1,a4
		move.w	d2,d0
		addq.w	#2,d0
		lsr.w	#2,d0
		subq.w	#1,d0
.1		move.l	(a4)+,(a3)+
		dbf	d0,.1
.2		cmp.l	#$000bffff,d7
		bls	.3
		move.b	#$02,ch_SyncIndNew(a0)		;Start Ring IRQ
		bra	CreateSExit
.3
		cmp.w	#$000c,d2
		bhi	.5
		lea	-$200(a5),a3
		moveq	#$03,d0
		move.w	d2,d1
		lsr.w	#1,d1
		subq.w	#1,d1
		move.w	d1,d3
		move.l	a1,a4
.4		move.w	(a4)+,(a3)+
		dbf	d1,.4
		move.w	d3,d1
		move.l	a1,a4
		dbf	d0,.4
		lea	-$200(a5),a1
.5		move.l	a5,a3
		move.l	a6,-(a7)
		lea	$100(a5),a6
		move.l	a1,a4
		swap	d2
		clr.w	d2
		move.l	d2,d3
		lsr.l	#1,d3
		move.l	d3,d4
		swap	d4
		moveq	#$00,d5
		moveq	#$00,d6
.6		add.l	d7,d6
		move.l	d6,d1
		sub.l	d5,d1
		clr.w	d1
		add.l	d1,d5
		swap	d1
		subq.w	#1,d1
.7		move.b	(a4)+,(a3)+
		dbf	d1,.7
		add.l	d3,d5
		add.l	d3,d6
		add.w	d4,a4
.8		cmp.l	d5,d2
		bhi	.9
		sub.l	d2,d5
		sub.l	d2,d6
		sub.w	d4,a4
		sub.w	d4,a4
		bra	.8
.9		cmp.l	a3,a6
		bhi	.6
		move.l	(a7)+,a6
		move.l	a5,a1
		move.l	a3,d1
		sub.l	a5,d1
		move.w	d1,ch_SamLenNew(a0)
		bra	CreateSExit
.10
		move.w	ch_SamPer(a2),ch_SamPerNew(a0)
		move.w	ch_SamLen(a2),d2
		move.w	d2,ch_SamLenNew(a0)
		bra	CreateSNormal

CreateSSync					;Synchronize
		move.w	d2,d7
		tst.w	ch_Freq64New(a2)
		beq	CreateSNormal
		mulu	ch_Freq64New(a0),d7
		divu	ch_Freq64New(a2),d7
		beq	.6
		move.l	d7,d6
		clr.w	d6
		divu	ch_Freq64New(a2),d6
		swap	d7
		move.w	d6,d7
		move.l	d7,ch_SyncLenNew(a0)
		bsr	GetWaveform
		lea	$0200(a1),a5
		move.l	a1,a3
		move.l	d0,a1
		cmp.l	#$000bffff,d7
		bls	.1
		move.b	#$01,ch_SyncIndNew(a0)		;Start Sync IRQ
		bra	CreateSExit
.1
		cmp.w	#$000c,d2
		bhi	.3
		lea	-$200(a5),a3
		moveq	#$02,d0
		move.w	d2,d1
		lsr.w	#1,d1
		subq.w	#1,d1
		move.w	d1,d3
		move.l	a1,a4
.2		move.w	(a4)+,(a3)+
		dbf	d1,.2
		move.w	d3,d1
		move.l	a1,a4
		dbf	d0,.2
		lea	-$200(a5),a1
.3		move.l	a5,a3
		move.l	a6,-(a7)
		lea	$100(a5),a6
		moveq	#$00,d6
.4		andi.l	#$0000ffff,d6
		add.l	d7,d6
		move.l	d6,d1
		swap	d1
		subq.w	#1,d1
		move.l	a1,a4
.5		move.b	(a4)+,(a3)+
		dbf	d1,.5
		cmp.l	a3,a6
		bhi	.4
		move.l	(a7)+,a6
		move.l	a5,a1
		move.l	a3,d1
		sub.l	a5,d1
		move.w	d1,ch_SamLenNew(a0)
		bra	CreateSExit
.6
		move.w	ch_SamPer(a2),ch_SamPerNew(a0)
		move.w	ch_SamLen(a2),d2
		move.w	d2,ch_SamLenNew(a0)
		bra	CreateSNormal

CreateSClear					;No - Waveform
		clr.l	(a1)
		clr.l	4(a1)
		clr.l	8(a1)
		clr.l	12(a1)
		move.w	#$0010,ch_SamLenNew(a0)	;Lengh = 16
		move.w	#$0080,ch_SamPerNew(a0)	;Period = 128

CreateSExit					;Exit
		move.l	a1,ch_SamAdrNew(a0)	;Sample Adress
		movem.l	(a7)+,d2-d7/a2-a6
		rts

GetWaveform
		move.b	d0,d3
		andi.b	#$f0,d3
		cmp.b	#$70,d3
		beq	GetPulSawTriWave
		cmp.b	#$60,d3
		beq	GetPulSawWave
		cmp.b	#$50,d3
		beq	GetPulTriWave
		cmp.b	#$40,d3
		beq.s	GetPulWave
		cmp.b	#$30,d3
		beq	GetTriSawWave
		cmp.b	#$20,d3
		beq.s	GetSawWave
		cmp.b	#$10,d3
		beq	GetTriWave
		bra	GetTriWave

GetTriWave	move.l	psb_SIDSampleTri(a6),a3
		bra	GetWaveSample

GetSawWave	move.l	psb_SIDSampleSaw(a6),a3
		bra	GetWaveSample

GetTriSawWave	move.l	psb_SIDSampleTSaw(a6),a3
		bra	GetWaveSample

GetPulWave	move.l	psb_SIDSamplePulse(a6),a3
		add.w	psb_PulseOffset(a6),a3
		andi.w	#$0fff,d1		;Pulsewidth
		mulu	d2,d1
		divu	#$0fff,d1
		move.l	d1,d0
		swap	d0
		lsr.w	#4,d0
		not.b	d0
		addi.b	#$80,d0
		btst	#0,d1
		beq.s	.1
		lea	$0300(a3),a3
		move.b	d0,1(a3)
		bra.s	.2
.1		lea	$0100(a3),a3
		move.b	d0,(a3)
.2		andi.w	#$fffe,d1
		sub.w	d1,a3
		move.l	a3,d0
		rts
	
GetPulTriWave	move.l	psb_SIDSampleTPul(a6),a3
		bsr	GetWaveSample		;Get 2nd AND Waveform
		bra	GetAndPulWave

GetPulSawWave
		move.l	psb_SIDSampleSaw(a6),a3
		bsr	GetWaveSample
		bra	GetAndPulWave

GetPulSawTriWave
		move.l	psb_SIDSampleTSaw(a6),a3
		bsr	GetWaveSample
		bra	GetAndPulWave

GetWaveSample	lea	MakeSIDSData2,a5
		move.w	(a5)+,d3
.1		cmp.w	d3,d2
		beq.s	.2
		add.w	d3,a3
		add.w	d3,a3
		move.w	(a5)+,d3
		bne.s	.1
.2		move.l	a3,d0
		rts

GetAndPulWave	move.l	a1,a4
		andi.w	#$0fff,d1		;Pulsewidth
		mulu	d2,d1
		divu	#$0fff,d1
		add.w	d1,a3
		move.w	d1,d3
		lsr.w	#2,d3
		moveq	#$00,d0
		subq.w	#1,d3
		bmi.s	.2
.1		move.l	d0,(a4)+
		dbf	d3,.1
.2		move.w	d1,d3
		andi.w	#$0003,d3
		subq.w	#1,d3
		bmi.s	.4
.3		move.b	d0,(a4)+
		dbf	d3,.3
.4		move.w	d2,d3
		sub.w	d1,d3
		beq.s	.8
		move.w	d3,d4
		andi.w	#$0003,d3
		subq.w	#1,d3
		bmi.s	.6
.5		move.b	(a3)+,(a4)+
		dbf	d3,.5
.6		lsr.w	#2,d4
		subq.w	#1,d4
		bmi.s	.8
.7		move.l	(a3)+,(a4)+
		dbf	d4,.7
.8
		move.l	a1,d0
		rts

*-----------------------------------------------------------------------*
SelectVolume
		move.l	psb_C64Mem(a6),a5
		add.l	#$0000D400,a5
		move.b	sid_Volume(a5),d0
		andi.w	#$000f,d0
		add.w	d0,d0
		add.w	d0,d0
		move.l	psb_VolumePointers(a6,d0.w),psb_VolumePointer(a6)
		rts

*-----------------------------------------------------------------------*
MakeVolume
		move.l	d2,-(a7)
		lea	psb_VolumePointers(a6),a0
		move.l	psb_VolumeTable(a6),a1
		moveq	#$00,d0
.1
		move.l	a1,(a0)+
		moveq	#$00,d1
.2
		moveq	#$00,d2
		move.b	d1,d2
		mulu	#$0040,d2
		mulu	d0,d2
		addi.l	#1912,d2
		divu	#3825,d2
		move.b	d2,(a1)+
		addq.b	#1,d1
		bne.s	.2
		addq.w	#1,d0
		cmp.w	#$0010,d0
		bne.s	.1
		move.l	(a7)+,d2
		rts

*-----------------------------------------------------------------------*
MakeEnvelope	movem.l	d2-d7/a2-a6,-(a7)
		move.l	psb_EnvelopeMem(a6),a0
		moveq	#$00,d0
		moveq	#$00,d1
		move.w	#15,d2			;Attack
		move.w	#44976,d3
		moveq	#1,d5
		bsr	.CalcNextAddr
		bsr	.Fill
		moveq	#2,d5
.Attack		addq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$fe,d0
		bne.s	.Attack
		moveq	#1,d5
		move.b	#$ff,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		move.w	#15,d2			;Decay/Release
		move.w	#37638,d3
		bsr	.CalcNextAddr
		bsr	.Fill
		moveq	#2,d5
.Decay		subq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$5e,d0
		bne	.Decay
		moveq	#4,d5
.Decay1		subq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$37,d0
		bne	.Decay1
		moveq	#8,d5
.Decay2		subq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$1b,d0
		bne	.Decay2
		moveq	#16,d5
.Decay3		subq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$0f,d0
		bne	.Decay3
		moveq	#32,d5
.Decay4		subq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$07,d0
		bne	.Decay4
		moveq	#60,d5
.Decay5		subq.b	#1,d0
		bsr	.CalcNextAddr
		bsr	.Fill
		cmp.b	#$01,d0
		bne	.Decay5
		move.l	psb_EnvelopeMem(a6),a1
		add.l	#32004,a1
		moveq	#$00,d0
		bsr	.Fill

		move.l	psb_EnvelopeMem(a6),a0
		move.l	psb_AttackTable(a6),a1
		moveq	#$00,d0
.1		cmp.b	(a0)+,d0
		bne.s	.1
		subq.l	#1,a0
		move.l	a0,d1
		sub.l	psb_EnvelopeMem(a6),d1
		move.w	d1,(a1)+
		addq.b	#1,d0
		bne.s	.1

		move.l	psb_EnvelopeMem(a6),a0
		add.l	#8000,a0
		move.l	psb_SustainTable(a6),a1
		add.l	#$20,a1
		move.w	#$00ff,d0
.2		cmp.b	(a0)+,d0
		bne.s	.2
		subq.l	#1,a0
		move.l	a0,d1
		sub.l	psb_EnvelopeMem(a6),d1
		move.w	d1,-(a1)
		subi.w	#$0011,d0
		bpl.s	.2

		move.l	psb_AttackDecay(a6),a0
		move.l	psb_AttDecRelStep(a6),a1
		moveq	#$00,d0
.3		move.w	d0,d1
		andi.w	#$00f0,d1
		lsr.w	#2,d1
		move.l	0(a1,d1.w),(a0)+
		move.w	d0,d1
		andi.w	#$000f,d1
		lsl.w	#2,d1
		move.l	0(a1,d1.w),(a0)+
		addq.b	#1,d0
		bne.s	.3

		move.l	psb_SustainRelease(a6),a0
		move.l	psb_AttDecRelStep(a6),a1
		move.l	psb_SustainTable(a6),a2
		moveq	#$00,d0
.4		move.w	d0,d1
		andi.w	#$00f0,d1
		lsr.w	#3,d1
		move.w	0(a2,d1.w),(a0)+
		addq.l	#2,a0
		move.w	d0,d1
		andi.w	#$000f,d1
		lsl.w	#2,d1
		move.l	0(a1,d1.w),(a0)+
		addq.b	#1,d0
		bne.s	.4

		movem.l	(a7)+,d2-d7/a2-a6
		rts

.Fill		move.b	d0,(a0)+
		cmp.l	a0,a1
		bne.s	.Fill
		rts

.CalcNextAddr	
		movem.l	d2/d4-d5,-(a7)
		moveq	#$00,d4
		subq.w	#1,d5
.CalcNextAddr1
		add.w	d3,d1
		addx.w	d2,d4
		dbf	d5,.CalcNextAddr1
		lea	0(a0,d4.w),a1
		movem.l	(a7)+,d2/d4-d5
		rts


*-----------------------------------------------------------------------*
Envelopes
		move.l	a1,a6
		move.w	d2,d1
		swap	d1
		move.l	psb_EnvelopeMem(a6),a5
		move.l	psb_VolumePointer(a6),a1
		move.l	psb_Enve1(a6),a0
		moveq	#$00,d0
		bsr	    .Calculate
        mulu.w  psb_Volume(a6),d0
        lsr     #6,d0
		move.w	d0,$dff0a8
		move.l	psb_Enve2(a6),a0
		bsr 	.Calculate
        mulu.w  psb_Volume(a6),d0
        lsr     #6,d0
		move.w	d0,$dff0b8
		move.l	psb_Enve3(a6),a0
		bsr.s	.Calculate
        mulu.w  psb_Volume(a6),d0
        lsr     #6,d0
		move.w	d0,$dff0c8
		swap	d1
		move.w	d1,d2
		moveq	#$00,d0
		rts

.Release
		cmp.w	#32000,d2
		bcs.s	.Set3
		move.w	#31999,d2
		move.w	d2,env_CurrentAddr(a0)
		clr.w	env_CurrentAddrDec(a0)
		move.w	#EM_QUIET,env_Mode(a0)	;Go To Quiet
		bra.s	.Quiet
.Set3
		move.w	env_ReleaseDec(a0),d1
		add.w	d1,env_CurrentAddrDec(a0)
		move.w	env_Release(a0),d1
		move.b	0(a5,d2.w),d0
		addx.w	d1,d2
		move.w	d2,env_CurrentAddr(a0)
		move.b	0(a1,d0.w),d0		;Master volume calc
		rts

.Sustain	add.w	d1,d1
		bpl.s	.Quiet
		cmp.w	env_Sustain(a0),d2	;Check sustain if changing
		bne.s	.SusDecay		;Then start decay again
		move.b	0(a5,d2.w),d0
		move.b	0(a1,d0.w),d0		;Master volume calc
		rts

.SusDecay	bls.s	.SusDecay2
		move.w	#32000,env_Sustain(a0)
.SusDecay2	move.w	#EM_DECAY,env_Mode(a0)
		bra	.Decay			;Go to decay
.Quiet
		moveq	#$00,d0
		rts
.Calculate
		move.w	env_CurrentAddr(a0),d2
		move.w	env_Mode(a0),d1
		beq.s	.Release
		bpl.s	.Sustain
		add.w	d1,d1
		bpl.s	.Decay
		cmp.w	#8000,d2
		bcs.s	.Set1
		move.w	#8000,d2
		clr.w	env_CurrentAddrDec(a0)
		move.w	#EM_DECAY,env_Mode(a0)
		bra.s	.Decay			;Go to decay
.Set1
		move.w	env_AttackDec(a0),d1
		add.w	d1,env_CurrentAddrDec(a0)
		move.w	env_Attack(a0),d1
		move.b	0(a5,d2.w),d0
		addx.w	d1,d2
		move.w	d2,env_CurrentAddr(a0)
		move.b	0(a1,d0.w),d0		;Master volume calc
		rts

.Decay
		cmp.w	env_Sustain(a0),d2
		bcs.s	.Set2
		move.w	env_Sustain(a0),d2
		move.w	d2,env_CurrentAddr(a0)
		clr.w	env_CurrentAddrDec(a0)
		move.w	#EM_SUSTAIN,env_Mode(a0)
		bra	.Sustain		;Go to Sustain
.Set2
		move.w	env_DecayDec(a0),d1
		add.w	d1,env_CurrentAddrDec(a0)
		move.w	env_Decay(a0),d1
		move.b	0(a5,d2.w),d0
		addx.w	d1,d2
		move.w	d2,env_CurrentAddr(a0)
		move.b	0(a1,d0.w),d0		;Master volume calc
		rts

DoEnvelope	movem.l	d2-d7/a2-a6,-(a7)
		move.l	psb_C64Mem(a6),a5
		move.l	psb_SustainRelease(a6),a4
		move.l	psb_AttackDecay(a6),a3
		move.l	#$D400,d7
		move.b	$20(a5,d7.l),d6
		move.b	#sid_Voice1Control,d7
		move.l	psb_Enve1(a6),a2
		bsr	.Do
		lsr.b	#1,d6
		move.b	#sid_Voice2Control,d7
		move.l	psb_Enve2(a6),a2
		bsr	.Do
		lsr.b	#1,d6
		move.b	#sid_Voice3Control,d7
		move.l	psb_Enve3(a6),a2
		bsr	.Do
		bsr	SelectVolume
		movem.l	(a7)+,d2-d7/a2-a6
		rts
.Do
		moveq	#$00,d0
		move.b	1(a5,d7.l),d0
		lsl.w	#3,d0
		move.l	0(a3,d0.w),env_Attack(a2)
		move.l	4(a3,d0.w),env_Decay(a2)
		moveq	#$00,d0
		move.b	2(a5,d7.l),d0
		lsl.w	#3,d0
		move.w	0(a4,d0.w),env_Sustain(a2)
		move.l	4(a4,d0.w),env_Release(a2)

		move.b	0(a5,d7.l),d0
		lsr.b	#1,d0
		bcs.s	.Do1			;Gate turned on ?
		clr.w	env_Mode(a2)		;Release
		rts

.Do1		btst	#0,d6
		beq.s	.Do2
		st	env_Mode(a2)			;Attack
.Do2		rts

*-----------------------------------------------------------------------*

*=======================================================================*
*	CPU 6502 EMULATION ROUTINES					*
*=======================================================================*

*************************************************************************
* REGISTER *
* D0=00000000 00000000 00000000 ---AC---
* D1=00000000 00000000 00000000 ---XR---
* D2=00000000 00000000 00000000 ---YR---
* D3=00000000 00000000 N0000000 NZZZZZZZ
* D4=00000000 00000000 D+000000 CCCCCCCC
* D5=00000000 00000000 001BDI00 VVVVVVVV
* D6=00000000 00000000 00000000 --Temp--
* D7=00000000 00000000 --Temp-- --Temp--
* A0=-------- -MEMORY- --BASE-- --------
* A1=-------- -STACK-- -POINTER --------
* A2=--Temp-- --Temp-- --Temp-- --Temp--
* A3=-MEMORY- -MANAGE- -MENT--- -TABLE--
* A4=-------- --EMUL-- --PROG-- --BASE--
* A5=-------- --STACK- -LIMIT-- --------
* A6=-------- PROGRAM- COUNTER- --------
* A7=--SUPER- --VISOR- -STACK-- -POINTER
*************************************************************************
* PROGRAM CAN BE RUN IN SUPERVISOR OR USER MODE                         *
*************************************************************************
Make6502Emulator
	movem.l	d0-d7/a0-a6,-(a7)
	lea	I00,a0
	move.l	psb_PrgMem(a6),a1
	add.l	#$8000,a1
	lea	InstTable1,a3
	moveq	#$00,d7
.1
	lea	0(a1,d7.w),a5
	move.w	(a3)+,d4
	lea	0(a0,d4.w),a4
	move.w	(a3),d4
	sub.w	-2(a3),d4
	bsr.s	.Make
	addi.w	#$0100,d7
	tst.w	d7
	bne.s	.1
	movem.l	(a7)+,d0-d7/a0-a6
	rts
.Make
	movem.l	a0-a6/d4-d7,-(a7)
	move.w	psb_CPUVersion(a6),d6		;ProcessorMode
	lea	$007e(a5),a6
	move.l	a6,a0
	move.l	#$00010000,a2
	moveq	#$00,d5			;StatusMode
	lea	.Next68000(pc),a3
	tst.w	d6		;ProcessorMode
	beq.s	.M1
	lea	.Next68020(pc),a3
.M1
	tst.w	d4
	bne.s	.M2
	movem.l	(a7)+,a0-a6/d4-d7
	rts
.M2
	move.w	(a4)+,d7
	subq.w	#2,d4
	cmp.w	#hunkStatus,d7
	beq.s	.M3
	cmp.w	#hunkDecAdd,d7
	beq.s	.M4
	cmp.w	#hunkDecSub,d7
	beq.s	.M5
	cmp.w	#hunkIfStat,d7
	beq.s	.M6
	cmp.w	#hunkNextInst,d7
	beq.s	.M7
	cmp.w	#$aff9,d7
	beq.w	.AFF9
	cmp.w	#$affa,d7
	beq.w	.AFFA
	bsr	.Write
	bra.s	.M1
.M3
	move.w	.Irq+4(pc),d7		;Set Status
	bsr	.Write2
	tst.b	d5
	beq.s	.M1
	move.l	a6,a5
	bra.s	.M1
.M4
	move.w	.DecAdd+2(pc),d7
	move.w	d7,0(a5,a2.l)
	move.w	d7,0(a6,a2.l)
	move.w	.DecAdd(pc),d7
	move.w	d7,(a5)+
	move.w	d7,(a6)+
	bra.s	.M1
.M5
	move.w	.DecSub+2(pc),d7
	move.w	d7,0(a5,a2.l)
	move.w	d7,0(a6,a2.l)
	move.w	.DecSub(pc),d7
	move.w	d7,(a5)+
	move.w	d7,(a6)+
	bra.s	.M1
.M6
	move.l	a0,a6
	move.l	a0,a5
	st	d5
	bra.w	.M1
.M7
	move.w	(a4)+,d7
	subq.w	#2,d4
	cmp.w	#hunkNextInst0,d7
	beq.s	.M8
	cmp.w	#hunkNextInst1,d7
	beq.s	.M9
	cmp.w	#hunkNextInst2,d7
	beq.s	.M10
	bra	.M1
.M8
	subq.w	#6,d4
	addq.l	#6,a4
	move.w	(a3),d7
	bsr	.Write
	move.w	2(a3),d7
	bsr	.Write
	move.w	4(a3),d7
	bsr	.Write
	move.w	6(a3),d7
	bsr	.Write
	move.w	8(a3),d7
	bsr	.Write
	bra.s	.M11
.M9
	subq.w	#6,d4
	addq.l	#6,a4
	move.w	10(a3),d7
	bsr.s	.Write
	move.w	12(a3),d7
	bsr.s	.Write
	move.w	14(a3),d7
	bsr.s	.Write
	move.w	16(a3),d7
	bsr.s	.Write
	move.w	18(a3),d7
	bsr.s	.Write
	bra.s	.M11
.M10
	subq.w	#6,d4
	addq.l	#6,a4
	move.w	(a3),d7
	bsr.s	.Write1
	move.w	2(a3),d7
	bsr.s	.Write1
	move.w	4(a3),d7
	bsr.s	.Write1
	move.w	6(a3),d7
	bsr.s	.Write1
	move.w	8(a3),d7
	bsr.s	.Write1
	move.w	10(a3),d7
	bsr.s	.Write2
	move.w	12(a3),d7
	bsr.s	.Write2
	move.w	14(a3),d7
	bsr.s	.Write2
	move.w	16(a3),d7
	bsr.s	.Write2
	move.w	18(a3),d7
	bsr.s	.Write2
.M11
	tst.w	d6
	bne	.M1
	move.l	a5,d7
	subq.l	#4,d7
	sub.l	a1,d7
	move.w	d7,-8(a5)
	move.w	d7,-8(a5,a2.l)
	move.l	a6,d7
	subq.l	#4,d7
	sub.l	a1,d7
	move.w	d7,-8(a6)
	move.w	d7,-8(a6,a2.l)
	bra	.M1
.Write
	move.w	d7,0(a5,a2.l)
	move.w	d7,0(a6,a2.l)
	move.w	d7,(a5)+
	move.w	d7,(a6)+
	rts
.Write1
	move.w	d7,0(a5,a2.l)
	move.w	d7,(a5)+
	rts
.Write2
	move.w	d7,0(a6,a2.l)
	move.w	d7,(a6)+
	rts

.AFF9	; indirect
	subq.w	#8,d4
	addq.l	#8,a4
	move.w	20(a3),d7
	bsr.w	.Write
	move.w	22(a3),d7
	bsr.w	.Write
	move.w	24(a3),d7
	bsr.w	.Write
	move.w	26(a3),d7
	bsr.w	.Write
	move.w	28(a3),d7
	bsr.w	.Write
	bra.w	.M1
.AFFA	; absolute
	subq.w	#6,d4
	addq.l	#6,a4
	move.w	30(a3),d7
	bsr.w	.Write
	move.w	32(a3),d7
	bsr.w	.Write
	move.w	34(a3),d7
	bsr.w	.Write
	move.w	36(a3),d7
	bsr.w	.Write
	bra.w	.M1

.Irq	rts
	nop
	move.w	d0,d3
	rts
.DecAdd	addx.b	d6,d0
	abcd.b	d6,d0
.DecSub	subx.b	d6,d0
	sbcd.b	d6,d0
.Next68000
	move.b	(a6)+,$0000(a4)
	jmp	$0000(a4)
	nop
	move.b	(a6)+,$0000(a4)
	jmp	$007E(a4)
	nop
	lea	0(a0,d6.l),a2
	movep.w	1(a2),d7
	move.b	(a2),d7
	movep.w	1(a6),d7
	move.b	(a6),d7
	addq.l	#2,a6
.Next68020
	move.b	(a6)+,-(a7)
	move.w	(a7)+,d7
	clr.b	d7
	jmp	0(a4,d7.w)
	move.b	(a6)+,-(a7)
	move.w	(a7)+,d7
	clr.b	d7
	jmp	$7E(a4,d7.w)
	move.b	1(a0,d6.l),d7
	lsl.w	#$8,d7
	move.b	0(a0,d6.l),d7
	move.b	(a6)+,d7
	ror.w	#$8,d7
	move.b	(a6)+,d7
	ror.w	#$8,d7

*-----------------------------------------------------------------------*
MakeMMUTable
	move.l	psb_MMUMem(a6),a1
	bsr 	.Make
    rts

.Make
	movem.l	a2-a3/d4-d7,-(a7)
	move.l	a1,a2				;0000-D400
	move.l	a2,a0				;RAM
	add.l	#$0000D400,a1
	moveq	#$00,d0
	bsr.s	.Fill
	move.l	a2,a1				;D400-D800
	add.l	#$0000D800,a1			;IO
	bsr.s	.FixIO
	move.l	a2,a1				;D800-FFFF
	add.l	#$00010000,a1			;RAM
	moveq	#$00,d0
	bsr.s	.Fill
	movem.l	(a7)+,a2-a3/d4-d7
	rts
.Fill
	move.l	d0,(a0)+
	cmp.l	a1,a0
	bne.s	.Fill
	rts
.FixIO
	lea	.D400(pc),a3
	movem.l	(a3)+,d4-d7
	movem.l	d4-d7,(a0)
	lea	$0010(a0),a0
	movem.l	(a3)+,d4-d7
	movem.l	d4-d7,(a0)
	lea	$0010(a0),a0
	cmp.l	a0,a1
	bne.s	.FixIO
	rts

    * MMU bytes for SID, bit 7 is set
.D400	
    dc.b	$80,$81,$82,$83,$84,$85,$86,$87	;$D400-$D418
	dc.b	$88,$89,$8a,$8b,$8c,$8d,$8e,$8f
	dc.b	$90,$91,$92,$93,$94,$95,$96,$97
	dc.b	$98,$00,$00,$00,$00,$00,$00,$00
	
* IO range for SID2, to be called after SetModule when the SID2 address is known
MakeMMUTable2:
	movem.l	d0-a6,-(a7)
    moveq   #0,d0
    move.w  psb_Sid2Address(a6),d0
    beq.b   .1
	move.l	psb_MMUMem(a6),a1
    add.l   d0,a1
    lea     .Sid2(pc),a0
    moveq   #.Sid2e-.Sid2-1,d0
.2  move.b  (a0)+,(a1)+
    dbf     d0,.2
.1	movem.l	(a7)+,d0-a6
    rts

    * MMU bytes for SID2, offset by $20
.Sid2
    dc.b	$80+$20,$81+$20,$82+$20,$83+$20,$84+$20,$85+$20,$86+$20,$87+$20
	dc.b	$88+$20,$89+$20,$8a+$20,$8b+$20,$8c+$20,$8d+$20,$8e+$20,$8f+$20
	dc.b	$90+$20,$91+$20,$92+$20,$93+$20,$94+$20,$95+$20,$96+$20,$97+$20
	dc.b	$98+$20,$00,$00,$00,$00,$00,$00,$00
.Sid2e

	
* IO range for SID3, to be called after SetModule when the SID2 address is known
MakeMMUTable3:
	movem.l	d0-a6,-(a7)
    moveq   #0,d0
    move.w  psb_Sid3Address(a6),d0
    beq.b   .1
	move.l	psb_MMUMem(a6),a1
    add.l   d0,a1
    lea     .Sid3(pc),a0
    moveq   #.Sid3e-.Sid3-1,d0
.2  move.b  (a0)+,(a1)+
    dbf     d0,.2
.1	movem.l	(a7)+,d0-a6
    rts

    * MMU bytes for SID3, offset by $40
.Sid3
    dc.b	$80+$40,$81+$40,$82+$40,$83+$40,$84+$40,$85+$40,$86+$40,$87+$40
	dc.b	$88+$40,$89+$40,$8a+$40,$8b+$40,$8c+$40,$8d+$40,$8e+$40,$8f+$40
	dc.b	$90+$40,$91+$40,$92+$40,$93+$40,$94+$40,$95+$40,$96+$40,$97+$40
	dc.b	$98+$40,$00,$00,$00,$00,$00,$00,$00
.Sid3e

*-----------------------------------------------------------------------*
Jump6502Routine		;6502 CODE MUST BE ENDED WITH RTS!
			;D0=AC,D1=XR,D2=YR,D3+D4+D5=P,D6=PC,D7=SP
	movem.l	a2-a6,-(a7)
	move.l	psb_C64Mem(a6),a0	;Set A0=MemBase

	andi.w	#$00ff,d7		;Set A1=SP
	addi.w	#$0101,d7
	lea	$0(a0,d7.w),a1

	move.l	psb_MMUMem(a6),a3	;Set A3=MMUTable

	move.l	psb_PrgMem(a6),a4
	add.l	#$8000,a4		;Set A4=EmulPrgBase
	move.l	a1,a5			;Set A5=StackLimit

	move.l	#$0000ffff,d7
	and.l	d7,d6

	lea	0(a0,d6.l),a6		;Set A6=PC

	move.l	#$000000ff,d6
	and.l	d7,d5
	btst	#11,d5
	beq.s	.3
	move.l	#$00010000,a2
	add.l	a2,a4
	add.l	a2,a5
	and.l	d7,d4
	ori.w	#$8000,d4
	bra.s	.4
.3	and.l	d6,d4
.4	and.l	d7,d3
	and.l	d6,d2
	and.l	d6,d1
	and.l	d6,d0

	move.w	#$D420,d7
	clr.b	0(a0,d7.l)		;New envelope clear

	move.b	(a6)+,-(a7)
	move.w	(a7)+,d7
	clr.b	d7
	jsr	0(a4,d7.w)
	move.l	a1,d7				;D7=SP
	sub.l	a0,d7
	subq.w	#1,d7

	move.l	a6,d6				;D6=PC
	sub.l	a0,d6
	movem.l	(a7)+,a2-a6
	rts

*-----------------------------------------------------------------------*
ReadIO					;Read 64 I/O $D000-$DFFF
					;IN: D7=Addr, D6=IOreg, A2=RetAddr
					;OUT: D6=Data
					;USAGE; D3
	add.b	d6,d6
	move.w	.JMP(pc,d6.w),d3
	jmp	.JMP(pc,d3.w)

.JMP
	dc.w	.D400-.JMP		;80
	dc.w	.D401-.JMP
	dc.w	.D402-.JMP
	dc.w	.D403-.JMP

	dc.w	.D404-.JMP		;84
	dc.w	.D405-.JMP
	dc.w	.D406-.JMP
	dc.w	.D407-.JMP

	dc.w	.D408-.JMP		;88
	dc.w	.D409-.JMP
	dc.w	.D40A-.JMP
	dc.w	.D40B-.JMP

	dc.w	.D40C-.JMP		;8C
	dc.w	.D40D-.JMP
	dc.w	.D40E-.JMP
	dc.w	.D40F-.JMP

	dc.w	.D410-.JMP		;90
	dc.w	.D411-.JMP
	dc.w	.D412-.JMP
	dc.w	.D413-.JMP

	dc.w	.D414-.JMP		;94
	dc.w	.D415-.JMP
	dc.w	.D416-.JMP
	dc.w	.D417-.JMP

	dc.w	.D418-.JMP		;98

    ; Fill the gap
    dc.w    0   ; D419
    dc.w    0   ; D41A
    dc.w    0   ; D41B
    dc.w    0   ; D41C
    dc.w    0   ; D41D
    dc.w    0   ; D41E
    dc.w    0   ; D41F

	dc.w	.D420-.JMP		;80
	dc.w	.D421-.JMP
	dc.w	.D422-.JMP
	dc.w	.D423-.JMP
	dc.w	.D424-.JMP		;84
	dc.w	.D425-.JMP
	dc.w	.D426-.JMP
	dc.w	.D427-.JMP
	dc.w	.D428-.JMP		;88
	dc.w	.D429-.JMP
	dc.w	.D42A-.JMP
	dc.w	.D42B-.JMP
	dc.w	.D42C-.JMP		;8C
	dc.w	.D42D-.JMP
	dc.w	.D42E-.JMP
	dc.w	.D42F-.JMP
	dc.w	.D430-.JMP		;90
	dc.w	.D431-.JMP
	dc.w	.D432-.JMP
	dc.w	.D433-.JMP
	dc.w	.D434-.JMP		;94
	dc.w	.D435-.JMP
	dc.w	.D436-.JMP
	dc.w	.D437-.JMP
	dc.w	.D438-.JMP		;98

    ; Fill the gap
    dc.w    0   ; D439
    dc.w    0   ; D43A
    dc.w    0   ; D43B
    dc.w    0   ; D43C
    dc.w    0   ; D43D
    dc.w    0   ; D43E
    dc.w    0   ; D43F

	dc.w	.D440-.JMP		;80
	dc.w	.D441-.JMP
	dc.w	.D442-.JMP
	dc.w	.D443-.JMP
	dc.w	.D444-.JMP		;84
	dc.w	.D445-.JMP
	dc.w	.D446-.JMP
	dc.w	.D447-.JMP
	dc.w	.D448-.JMP		;88
	dc.w	.D449-.JMP
	dc.w	.D44A-.JMP
	dc.w	.D44B-.JMP
	dc.w	.D44C-.JMP		;8C
	dc.w	.D44D-.JMP
	dc.w	.D44E-.JMP
	dc.w	.D44F-.JMP
	dc.w	.D450-.JMP		;90
	dc.w	.D451-.JMP
	dc.w	.D452-.JMP
	dc.w	.D453-.JMP
	dc.w	.D454-.JMP		;94
	dc.w	.D455-.JMP
	dc.w	.D456-.JMP
	dc.w	.D457-.JMP
	dc.w	.D458-.JMP		;98

.D400						;80
	move.w	#$D400,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D401
	move.w	#$D401,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D402
	move.w	#$D402,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D403
	move.w	#$D403,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D404
	move.w	#$D404,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D405
	move.w	#$D405,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D406
	move.w	#$D406,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D407
	move.w	#$D407,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D408
	move.w	#$D408,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D409
	move.w	#$D409,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D40A
	move.w	#$D40A,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D40B
	move.w	#$D40B,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D40C
	move.w	#$D40C,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D40D
	move.w	#$D40D,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D40E
	move.w	#$D40E,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D40F
	move.w	#$D40F,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D410						;90
	move.w	#$D410,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D411
	move.w	#$D411,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D412
	move.w	#$D412,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D413
	move.w	#$D413,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D414
	move.w	#$D414,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D415
	move.w	#$D415,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D416
	move.w	#$D416,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D417
	move.w	#$D417,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)
.D418
	move.w	#$D418,d7
	move.b	0(a0,d7.l),d6
	jmp	(a2)

.D420
.D421
.D422
.D423
.D424
.D425
.D426
.D427
.D428
.D429
.D42A
.D42B
.D42C
.D42D
.D42E
.D42F
.D430
.D431
.D432
.D433
.D434
.D435
.D436
.D437
.D438

.D440
.D441
.D442
.D443
.D444
.D445
.D446
.D447
.D448
.D449
.D44A
.D44B
.D44C
.D44D
.D44E
.D44F
.D450
.D451
.D452
.D453
.D454
.D455
.D456
.D457
.D458
    clr.b   d6
	jmp	    (a2)

*-----------------------------------------------------------------------*
WriteIO					;Write 64 I/O $D000-$DFFF
					;D7=IOReg,D6=Byte,A2=Addr
					;USAGE: D6,D7,A2
    * d7 is a byte from the MMUTable, with bit 7 set
    * Drop the 7th bit and make a word index.
    add.b   d7,d7
	move.w	.JMP(pc,d7.w),d7
	jmp	.JMP(pc,d7.w)

.JMP
	dc.w	.D400-.JMP		;80
	dc.w	.D401-.JMP
	dc.w	.D402-.JMP
	dc.w	.D403-.JMP

	dc.w	.D404-.JMP		;84
	dc.w	.D405-.JMP
	dc.w	.D406-.JMP
	dc.w	.D407-.JMP

	dc.w	.D408-.JMP		;88
	dc.w	.D409-.JMP
	dc.w	.D40A-.JMP
	dc.w	.D40B-.JMP

	dc.w	.D40C-.JMP		;8C
	dc.w	.D40D-.JMP
	dc.w	.D40E-.JMP
	dc.w	.D40F-.JMP

	dc.w	.D410-.JMP		;90
	dc.w	.D411-.JMP
	dc.w	.D412-.JMP
	dc.w	.D413-.JMP

	dc.w	.D414-.JMP		;94
	dc.w	.D415-.JMP
	dc.w	.D416-.JMP
	dc.w	.D417-.JMP

	dc.w	.D418-.JMP		;98
    ;----------------------------------
    ; Fill the gap
    dc.w    0   ; D419
    dc.w    0   ; D41A
    dc.w    0   ; D41B
    dc.w    0   ; D41C
    dc.w    0   ; D41D
    dc.w    0   ; D41E
    dc.w    0   ; D41F

	dc.w	.D420-.JMP		;80
	dc.w	.D421-.JMP
	dc.w	.D422-.JMP
	dc.w	.D423-.JMP
	dc.w	.D424-.JMP		;84
	dc.w	.D425-.JMP
	dc.w	.D426-.JMP
	dc.w	.D427-.JMP
	dc.w	.D428-.JMP		;88
	dc.w	.D429-.JMP
	dc.w	.D42A-.JMP
	dc.w	.D42B-.JMP
	dc.w	.D42C-.JMP		;8C
	dc.w	.D42D-.JMP
	dc.w	.D42E-.JMP
	dc.w	.D42F-.JMP
	dc.w	.D430-.JMP		;90
	dc.w	.D431-.JMP
	dc.w	.D432-.JMP
	dc.w	.D433-.JMP
	dc.w	.D434-.JMP		;94
	dc.w	.D435-.JMP
	dc.w	.D436-.JMP
	dc.w	.D437-.JMP
	dc.w	.D438-.JMP		;98

    ;----------------------------------
    ; Fill the gap
    dc.w    0   ; D439
    dc.w    0   ; D43A
    dc.w    0   ; D43B
    dc.w    0   ; D43C
    dc.w    0   ; D43D
    dc.w    0   ; D43E
    dc.w    0   ; D43F

	dc.w	.D440-.JMP		;80
	dc.w	.D441-.JMP
	dc.w	.D442-.JMP
	dc.w	.D443-.JMP
	dc.w	.D444-.JMP		;84
	dc.w	.D445-.JMP
	dc.w	.D446-.JMP
	dc.w	.D447-.JMP
	dc.w	.D448-.JMP		;88
	dc.w	.D449-.JMP
	dc.w	.D44A-.JMP
	dc.w	.D44B-.JMP
	dc.w	.D44C-.JMP		;8C
	dc.w	.D44D-.JMP
	dc.w	.D44E-.JMP
	dc.w	.D44F-.JMP
	dc.w	.D450-.JMP		;90
	dc.w	.D451-.JMP
	dc.w	.D452-.JMP
	dc.w	.D453-.JMP
	dc.w	.D454-.JMP		;94
	dc.w	.D455-.JMP
	dc.w	.D456-.JMP
	dc.w	.D457-.JMP
	dc.w	.D458-.JMP		;98

    ; ---------------------------------

.D420:
	move.w	#$D400,d7
    bsr     writeSID2Register
    Next_Inst
.D421:
	move.w	#$D401,d7
    bsr     writeSID2Register
    Next_Inst
.D422:
	move.w	#$D402,d7
    bsr     writeSID2Register
    Next_Inst
.D423:
	move.w	#$D403,d7
    bsr     writeSID2Register
    Next_Inst
.D424:
	move.w	#$D404,d7
    bsr     writeSID2Register
    Next_Inst
.D425:
	move.w	#$D405,d7
    bsr     writeSID2Register
    Next_Inst
.D426:
	move.w	#$D406,d7
    bsr     writeSID2Register
    Next_Inst
.D427:
	move.w	#$D407,d7
    bsr     writeSID2Register
    Next_Inst
.D428:
	move.w	#$D408,d7
    bsr     writeSID2Register
    Next_Inst
.D429:
	move.w	#$D409,d7
    bsr     writeSID2Register
    Next_Inst
.D42A:
	move.w	#$D40A,d7
    bsr     writeSID2Register
    Next_Inst
.D42B:
	move.w	#$D40B,d7
    bsr     writeSID2Register
    Next_Inst
.D42C:
	move.w	#$D40C,d7
    bsr     writeSID2Register
    Next_Inst
.D42D:
	move.w	#$D40D,d7
    bsr     writeSID2Register
    Next_Inst
.D42E:
	move.w	#$D40E,d7
    bsr     writeSID2Register
    Next_Inst
.D42F:
	move.w	#$D40F,d7
    bsr     writeSID2Register
    Next_Inst
.D430:
	move.w	#$D410,d7
    bsr     writeSID2Register
    Next_Inst
.D431:
	move.w	#$D411,d7
    bsr     writeSID2Register
    Next_Inst
.D432:
	move.w	#$D412,d7
    bsr     writeSID2Register
    Next_Inst
.D433:
	move.w	#$D413,d7
    bsr     writeSID2Register
    Next_Inst
.D434:
	move.w	#$D414,d7
    bsr     writeSID2Register
    Next_Inst
.D435:
	move.w	#$D15,d7
    bsr     writeSID2Register
    Next_Inst
.D436:
	move.w	#$D416,d7
    bsr     writeSID2Register
    Next_Inst
.D437:
	move.w	#$D417,d7
    bsr     writeSID2Register
    Next_Inst
.D438:
	move.w	#$D418,d7
    bsr     writeSID2Register
    Next_Inst

    ; ---------------------------------

.D440:
	move.w	#$D400,d7
    bsr     writeSID3Register
    Next_Inst
.D441:
	move.w	#$D401,d7
    bsr     writeSID3Register
    Next_Inst
.D442:
	move.w	#$D402,d7
    bsr     writeSID3Register
    Next_Inst
.D443:
	move.w	#$D403,d7
    bsr     writeSID3Register
    Next_Inst
.D444:
	move.w	#$D404,d7
    bsr     writeSID3Register
    Next_Inst
.D445:
	move.w	#$D405,d7
    bsr     writeSID3Register
    Next_Inst
.D446:
	move.w	#$D406,d7
    bsr     writeSID3Register
    Next_Inst
.D447:
	move.w	#$D407,d7
    bsr     writeSID3Register
    Next_Inst
.D448:
	move.w	#$D408,d7
    bsr     writeSID3Register
    Next_Inst
.D449:
	move.w	#$D409,d7
    bsr     writeSID3Register
    Next_Inst
.D44A:
	move.w	#$D40A,d7
    bsr     writeSID3Register
    Next_Inst
.D44B:
	move.w	#$D40B,d7
    bsr     writeSID3Register
    Next_Inst
.D44C:
	move.w	#$D40C,d7
    bsr     writeSID3Register
    Next_Inst
.D44D:
	move.w	#$D40D,d7
    bsr     writeSID3Register
    Next_Inst
.D44E:
	move.w	#$D40E,d7
    bsr     writeSID3Register
    Next_Inst
.D44F:
	move.w	#$D40F,d7
    bsr     writeSID3Register
    Next_Inst
.D450:
	move.w	#$D410,d7
    bsr     writeSID3Register
    Next_Inst
.D451:
	move.w	#$D411,d7
    bsr     writeSID3Register
    Next_Inst
.D452:
	move.w	#$D412,d7
    bsr     writeSID3Register
    Next_Inst
.D453:
	move.w	#$D413,d7
    bsr     writeSID3Register
    Next_Inst
.D454:
	move.w	#$D414,d7
    bsr     writeSID3Register
    Next_Inst
.D455:
	move.w	#$D15,d7
    bsr     writeSID3Register
    Next_Inst
.D456:
	move.w	#$D416,d7
    bsr     writeSID3Register
    Next_Inst
.D457:
	move.w	#$D417,d7
    bsr     writeSID3Register
    Next_Inst
.D458:
	move.w	#$D418,d7
    bsr     writeSID3Register
    Next_Inst

    ; ---------------------------------

.D400						;80
	move.w	#$D400,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D401
	move.w	#$D401,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D402
	move.w	#$D402,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D403
	move.w	#$D403,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D404
	move.w	#$D404,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip1
	move.l	a6,-(a7)
	move.l	_PlaySidBase,a6
	move.l	psb_Enve1(a6),a2
	lsr.b	#1,d6
	bcs.s	.D4041			;Gate turned on ?
	clr.w	env_Mode(a2)		;Release
	move.l	(a7)+,a6
	Next_Inst
.D4041
	tst.b	env_Mode(a2)
	bne.s	.D4042			;Gate was already on ?
	or.b	#$01,$D420-$D404(a0,d7.l)	;New Envelope
	move.w	env_CurrentAddr(a2),d7
	move.l	psb_EnvelopeMem(a6),a3
	move.b	(a3,d7.l),d6
	move.l	psb_AttackTable(a6),a3
	add.w	d6,d6
	move.w	0(a3,d6.w),env_CurrentAddr(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	st	env_Mode(a2)			;Attack
.D4042
	move.l	(a7)+,a6
.skip1
	Next_Inst
.D405
	move.w	#$D405,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip2
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Enve1(a6),a2
	lsl.w	#3,d6
	move.l	psb_AttackDecay(a6),a3
	move.l	0(a3,d6.w),env_Attack(a2)
	move.l	4(a3,d6.w),env_Decay(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	move.l	d7,a6
	moveq	#$00,d7
.skip2
	Next_Inst
.D406
	move.w	#$D406,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip3
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Enve1(a6),a2
	lsl.w	#3,d6
	move.l	psb_SustainRelease(a6),a3
	move.w	0(a3,d6.w),env_Sustain(a2)
	move.l	4(a3,d6.w),env_Release(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	move.l	d7,a6
	moveq	#$00,d7
.skip3
	Next_Inst
.D407
	move.w	#$D407,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D408
	move.w	#$D408,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D409
	move.w	#$D409,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D40A
	move.w	#$D40A,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D40B
	move.w	#$D40B,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip4
	move.l	a6,-(a7)
	move.l	_PlaySidBase,a6
	move.l	psb_Enve2(a6),a2
	lsr.b	#1,d6
	bcs.s	.D40B1			;Gate turned on ?
	clr.w	env_Mode(a2)		;Release
	move.l	(a7)+,a6
	Next_Inst
.D40B1
	tst.b	env_Mode(a2)
	bne.s	.D40B2			;Gate was already on ?
	or.b	#$02,$D420-$D40B(a0,d7.l)	;New Envelope
	move.w	env_CurrentAddr(a2),d7
	move.l	psb_EnvelopeMem(a6),a3
	move.b	(a3,d7.l),d6
	move.l	psb_AttackTable(a6),a3
	add.w	d6,d6
	move.w	0(a3,d6.w),env_CurrentAddr(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	st	env_Mode(a2)			;Attack
.D40B2
	move.l	(a7)+,a6
.skip4
	Next_Inst
.D40C
	move.w	#$D40C,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip5
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Enve2(a6),a2
	lsl.w	#3,d6
	move.l	psb_AttackDecay(a6),a3
	move.l	0(a3,d6.w),env_Attack(a2)
	move.l	4(a3,d6.w),env_Decay(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	move.l	d7,a6
	moveq	#$00,d7
.skip5
	Next_Inst
.D40D
	move.w	#$D40D,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip6
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Enve2(a6),a2
	lsl.w	#3,d6
	move.l	psb_SustainRelease(a6),a3
	move.w	0(a3,d6.w),env_Sustain(a2)
	move.l	4(a3,d6.w),env_Release(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	move.l	d7,a6
	moveq	#$00,d7
.skip6
	Next_Inst
.D40E
	move.w	#$D40E,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D40F
	move.w	#$D40F,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D410
	move.w	#$D410,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D411
	move.w	#$D411,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
	Next_Inst
.D412
	move.w	#$D412,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip7
	move.l	a6,-(a7)
	move.l	_PlaySidBase,a6
	move.l	psb_Enve3(a6),a2
	lsr.b	#1,d6
	bcs.s	.D4121			;Gate turned on ?
	clr.w	env_Mode(a2)		;Release
	move.l	(a7)+,a6
	Next_Inst
.D4121
	tst.b	env_Mode(a2)
	bne.s	.D4122			;Gate was already on ?
	or.b	#$04,$D420-$D412(a0,d7.l)	;New Envelope
	move.w	env_CurrentAddr(a2),d7
	move.l	psb_EnvelopeMem(a6),a3
	move.b	(a3,d7.l),d6
	move.l	psb_AttackTable(a6),a3
	add.w	d6,d6
	move.w	0(a3,d6.w),env_CurrentAddr(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	st	env_Mode(a2)			;Attack
.D4122
	move.l	(a7)+,a6
.skip7
	Next_Inst
.D413
	move.w	#$D413,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip8
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Enve3(a6),a2
	lsl.w	#3,d6
	move.l	psb_AttackDecay(a6),a3
	move.l	0(a3,d6.w),env_Attack(a2)
	move.l	4(a3,d6.w),env_Decay(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	move.l	d7,a6
	moveq	#$00,d7
.skip8
	Next_Inst
.D414
	move.w	#$D414,d7
	move.b	d6,0(a0,d7.l)
    bsr     writeSIDRegister
    bne.b   .skip9
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Enve3(a6),a2
	lsl.w	#3,d6
	move.l	psb_SustainRelease(a6),a3
	move.w	0(a3,d6.w),env_Sustain(a2)
	move.l	4(a3,d6.w),env_Release(a2)
	moveq	#$00,d6
	move.l	psb_MMUMem(a6),a3
	move.l	d7,a6
	moveq	#$00,d7
.skip9
	Next_Inst
.D415
	move.w	#$D415,d7
	move.b	d6,0(a0,d7.l)
    bsr.b    writeSIDRegister
	Next_Inst
.D416
	move.w	#$D416,d7
	move.b	d6,0(a0,d7.l)
    bsr.b   writeSIDRegister
	Next_Inst
.D417
	move.w	#$D417,d7
	move.b	d6,0(a0,d7.l)
    bsr.b   writeSIDRegister
	Next_Inst
.D418
	move.w	#$D418,d7
	move.b	d6,0(a0,d7.l)
    bsr.b   writeSIDRegister
    bne.b   .skip10
	move.l	a6,d7
	move.l	_PlaySidBase,a6
	move.l	psb_Chan4(a6),a2
	tst.b	ch4_Active(a2)
	bne.s	.D4181				;Channel Four Active
	andi.w	#$000f,d6
	lsl.w	#2,d6
	move.l	psb_VolumePointers(a6,d6.w),psb_VolumePointer(a6)
.D4181	move.l	d7,a6
	moveq	#$00,d7
.skip10
	Next_Inst


* Write to SID
* in:
*    d6 = data
*    d7 = address
* out:
*    Z set: normal playsid operation
*    Z clear: was written to reSID/SIDBlaster
writeSIDRegister:
	move.l	_PlaySidBase,a2
    tst.w   psb_OperatingMode(a2)
    bne.b   .out
    * Normal playsid mode
    rts
.out
    cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a2)
    beq.b   write_sid_reg

    * OM_RESID_6581, OM_RESID_8580

    movem.l d0-a6,-(sp)
 ifne ENABLE_REGDUMP
    move.l  regDumpOffset,d0
    cmp.l   #REGDUMP_SIZE,d0
    bhs.b   .1
    addq.l  #1,regDumpOffset
    lea     regDump,a1
    move.w  regDumpTime,(a1,d0.l*4)
    move.b  d7,2(a1,d0.l*4)
    move.b  d6,3(a1,d0.l*4)
.1
  endif

    move.b  d6,d0
    move.b  d7,d1
    move.l  psb_reSID(a2),a0
    jsr     sid_write
    moveq   #1,d0
    movem.l (sp)+,d0-a6
    rts


* Write to SID 2
* in:
*    d6 = data
*    d7 = Register offset 
* out:
*    Z set: normal playsid operation
*    Z clear: was written to reSID
writeSID2Register:
	move.l	_PlaySidBase,a2
    tst.w   psb_OperatingMode(a2)
    bne.b   .out
    * Normal playsid mode
.x
    rts
.out
    cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a2)
    beq.b   .x

    * OM_RESID_6581, OM_RESID_8580

    movem.l d0-a6,-(sp)
    move.b  d6,d0
    move.b  d7,d1
    move.l  psb_reSID2(a2),a0
    jsr     sid_write
    moveq   #1,d0
    movem.l (sp)+,d0-a6
    rts

* Write to SID 3
* in:
*    d6 = data
*    d7 = Register offset 
* out:
*    Z set: normal playsid operation
*    Z clear: was written to reSID
writeSID3Register:
	move.l	_PlaySidBase,a2
    tst.w   psb_OperatingMode(a2)
    bne.b   .out
    * Normal playsid mode
.x
    rts
.out
    cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a2)
    beq.b   .x

    * OM_RESID_6581, OM_RESID_8580

    movem.l d0-a6,-(sp)
    move.b  d6,d0
    move.b  d7,d1
    move.l  psb_reSID3(a2),a0
    jsr     sid_write
    moveq   #1,d0
    movem.l (sp)+,d0-a6
    rts

*-----------------------------------------------------------------------*

write_sid_reg:
	movem.l	d0-a6,-(sp)
    moveq   #0,d0
    moveq   #0,d1
	move.b	d7,d0
	move.b	d6,d1
	jsr	_sid_write_reg_record
	movem.l	(sp)+,d0-a6
	rts

start_sid_blaster:
    DPRINT  "start_sid_blaster"
	movem.l	d1-a6,-(sp)
	moveq.l	#$10,d0	; latency
	moveq.l	#$5,d1	; taskpri
	jsr	_sid_init
	tst.l	d0
	bne.b	.ok
    DPRINT  "fail %ld"
	moveq.l	#SID_NOSIDBLASTER,d0
	bra.b	.fail
.ok	clr.l	d0
.fail	movem.l	(sp)+,d1-a6
	rts

stop_sid_blaster:
    DPRINT  "stop_sid_blaster"
	movem.l	d0-a6,-(sp)
	jsr	_sid_exit
	movem.l	(sp)+,d0-a6
	rts

flush_sid_regs:
	movem.l	d0-a6,-(sp)		; paranoia
	jsr	_sid_write_reg_playback
	movem.l	(sp)+,d0-a6
	rts

mute_sid:
	movem.l	d0-a6,-(sp)
        moveq.l	#$00,d0 
        moveq.l	#$00,d1
        jsr	_sid_write_reg
        moveq.l	#$01,d0 
        moveq.l	#$00,d1
        jsr	_sid_write_reg
        moveq.l	#$07,d0 
        moveq.l	#$00,d1
        jsr	_sid_write_reg
        moveq.l	#$08,d0 
        moveq.l	#$00,d1
        jsr	_sid_write_reg
        moveq.l	#$0e,d0 
        moveq.l	#$00,d1
        jsr	_sid_write_reg
        moveq.l	#$0f,d0 
        moveq.l	#$00,d1
        jsr	_sid_write_reg
	movem.l	(sp)+,d0-a6
	rts

*=======================================================================*
*	INTERRUPT HANDLING ROUTINES					*
*=======================================================================*
OpenIRQ		
        DPRINT  "OpenIRQ"
        move.l	a6,timerAIntrPSB
		move.l	a6,PlayIntrPSB
	    move.l	psb_Chan1(a6),level4Intr1Data
		move.l	psb_Chan2(a6),level4Intr2Data
		move.l	psb_Chan3(a6),level4Intr3Data
		move.l	psb_Chan4(a6),level4Intr4Data

		lea	_custom,a0

        tst.w   psb_OperatingMode(a6)
        bne.b   .o1
		move.w	#INTF_AUD0+INTF_AUD1+INTF_AUD2+INTF_AUD3,INTENA(a0)
		move.w	#INTF_AUD0+INTF_AUD1+INTF_AUD2+INTF_AUD3,INTREQ(a0)
.o1
		tst.w	psb_IntVecAudFlag(a6)
		bne 	.1

        clr.l   psb_OldIntVecAud0(a6)
        clr.l   psb_OldIntVecAud1(a6)
        clr.l   psb_OldIntVecAud2(a6)
        clr.l   psb_OldIntVecAud3(a6)

        * For sample playback with reSID get one of the audio interrupts,
        * if not using AHI
        bsr     isResidActive
        beq     .notResid
        tst.l   psb_AhiMode(a6)
        bne     .1
        bra     .getAud3
.notResid
        * Skip lev4 unless normal mode
        tst.w   psb_OperatingMode(a6)
        bne     .1

	    moveq	#INTB_AUD0,d0		; Allocate Level 4
	    lea	level4Intr1,a1
	    move.l	a6,-(a7)
	    CALLEXEC	SetIntVector
	    move.l	(a7)+,a6
        move.l	d0,psb_OldIntVecAud0(a6)

        moveq	#INTB_AUD1,d0
	    lea	level4Intr2,a1
	    move.l	a6,-(a7)
	    CALLEXEC	SetIntVector
	    move.l	(a7)+,a6
	    
        move.l	d0,psb_OldIntVecAud1(a6)
        moveq	#INTB_AUD2,d0
	    lea	level4Intr3,a1
	    move.l	a6,-(a7)
	    CALLEXEC	SetIntVector
	    move.l	(a7)+,a6
	    move.l	d0,psb_OldIntVecAud2(a6)
.getAud3
        moveq	#INTB_AUD3,d0
	    lea	level4Intr4,a1
	    move.l	a6,-(a7)
	    CALLEXEC	SetIntVector
	    move.l	(a7)+,a6
	    move.l	d0,psb_OldIntVecAud3(a6)
	    
        ; Got level4 stuff!
        move.w	#1,psb_IntVecAudFlag(a6)
.1		
        lea	CiabName,a1	; Open Cia Resource
		moveq	#0,d0
		move.l	a6,-(a7)
		CALLEXEC	OpenResource
		move.l	(a7)+,a6
		move.l	d0,_CiabBase
		beq 	.error

		tst.w	psb_TimerAFlag(a6)
		bne.s	.2

        * Skip this timer (envelopes) if not in normal mode
        tst.w   psb_OperatingMode(a6)
        bne     .2

		lea	timerAIntr,a1	; Allocate Timers
		moveq	#CIAICRB_TA,d0
		move.l	a6,-(a7)
		CALLCIAB	AddICRVector
		move.l	(a7)+,a6
		tst.l	d0
		bne.s	.error
		move.w	#1,psb_TimerAFlag(a6)

.2		tst.w	psb_TimerBFlag(a6)
		bne.s	.3

        * Skip this timer (playback timer) if reSID
        bsr     isResidActive
        bne     .3

		lea	timerBIntr,a1
		moveq	#CIAICRB_TB,d0
		move.l	a6,-(a7)
		CALLCIAB	AddICRVector
		move.l	(a7)+,a6
		tst.l	d0
		bne.s	.error
		move.w	#1,psb_TimerBFlag(a6)
.3		

        bsr     isResidActive
        beq     .5
        jsr     createResidWorkerTask
.5
        bsr	PlayDisable
		moveq	#0,d0
		rts
.error		
        bsr	CloseIRQ
		moveq	#SID_NOCIATIMER,D0
		rts

*-----------------------------------------------------------------------*
CloseIRQ	tst.w	psb_TimerBFlag(a6)
		beq.s	.1
		lea	timerBIntr,a1	; Deallocate Timers
		moveq	#CIAICRB_TB,d0
		move.l	a6,-(a7)
		CALLCIAB	RemICRVector
		move.l	(a7)+,a6
		move.w	#0,psb_TimerBFlag(a6)
.1
		tst.w	psb_TimerAFlag(a6)
		beq.s	.2
		lea	timerAIntr,a1
		moveq	#CIAICRB_TA,d0
		move.l	a6,-(a7)
		CALLCIAB	RemICRVector
		move.l	(a7)+,a6
		move.w	#0,psb_TimerAFlag(a6)
.2
		tst.w	psb_IntVecAudFlag(a6)
		beq.s	.3
		moveq	#INTB_AUD3,d0	; Deallocate Level 4
		move.l	psb_OldIntVecAud3(a6),d1
        beq.b   .na1
        move.l  d1,a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
.na1
		moveq	#INTB_AUD2,d0
		move.l	psb_OldIntVecAud2(a6),d1
        beq.b   .na2
        move.l  d1,a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
.na2
        moveq	#INTB_AUD1,d0
		move.l	psb_OldIntVecAud1(a6),d1
        beq.b   .na3
        move.l  d1,a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
.na3
        moveq	#INTB_AUD0,d0
		move.l	psb_OldIntVecAud0(a6),d1
        beq.b   .na4
        move.l  d1,a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
.na4
        move.w	#0,psb_IntVecAudFlag(a6)
.3
        bsr     isResidActive
        beq     .noResid
        jsr     stopResidWorkerTask
.noResid
        rts

*-----------------------------------------------------------------------*
InitTimers
		move.w	psb_TimerConstA(a6),d0		; ~700
        tst.w   psb_OperatingMode(a6)
        bne.b   .1
		bsr	StopTimerA
		bsr	SetTimerA
		bsr	StartTimerA
.1		
        bsr	StopTimerB
		move.w	psb_TimerConstB(a6),d0		; ~14000
		bsr	SetTimerB
		bsr	StartTimerB
		rts

*-----------------------------------------------------------------------*
SetTimerA
		lea	_ciab,a0
		move.b	d0,ciatalo(a0)
		lsr.w	#8,d0
		move.b	d0,ciatahi(a0)
		rts

*-----------------------------------------------------------------------*
SetTimerB
		lea	_ciab,a0
		move.b	d0,ciatblo(a0)
		lsr.w	#8,d0
		move.b	d0,ciatbhi(a0)
		rts

*-----------------------------------------------------------------------*
StopTimerA
        tst.w   psb_OperatingMode(a6)
        bne.b   .1
		lea	_ciab,a0
		and.b	#CIACRAF_TODIN+CIACRAF_SPMODE+CIACRAF_OUTMODE+CIACRAF_PBON,ciacra(a0)	; Timer A Cia B
		bclr	#CIACRAB_START,ciacra(a0)
.1
		rts

*-----------------------------------------------------------------------*
StopTimerB
		lea	_ciab,a0
		and.b	#CIACRBF_ALARM+CIACRBF_OUTMODE+CIACRBF_PBON,ciacrb(a0)	; Timer B Cia B
		bclr	#CIACRBB_START,ciacrb(a0)
		rts

*-----------------------------------------------------------------------*
StartTimerA
		lea	_ciab,a0
		bset	#CIACRBB_START,ciacra(a0)
		rts

*-----------------------------------------------------------------------*
StartTimerB
		lea	_ciab,a0
		bset	#CIACRBB_START,ciacrb(a0)
		rts

*-----------------------------------------------------------------------*
PlayDisable					;Turns off all Audio
		bsr	StopTimerB
        tst.w   psb_OperatingMode(a6)
        bne.b   .1
		move.w	#INTF_AUD0+INTF_AUD1+INTF_AUD2+INTF_AUD3,INTENA(a0)
		move.w	#INTF_AUD0+INTF_AUD1+INTF_AUD2+INTF_AUD3,INTREQ(a0)
		move.w	#DMAF_AUD0+DMAF_AUD1+DMAF_AUD2+DMAF_AUD3,DMACON(a0)
		move.w	#$0001,AUD0PER(a0)
		move.w	#$0001,AUD1PER(a0)
		move.w	#$0001,AUD2PER(a0)
		move.w	#$0001,AUD3PER(a0)
		bsr	StopTimerA
		moveq	#0,d0
		lea	_custom,a0
		move.w	d0,AUD0VOL(a0)
		move.w	d0,AUD1VOL(a0)
		move.w	d0,AUD2VOL(a0)
		move.w	d0,AUD3VOL(a0)
.1
        cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a6)
        beq     mute_sid
        rts

*-----------------------------------------------------------------------*
* The registers when called as an interrupt handler:
* D0 = not valid (scratch)
* D1 = interrupt masks (scratch)
* A0 = Amiga Custom Chips Base Adress ($00DFF000) (scratch)
* A1 = is_Data (scratch)
* A5 = is_Code (The Handler) (scratch)
* A6 = ExecBase (scratch)
*-----------------------------------------------------------------------*
* The registers when called as an interrupt server:
* D0 = (scratch)
* D1 = (scratch)
* A0 = (scratch sometimes)
* A1 = is_Data (scratch)
* A5 = is_Code (The Handler) (scratch)
* A6 = (scratch)
*-----------------------------------------------------------------------*
timerAServer	equ	Envelopes		; Do Envelopes

*-----------------------------------------------------------------------*
timerBServer	
        CALLEXEC 	Cause		; Ready for Player
		moveq	#0,d0			; A1=softwIntr
		rts

*-----------------------------------------------------------------------*
softwServer	move.l	a6,-(a7)		; Play it..
        cmp.w   #PM_PLAY,psb_PlayMode(a1)
        bne.b   .x
		move.l	a1,a6
        bsr     Play64
.x      move.l	(a7)+,a6
		moveq	#0,d0
		rts

*-----------------------------------------------------------------------*
level4Handler1	move.l	ch_ProgPointer(a1),a5		;A1=Chan1
		jmp	(a5)

*-----------------------------------------------------------------------*
level4H1New
		move.w	#INTF_AUD0,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		move.l	ch_SamAdrOld(a1),AUD0LC(a0)
		move.w	ch_SamLenOld(a1),d0
		lsr.w	#1,d0
		move.w	d0,AUD0LEN(a0)
		move.w	ch_SamPerOld(a1),AUD0PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD0,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD0,INTENA(a0)
		move.w	#INTF_AUD0,INTREQ(a0)
		move.w	ch_SamPerOld(a1),AUD0PER(a0)
		rts

*-----------------------------------------------------------------------*
level4H1Sync
		move.w	#INTF_AUD0,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextSync
		move.l	ch_SamAdrOld(a1),AUD0LC(a0)
		move.w	d0,AUD0LEN(a0)
		move.w	ch_SamPerOld(a1),AUD0PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD0,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD0,INTREQ(a0)
		bsr	GetNextSync
		move.w	d0,AUD0LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4H1Ring
		move.w	#INTF_AUD0,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextRing
		move.l	a5,AUD0LC(a0)
		move.w	d0,AUD0LEN(a0)
		move.w	ch_SamPerOld(a1),AUD0PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD0,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD0,INTREQ(a0)
		bsr	GetNextRing
		move.l	a5,AUD0LC(a0)
		move.w	d0,AUD0LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4H1RSync
		move.w	#INTF_AUD0,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextRSync
		move.l	a5,AUD0LC(a0)
		move.w	d0,AUD0LEN(a0)
		move.w	ch_SamPerOld(a1),AUD0PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD0,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD0,INTREQ(a0)
		bsr	GetNextRSync
		move.l	a5,AUD0LC(a0)
		move.w	d0,AUD0LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4Handler2	move.l	ch_ProgPointer(a1),a5
		jmp	(a5)

*-----------------------------------------------------------------------*
level4H2New
		move.w	#INTF_AUD1,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		move.l	ch_SamAdrOld(a1),AUD1LC(a0)
		move.w	ch_SamLenOld(a1),d0
		lsr.w	#1,d0
		move.w	d0,AUD1LEN(a0)
		move.w	ch_SamPerOld(a1),AUD1PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD1,DMACON(a0)
		rts
		
.1
		move.w	#INTF_AUD1,INTENA(a0)
		move.w	#INTF_AUD1,INTREQ(a0)
		move.w	ch_SamPerOld(a1),AUD1PER(a0)
		rts

*-----------------------------------------------------------------------*
level4H2Sync
		move.w	#INTF_AUD1,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextSync
		move.l	ch_SamAdrOld(a1),AUD1LC(a0)
		move.w	d0,AUD1LEN(a0)
		move.w	ch_SamPerOld(a1),AUD1PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD1,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD1,INTREQ(a0)
		bsr	GetNextSync
		move.w	d0,AUD1LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4H2Ring
		move.w	#INTF_AUD1,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextRing
		move.l	a5,AUD1LC(a0)
		move.w	d0,AUD1LEN(a0)
		move.w	ch_SamPerOld(a1),AUD1PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD1,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD1,INTREQ(a0)
		bsr	GetNextRing
		move.l	a5,AUD1LC(a0)
		move.w	d0,AUD1LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4H2RSync
		move.w	#INTF_AUD1,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextRSync
		move.l	a5,AUD1LC(a0)
		move.w	d0,AUD1LEN(a0)
		move.w	ch_SamPerOld(a1),AUD1PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD1,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD1,INTREQ(a0)
		bsr	GetNextRSync
		move.l	a5,AUD1LC(a0)
		move.w	d0,AUD1LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4Handler3	move.l	ch_ProgPointer(a1),a5
		jmp	(a5)

*-----------------------------------------------------------------------*
level4H3New
		move.w	#INTF_AUD2,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		move.l	ch_SamAdrOld(a1),AUD2LC(a0)
		move.w	ch_SamLenOld(a1),d0
		lsr.w	#1,d0
		move.w	d0,AUD2LEN(a0)
		move.w	ch_SamPerOld(a1),AUD2PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD2,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD2,INTENA(a0)
		move.w	#INTF_AUD2,INTREQ(a0)
		move.w	ch_SamPerOld(a1),AUD2PER(a0)
		rts

*-----------------------------------------------------------------------*
level4H3Sync
		move.w	#INTF_AUD2,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextSync
		move.l	ch_SamAdrOld(a1),AUD2LC(a0)
		move.w	d0,AUD2LEN(a0)
		move.w	ch_SamPerOld(a1),AUD2PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD2,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD2,INTREQ(a0)
		bsr	GetNextSync
		move.w	d0,AUD2LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4H3Ring
		move.w	#INTF_AUD2,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextRing
		move.l	a5,AUD2LC(a0)
		move.w	d0,AUD2LEN(a0)
		move.w	ch_SamPerOld(a1),AUD2PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD2,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD2,INTREQ(a0)
		bsr	GetNextRing
		move.l	a5,AUD2LC(a0)
		move.w	d0,AUD2LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4H3RSync
		move.w	#INTF_AUD2,INTREQ(a0)
		lea	.1(pc),a5
		move.l	a5,ch_ProgPointer(a1)
		bsr	GetNextRSync
		move.l	a5,AUD2LC(a0)
		move.w	d0,AUD2LEN(a0)
		move.w	ch_SamPerOld(a1),AUD2PER(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD2,DMACON(a0)
		rts
.1
		move.w	#INTF_AUD2,INTREQ(a0)
		bsr	GetNextRSync
		move.l	a5,AUD2LC(a0)
		move.w	d0,AUD2LEN(a0)
		rts

*-----------------------------------------------------------------------*
level4Handler4	move.l	_PlaySidBase,a6
		tst.l	ch4_ProgPointer(a1)
		beq.b   .1
		move.l	ch4_ProgPointer(a1),a5
		jmp	(a5)
.1      rts

*-----------------------------------------------------------------------*
GalwayFourStart
		move.w	#INTF_AUD3,INTREQ(a0)
		lea	GalwayFour(pc),a5
		move.l	a5,ch4_ProgPointer(a1)
		move.b	ch4_AverageVol(a1),d0
		bsr	SelectNewVolume
		move.l	ch4_SamAdr(a1),AUD3LC(a0)
		move.w	ch4_SamLen(a1),AUD3LEN(a0)
		bsr	GetNextFour
		addq.b	#1,ch4_Counter(a1)
		move.w	d0,AUD3PER(a0)
		move.w	#$0000,AUD3VOL(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD3,DMACON(a0)
		rts

*-----------------------------------------------------------------------*
GalwayFour	move.w	#INTF_AUD3,INTREQ(a0)
		;move.w	ch4_SamVol(a1),AUD3VOL(a0)
		bsr	SetCh4Vol
		bsr	GetNextFour
		move.w	d0,ch4_SamPer(a1)
		move.w	d0,AUD3PER(a0)
		cmp.b	#$ff,ch4_Counter(a1)
		bne.s	.1
		lea	GalwayFourEnd(pc),a5
		move.l	a5,ch4_ProgPointer(a1)
.1		rts

*-----------------------------------------------------------------------*
GalwayFourEnd
		move.w	#INTF_AUD3,INTENA(a0)
		move.w	#INTF_AUD3,INTREQ(a0)
		move.w	#DMAF_AUD3,DMACON(a0)
		move.w	#$0000,AUD3VOL(a0)
		bsr	SelectVolume
		clr.b	ch4_Active(a1)			;Four Inactive
		move.b	#FM_GALWAYOFF,ch4_Mode(a1)
		rts

*-----------------------------------------------------------------------*
HuelsFourStart
		move.w	#INTF_AUD3,INTREQ(a0)
		lea	HuelsFour(pc),a5
		move.l	a5,ch4_ProgPointer(a1)
		move.b	ch4_AverageVol(a1),d0
		bsr	SelectNewVolume
		move.l	ch4_SamAdr(a1),AUD3LC(a0)
		move.l	ch4_SamLen(a1),AUD3LEN(a0)
		move.w	#$0000,AUD3VOL(a0)
		move.w	#DMAF_SETCLR+DMAF_AUD3,DMACON(a0)
		rts

*-----------------------------------------------------------------------*
HuelsFour
		move.w	#INTF_AUD3,INTREQ(a0)
;		move.w	ch4_SamVol(a1),AUD3VOL(a0)
		bsr	SetCh4Vol
		move.l	ch4_SamRepAdr(a1),AUD3LC(a0)
		move.w	ch4_SamRepLen(a1),AUD3LEN(a0)
		subq.b	#1,ch4_Repeat(a1)
		cmp.b	#$ff,ch4_Repeat(a1)
		bne.s	.1
		lea	HuelsFourEnd(pc),a5
		move.l	a5,ch4_ProgPointer(a1)
.1		rts

*-----------------------------------------------------------------------*
HuelsFourEnd
		move.w	#INTF_AUD3,INTENA(a0)
		move.w	#INTF_AUD3,INTREQ(a0)
		move.w	#DMAF_AUD3,DMACON(a0)
		move.w	#$0000,AUD3VOL(a0)
		bsr	SelectVolume
		clr.b	ch4_Active(a1)
		move.b	#FM_HUELSOFF,ch4_Mode(a1)
		rts

*-----------------------------------------------------------------------*
GetNextSync
.1		move.w	ch_SamIndStop(a1),d0
		beq	.3
		cmp.w	ch_SamLenDec(a1),d0
		bhi	.2
		clr.w	ch_SamIndStop(a1)
		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		rts
.2		move.w	ch_SamLenDec(a1),d0
		sub.w	d0,ch_SamIndStop(a1)
		rts
.3		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		bra	.1

*-----------------------------------------------------------------------*
GetNextRing
.1		move.l	ch_SamAdrOld(a1),a5
		move.w	ch_SamIndStart(a1),d1
		add.w	d1,a5
		move.w	ch_SamIndStop(a1),d0
		sub.w	d1,d0
		beq	.5
		cmp.w	ch_SamLenDec(a1),d0
		bhi	.4
		add.w	d0,ch_SamIndStart(a1)
		move.l	ch_SamLenHDec(a1),d1
		add.l	d1,ch_SamIndStart(a1)
		add.l	d1,ch_SamIndStop(a1)
		move.w	ch_SamLenDec(a1),d1
.2		cmp.w	ch_SamIndStart(a1),d1
		bhi	.3
		sub.w	d1,ch_SamIndStart(a1)
		sub.w	d1,ch_SamIndStop(a1)
		bra	.2
.3		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		rts
.4		move.w	ch_SamLenDec(a1),d0
		sub.w	d0,ch_SamIndStop(a1)
		rts
.5		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		bra	.1

*-----------------------------------------------------------------------*
GetNextRSync
.1		move.l	ch_SamAdrOld(a1),a5
		move.w	ch_SamIndStart(a1),d1
		add.w	d1,a5
		move.w	ch_SamIndStop(a1),d0
		sub.w	d1,d0
		beq	.5
		cmp.w	ch_SamLenDec(a1),d0
		bhi	.4
		add.w	d0,ch_SamIndStart(a1)
		not.b	ch_RSyncToggle(a1)
		bpl	.6
		move.l	ch_SamLenHDec(a1),d1
		add.l	d1,ch_SamIndStart(a1)
		add.l	d1,ch_SamIndStop(a1)
		move.w	ch_SamLenDec(a1),d1
.2		cmp.w	ch_SamIndStart(a1),d1
		bhi	.3
		sub.w	d1,ch_SamIndStart(a1)
		sub.w	d1,ch_SamIndStop(a1)
		bra	.2
.3		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		rts
.4		move.w	ch_SamLenDec(a1),d0
		sub.w	d0,ch_SamIndStop(a1)
		rts
.5		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		bra	.1
.6		clr.w	ch_SamIndStart(a1)
		clr.w	ch_SamIndStop(a1)
		move.l	ch_SyncLenOld(a1),d1
		add.l	d1,ch_SamIndStop(a1)
		rts

*-----------------------------------------------------------------------*
GetNextFour
		moveq	#$00,d0
		move.b	ch4_Counter(a1),d0
		subq.b	#1,ch4_Counter(a1)
		move.l	ch4_Adress(a1),a5
		add.w	d0,a5
		move.b	(a5),d0
		mulu.w	ch4_LoopWait(a1),d0
		add.w	ch4_NullWait(a1),d0
		rts

*-----------------------------------------------------------------------*
SelectNewVolume
		move.l	_PlaySidBase,a5
		move.l	psb_C64Mem(a5),a5
		add.l	#$D400,a5
		move.b	sid_Volume(a5),d1
		andi.w	#$000f,d1
		cmp.w	#$000c,d1
		bls.s	.1
		andi.w	#$000f,d0
		add.w	d0,d0
		add.w	d0,d0
		move.l	_PlaySidBase,a5
		move.l	psb_VolumePointers(a5,d0.w),psb_VolumePointer(a5)
.1		rts

*-----------------------------------------------------------------------*

EndOfLibrary

@FreeEmulAudio	jmp	@FreeEmulAudio_impl.l

@AllocEmulAudio	
        * No audio alloc with SIDBlaster
        cmp.w   #OM_SIDBLASTER_USB,psb_OperatingMode(a6)
        beq     .3

        * Allocate audio in classic mode  
        bsr     isResidActive
        beq     .2

        * Allocate audio in reSID mode
        tst.l   psb_AhiMode(a6)
        beq     .2 
        * No audio alloc when reSID+AHI
.3
        moveq   #0,d0 * no error
        rts
.2
        jmp	@AllocEmulAudio_impl.l

*=======================================================================*
*                                                                       *
*	DATA SECTION							*
*                                                                       *
*=======================================================================*
	Section	.data,data
*-----------------------------------------------------------------------*

*=======================================================================*
*	SID PLAYER							*
*=======================================================================*
SidPlayer	incbin	sidplay.c64
*-----------------------------------------------------------------------*

*=======================================================================*
*	INTERRUPT HANDLING DATA						*
*=======================================================================*
level4Intr1	dc.l	0		; Audio Interrupt
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	level4Name1
level4Intr1Data	dc.l	0		;is_Data
		dc.l	level4Handler1	;is_Code

level4Intr2	dc.l	0		; Audio Interrupt
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	level4Name2
level4Intr2Data	dc.l	0
		dc.l	level4Handler2

level4Intr3	dc.l	0		; Audio Interrupt
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	level4Name3
level4Intr3Data	dc.l	0
		dc.l	level4Handler3

level4Intr4	dc.l	0		; Audio Interrupt
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	level4Name4
level4Intr4Data	dc.l	0
		dc.l	level4Handler4
timerAIntr	dc.l	0		; Envelope
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	timerAName
timerAIntrPSB	dc.l	0
		dc.l	timerAServer

timerBIntr	dc.l	0		; Player (Hardware)
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	timerBName
		dc.l	PlayIntr
		dc.l	timerBServer

PlayIntr	dc.l	0		; Player (Software)
		dc.l	0
		dc.b	2
		dc.b	0
		dc.l	softwName
PlayIntrPSB	dc.l	0
		dc.l	softwServer

level4H1List
		dc.l	level4H1New
		dc.l	level4H1Sync
		dc.l	level4H1Ring
		dc.l	level4H1RSync
level4H2List
		dc.l	level4H2New
		dc.l	level4H2Sync
		dc.l	level4H2Ring
		dc.l	level4H2RSync
level4H3List
		dc.l	level4H3New
		dc.l	level4H3Sync
		dc.l	level4H3Ring
		dc.l	level4H3RSync

level4Name1	dc.b	"PlaySID - Audio 1",0
level4Name2	dc.b	"PlaySID - Audio 2",0
level4Name3	dc.b	"PlaySID - Audio 3",0
level4Name4	dc.b	"PlaySID - Audio 4",0
timerAName	dc.b	"PlaySID - Timer A",0
timerBName	dc.b	"PlaySID - Timer B",0
softwName	dc.b	"PlaySID - Player",0

CiabName	CIABNAME
		even

*-----------------------------------------------------------------------*

*=======================================================================*
*	SOUND EMULATION DATA						*
*=======================================================================*
CalcFreqData1	dc.w	4
		dc.l	FREQPAL/4
		dc.l	(FREQPAL/4)/123		;Highest 64freq allowed
		dc.w	6
		dc.l	FREQPAL/6
		dc.l	(FREQPAL/6)/123
		dc.w	8
		dc.l	FREQPAL/8
		dc.l	(FREQPAL/8)/123
		dc.w	12
		dc.l	FREQPAL/12
		dc.l	(FREQPAL/12)/123
		dc.w	16
		dc.l	FREQPAL/16
		dc.l	(FREQPAL/16)/123
		dc.w	24
		dc.l	FREQPAL/24
		dc.l	(FREQPAL/24)/123
		dc.w	32
		dc.l	FREQPAL/32
		dc.l	(FREQPAL/32)/123
		dc.w	46
		dc.l	FREQPAL/46
		dc.l	(FREQPAL/46)/123
		dc.w	64
		dc.l	FREQPAL/64
		dc.l	(FREQPAL/64)/123
		dc.w	92
		dc.l	FREQPAL/92
		dc.l	(FREQPAL/92)/123
		dc.w	128
		dc.l	FREQPAL/128
		dc.l	(FREQPAL/128)/123
		dc.w	182
		dc.l	FREQPAL/182
		dc.l	(FREQPAL/182)/123
		dc.w	256
		dc.l	FREQPAL/256
		dc.l	(FREQPAL/256)/123
		dc.w	0
		dc.l	0
		dc.l	0

CalcFreqData2	dc.w	4
		dc.l	FREQNTSC/4
		dc.l	(FREQNTSC/4)/124
		dc.w	6
		dc.l	FREQNTSC/6
		dc.l	(FREQNTSC/6)/124
		dc.w	8
		dc.l	FREQNTSC/8
		dc.l	(FREQNTSC/8)/124
		dc.w	12
		dc.l	FREQNTSC/12
		dc.l	(FREQNTSC/12)/124
		dc.w	16
		dc.l	FREQNTSC/16
		dc.l	(FREQNTSC/16)/124
		dc.w	24
		dc.l	FREQNTSC/24
		dc.l	(FREQNTSC/24)/124
		dc.w	32
		dc.l	FREQNTSC/32
		dc.l	(FREQNTSC/32)/124
		dc.w	46
		dc.l	FREQNTSC/46
		dc.l	(FREQNTSC/46)/124
		dc.w	64
		dc.l	FREQNTSC/64
		dc.l	(FREQNTSC/64)/124
		dc.w	92
		dc.l	FREQNTSC/92
		dc.l	(FREQNTSC/92)/124
		dc.w	128
		dc.l	FREQNTSC/128
		dc.l	(FREQNTSC/128)/124
		dc.w	182
		dc.l	FREQNTSC/182
		dc.l	(FREQNTSC/182)/124
		dc.w	256
		dc.l	FREQNTSC/256
		dc.l	(FREQNTSC/256)/124

		dc.w	0
		dc.l	0
		dc.l	0
MakeSIDSData1
		dc.b	$00,$00,$00,$00,$00,$40,$60,$7f		;$78
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00		;$80
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00		;$88
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00		;$90
		dc.b	$00,$00,$00,$00,$00,$00,$00,$80		;$98
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00		;$a0
		dc.b	$00,$00,$00,$00,$00,$00,$00,$80		;$a8
		dc.b	$00,$00,$00,$00,$00,$00,$00,$80		;$b0
		dc.b	$00,$00,$00,$80,$00,$80,$80,$bf		;$b8
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00		;$c0
		dc.b	$00,$00,$00,$00,$00,$00,$00,$80		;$c8
		dc.b	$00,$00,$00,$00,$00,$00,$00,$c0		;$d0
		dc.b	$00,$00,$00,$c0,$00,$c0,$c0,$df		;$d8
		dc.b	$00,$00,$00,$00,$00,$00,$00,$c0		;$e0
		dc.b	$00,$00,$00,$c0,$e0,$e0,$e0,$ef		;$e8
		dc.b	$00,$00,$80,$e0,$80,$e0,$e0,$f7		;$f0
		dc.b	$80,$e0,$f0,$fb,$f0,$fd,$fe,$ff		;$f8
MakeSIDSData2
		dc.w	$0100
		dc.w	$00b6
		dc.w	$0080
		dc.w	$005c
		dc.w	$0040
		dc.w	$002e
		dc.w	$0020
		dc.w	$0018
		dc.w	$0010
		dc.w	$000c
		dc.w	$0008
		dc.w	$0006
		dc.w	$0004
		dc.w	$0000
MakeSIDSData3
		dc.b	$80,$91,$a2,$b3,$c4,$d5,$e6,$f7
		dc.b	$08,$19,$2a,$3b,$4c,$5d,$6e,$7f

AttDecRelStep
		dc.w	4000, 0, 1000, 0, 500, 0, 333, 21846
		dc.w	210, 34493, 142, 56174, 117, 42406, 100, 0
		dc.w	80, 0, 32, 0, 16, 0, 10, 0
		dc.w	8, 0, 2, 43691, 1, 39322, 1, 0

*-----------------------------------------------------------------------*

*=======================================================================*
*	REMEMBER DATA							*
*=======================================================================*
RememberTable	SoundRemTable

*-----------------------------------------------------------------------*

*=======================================================================*
*	CPU 6502 EMULATION DATA						*
*=======================================================================*
InstTable1
	dc.w	I00-I00,I01-I00,I02-I00,I03-I00,I04-I00,I05-I00,I06-I00,I07-I00
	dc.w	I08-I00,I09-I00,I0A-I00,I0B-I00,I0C-I00,I0D-I00,I0E-I00,I0F-I00
	dc.w	I10-I00,I11-I00,I12-I00,I13-I00,I14-I00,I15-I00,I16-I00,I17-I00
	dc.w	I18-I00,I19-I00,I1A-I00,I1B-I00,I1C-I00,I1D-I00,I1E-I00,I1F-I00

	dc.w	I20-I00,I21-I00,I22-I00,I23-I00,I24-I00,I25-I00,I26-I00,I27-I00
	dc.w	I28-I00,I29-I00,I2A-I00,I2B-I00,I2C-I00,I2D-I00,I2E-I00,I2F-I00
	dc.w	I30-I00,I31-I00,I32-I00,I33-I00,I34-I00,I35-I00,I36-I00,I37-I00
	dc.w	I38-I00,I39-I00,I3A-I00,I3B-I00,I3C-I00,I3D-I00,I3E-I00,I3F-I00

	dc.w	I40-I00,I41-I00,I42-I00,I43-I00,I44-I00,I45-I00,I46-I00,I47-I00
	dc.w	I48-I00,I49-I00,I4A-I00,I4B-I00,I4C-I00,I4D-I00,I4E-I00,I4F-I00
	dc.w	I50-I00,I51-I00,I52-I00,I53-I00,I54-I00,I55-I00,I56-I00,I57-I00
	dc.w	I58-I00,I59-I00,I5A-I00,I5B-I00,I5C-I00,I5D-I00,I5E-I00,I5F-I00

	dc.w	I60-I00,I61-I00,I62-I00,I63-I00,I64-I00,I65-I00,I66-I00,I67-I00
	dc.w	I68-I00,I69-I00,I6A-I00,I6B-I00,I6C-I00,I6D-I00,I6E-I00,I6F-I00
	dc.w	I70-I00,I71-I00,I72-I00,I73-I00,I74-I00,I75-I00,I76-I00,I77-I00
	dc.w	I78-I00,I79-I00,I7A-I00,I7B-I00,I7C-I00,I7D-I00,I7E-I00,I7F-I00

	dc.w	I80-I00,I81-I00,I82-I00,I83-I00,I84-I00,I85-I00,I86-I00,I87-I00
	dc.w	I88-I00,I89-I00,I8A-I00,I8B-I00,I8C-I00,I8D-I00,I8E-I00,I8F-I00
	dc.w	I90-I00,I91-I00,I92-I00,I93-I00,I94-I00,I95-I00,I96-I00,I97-I00
	dc.w	I98-I00,I99-I00,I9A-I00,I9B-I00,I9C-I00,I9D-I00,I9E-I00,I9F-I00

	dc.w	IA0-I00,IA1-I00,IA2-I00,IA3-I00,IA4-I00,IA5-I00,IA6-I00,IA7-I00
	dc.w	IA8-I00,IA9-I00,IAA-I00,IAB-I00,IAC-I00,IAD-I00,IAE-I00,IAF-I00
	dc.w	IB0-I00,IB1-I00,IB2-I00,IB3-I00,IB4-I00,IB5-I00,IB6-I00,IB7-I00
	dc.w	IB8-I00,IB9-I00,IBA-I00,IBB-I00,IBC-I00,IBD-I00,IBE-I00,IBF-I00

	dc.w	IC0-I00,IC1-I00,IC2-I00,IC3-I00,IC4-I00,IC5-I00,IC6-I00,IC7-I00
	dc.w	IC8-I00,IC9-I00,ICA-I00,ICB-I00,ICC-I00,ICD-I00,ICE-I00,ICF-I00
	dc.w	ID0-I00,ID1-I00,ID2-I00,ID3-I00,ID4-I00,ID5-I00,ID6-I00,ID7-I00
	dc.w	ID8-I00,ID9-I00,IDA-I00,IDB-I00,IDC-I00,IDD-I00,IDE-I00,IDF-I00

	dc.w	IE0-I00,IE1-I00,IE2-I00,IE3-I00,IE4-I00,IE5-I00,IE6-I00,IE7-I00
	dc.w	IE8-I00,IE9-I00,IEA-I00,IEB-I00,IEC-I00,IED-I00,IEE-I00,IEF-I00
	dc.w	IF0-I00,IF1-I00,IF2-I00,IF3-I00,IF4-I00,IF5-I00,IF6-I00,IF7-I00
	dc.w	IF8-I00,IF9-I00,IFA-I00,IFB-I00,IFC-I00,IFD-I00,IFE-I00,IFF-I00

	dc.w	IEND-I00

*-----------------------------------------------------------------------*
I00					;BRK
	NextInstStat2
	
I01					;ORA - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	or.b	0(a0,d7.l),d0
	NextInstStat			;N & Z

I02					;???
	NextInstStat2

I03					;+ ASL,ORA - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6
	MovepInd
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I04					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I05					;ORA - Zero Page
	move.b	(a6)+,d6
	or.b	0(a0,d6.l),d0
	NextInstStat			;N & Z

I06					;ASL - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I07					;+ ASL,ORA - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I08					;PHP
					;C64 SR:NV_BDIZC
	SetAStatus
	move.w	d5,-(a7)
	move.b	(a7)+,d7		;B,D,I
	move.w	d5,d6
	andi.w	#$0040,d6
	or.w	d6,d7
	move.w	d4,d6
	andi.w	#$0001,d6
	or.w	d6,d7
	tst.w	d3
	bpl.s	I08b
	ori.w	#$0080,d7
I08b
	tst.b	d3
	bpl.s	I08c
	ori.w	#$0080,d7
I08c
	bne.s	I08d
	ori.w	#$0002,d7
I08d
	move.b	d7,-(a1)
	NextInst

I09					;ORA - Immediate
	or.b	(a6)+,d0
	NextInstStat			;N & Z

I0A					;ASL - Accumulator
	add.b	d0,d0
	scs	d4			;C
	NextInstStat			;N & Z

I0B					;+ AND,ASL - Immeditate
	and.b	(a6)+,d0
	move.w	d0,d6
	add.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	NextInst

I0C					;+ NOP - Absolute
	addq.l	#2,a6
	NextInstStat2

I0D					;ORA - Absolute
	MovepAbs
	or.b	0(a0,d7.l),d0
	NextInstStat			;N & Z

I0E					;ASL - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I0F					;+ ASL,ORA - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I10					;BPL
	move.b	(a6)+,d7
	tst.w	d3			;N
	bmi.s	I10a
	tst.b	d3			;N
	bmi.s	I10a
	ext.w	d7
	adda.w	d7,a6
I10a
	NextInst
	IfStatus
	move.b	(a6)+,d7
	tst.b	d0			;N
	bmi.s	I10b
	ext.w	d7
	adda.w	d7,a6
I10b
	NextInstStat2

I11					;ORA - (Indirect),y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	or.b	0(a0,d7.l),d0
	NextInstStat

I12					;???
	NextInstStat2

I13					;+ ASL,ORA - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I14					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I15					;ORA - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	or.b	0(a0,d6.l),d0
	NextInstStat

I16					;ASL - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I17					;+ ASL,ORA - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I18					;CLC
	sub.b	d4,d4			;X___C
	NextInstStat2

I19					;ORA - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	or.b	0(a0,d7.l),d0
	NextInstStat

I1A					;+ NOP
	NextInstStat2

I1B					;+ ASL,ORA - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I1C					;+ NOP - Absolute
	addq.l	#2,a6
	NextInstStat2

I1D					;ORA - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	or.b	0(a0,d7.l),d0
	NextInstStat
	
I1E					;ASL - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I1F					;+ ASL,ORA - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	add.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	or.b	d6,d0
	NextInstStat

I20					;JSR
	move.b	1(a6),-(sp)
	move.w	(sp)+,d7
	move.b	(a6)+,d7
	move.l	a6,a2
	sub.l	a0,a2
	lea	0(a0,d7.l),a6
	move.w	a2,d7
	move.w	d7,-(a7)
	move.b	(a7)+,-(a1)
	move.b	d7,-(a1)
	NextInstStat2

I21					;AND - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	and.b	0(a0,d7.l),d0
	NextInstStat

I22					;???
	NextInstStat2

I23					;+ ROL,AND - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I24					;BIT - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d6
	move.b	d6,d7
	smi	d3
	ext.w	d3			;N
	add.b	d7,d7
	smi	d5			;V
	and.b	d0,d6
	sne	d3
	neg.b	d3			;Z
	NextInst

I25					;AND - Zero Page
	move.b	(a6)+,d6
	and.b	0(a0,d6.l),d0
	NextInstStat

I26					;ROL - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I27					;+ ROL,AND - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I28					;PLP
	move.b	(a1)+,d4		;Get P from Stack
	move.b	d4,d3
	ext.w	d3
	not.b	d3
	andi.w	#$8002,d3
	move.b	d4,-(a7)
	move.w	(a7)+,d5
	move.b	d4,d5
	andi.w	#$0c40,d5		;D,I,V
	ori.w	#$3000,d5		;B
	lsr.b	#1,d4
	scs	d4			;C
	CheckDecMode
	NextInst

I29					;AND - Immediate
	and.b	(a6)+,d0
	NextInstStat

I2A					;ROL - Accumulator
	neg.b	d4			;C
	addx.b	d0,d0
	scs	d4			;C
	NextInstStat

I2B					;+ AND,ROL - Immediate
	and.b 	(a6)+,d0
	move.w	d0,d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	NextInst

I2C					;BIT - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d6
I2Cc
	move.b	d6,d7
	smi	d3
	ext.w	d3			;N
	add.b	d7,d7
	smi	d5			;V
	and.b	d0,d6
	sne	d3
	neg.b	d3			;Z
	NextInst

I2D					;AND - Absolute
	MovepAbs
	and.b	0(a0,d7.l),d0
	NextInstStat

I2E					;ROL - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I2F					;+ ROL,AND - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I30					;BMI
	move.b	(a6)+,d7
	tst.w	d3
	bmi.s	I30a
	tst.b	d3
	bpl.s	I30b
I30a
	ext.w	d7
	adda.w	d7,a6
I30b
	NextInst
	IfStatus
	move.b	(a6)+,d7
	tst.b	d0
	bpl.s	I30c
	ext.w	d7
	adda.w	d7,a6
I30c
	NextInstStat2

I31					;AND - (Indirect),y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	and.b	0(a0,d7.l),d0
	NextInstStat
	
I32					;???
	NextInstStat2

I33					;+ ROL,AND - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I34					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I35					;AND - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	and.b	0(a0,d6.l),d0
	NextInstStat

I36					;ROL - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I37					;+ ROL,AND - (Ind),Y
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I38					;SEC
	st	d4			;C
	NextInstStat2

I39					;AND - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	and.b	0(a0,d7.l),d0
	NextInstStat

I3A					;+ NOP
	NextInstStat2

I3B					;+ ROL,AND - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I3C					;+ NOP - Absolute
	addq.l	#2,a6
	NextInstStat2

I3D					;AND - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	and.b	0(a0,d7.l),d0
	NextInstStat

I3E					;ROL - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I3F					;+ ROL,AND - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	addx.b	d6,d6
	scs	d4			;C
	move.b	d6,(a2)
	and.b	d6,d0
	NextInstStat

I40					;RTI
	rts

I41					;EOR - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	move.b	0(a0,d7.l),d7
	eor.b	d7,d0
	NextInstStat

I42					;???
	NextInstStat2

I43					;+ LSR,EOR - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I44					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I45					;EOR - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d7
	eor.b	d7,d0
	NextInstStat

I46					;LSR - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I47					;+ LSR,EOR - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I48					;PHA
	move.b	d0,-(a1)
	NextInstStat2

I49					;EOR - Immediate
	move.b	(a6)+,d7
	eor.b	d7,d0
	NextInstStat

I4A					;LSR - Accumulator
	lsr.b	#1,d0
	scs	d4			;C
	NextInstStat

I4B					;+ AND,LSR - Immediate
	and.b	(a6)+,d0
	lsr.b	#1,d0
	scs	d4			;C
	NextInstStat

I4C					;JMP - Absolute
	move.b	1(a6),-(sp)
	move.w	(sp)+,d7
	move.b	(a6),d7
	lea	0(a0,d7.l),a6
	NextInstStat2

I4D					;EOR - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d7
	eor.b	d7,d0
	NextInstStat

I4E					;LSR - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I4F					;+ LSR,EOR - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I50					;BVC
	move.b	(a6)+,d7
	tst.b	d5
	bne.s	I50a
	ext.w	d7
	adda.w	d7,a6
I50a
	NextInstStat2

I51					;EOR - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d7
	eor.b	d7,d0
	NextInstStat

I52					;???
	NextInstStat2

I53					;+ LSR,EOR - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I54					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I55					;EOR - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.b	0(a0,d6.l),d7
	eor.b	d7,d0
	NextInstStat

I56					;LSR - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I57					;+ LSR,EOR - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I58					;CLI
	andi.w	#$FBFF,d5
	NextInstStat2

I59					;EOR - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d7
	eor.b	d7,d0
	NextInstStat

I5A					;+ NOP
	NextInstStat2

I5B					;+ LSR,EOR - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I5C					;+ NOP - Absolute
	addq.l	#2,a6
	NextInstStat2

I5D					;EOR - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	move.b	0(a0,d7.l),d7
	eor.b	d7,d0
	NextInstStat

I5E					;LSR - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I5F					;+ LSR,EOR - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	lsr.b	#1,d6
	scs	d4			;C
	move.b	d6,(a2)
	eor.b	d6,d0
	NextInstStat

I60					;RTS
	cmp.l	a1,a5
	bls.s	I60a
	move.b	1(a1),-(sp)
	move.w	(sp)+,d7
	move.b	(a1)+,d7
	addq.l	#1,a1
	lea	1(a0,d7.l),a6
	NextInstStat2
I60a	rts

I61					;ADC - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	move.b	0(a0,d7.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I62					;???
	NextInstStat2

I63					;+ ROR,ADC - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I64					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I65					;ADC - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I66					;ROR - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	scs	d4			;C
	move.w	d0,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I67					;+ ROR,ADC - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I68					;PLA
	move.b	(a1)+,d0
	NextInstStat

I69					;ADC - Immediate
	move.b	(a6)+,d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I6A					;ROR - Accumulator
	neg.b	d4			;C
	roxr.b	#1,d0
	scs	d4			;C
	NextInstStat

I6B					;+ AND,ROR - Immediate
	and.b	(a6)+,d0
	neg.b	d4			;C
	roxr.b	#1,d0
	scs	d4			;C
	NextInstStat

I6C					;JMP - Indirect
	move.b	1(a6),-(sp)
	move.w	(sp)+,d7
	move.b	(a6),d7
	lea	0(a0,d7.l),a6
	move.b	1(a6),-(sp)
	move.w	(sp)+,d7
	move.b	(a6),d7
	lea	0(a0,d7.l),a6
	NextInstStat2

I6D					;ADC - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I6E					;ROR - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I6F					;+ ROR,ADC - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I70					;BVS
	move.b	(a6)+,d7
	tst.b	d5			;V
	beq.s	I70a
	ext.w	d7
	adda.w	d7,a6
I70a
	NextInstStat2

I71					;ADC - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I72					;???
	NextInstStat2

I73					;+ ROR,ADC - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I74					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I75					;ADC - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.b	0(a0,d6.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I76					;ROR - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I77					;+ ROR,ADC - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I78					;SEI
	ori.w	#$0400,d5
	NextInstStat2

I79					;ADC - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I7A					;+ NOP
	NextInstStat2

I7B					;+ ROR,ADC - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I7C					;???
	addq.l	#2,a6
	NextInstStat2

I7D					;ADC - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	move.b	0(a0,d7.l),d6
	neg.b	d4			;C
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I7E					;ROR - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	scs	d4			;C
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

I7F					;+ ROR,ADC - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	neg.b	d4			;C
	roxr.b	#1,d6
	move.b	d6,(a2)
	DecimalMode1
	scs	d4			;C
	svs	d5			;V
	NextInstStat

I80					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I81					;STA - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	MMU2	I81b
	move.b	d0,0(a0,d7.l)
	NextInstStat2
I81b
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d0,d6
	_OUTPUT2

I82					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I83					;+ CLRX - (Ind,X)
	move.b	(a6)+,d6
	tst.b	d1			;X
	bne.s	I83a
	MovepInd
	MMU2	I83b
	clr.b	0(a0,d7.l)
I83a
	NextInstStat2
I83b
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	moveq	#$00,d6
	_OUTPUT2

I84					;STY - Zero Page
	move.b	(a6)+,d6
	move.b	d2,0(a0,d6.l)
	NextInstStat2

I85					;STA - Zero Page
	move.b	(a6)+,d6
	move.b	d0,0(a0,d6.l)
	NextInstStat2

I86					;STX - Zero Page
	move.b	(a6)+,d6
	move.b	d1,0(a0,d6.l)
	NextInstStat2

I87					;+ STAX - Zero Page
	move.b	(a6)+,d6
	move.b	d0,d7			;A
	and.b	d1,d7			;X
	move.b	d7,0(a0,d6.l)
	NextInstStat2

I88					;DEY
	subq.b	#1,d2
	move.w	d2,d3			;N & Z
	NextInst

I89					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

I8A					;TXA
	move.b	d1,d0
	NextInstStat

I8B					;+ MXA - Immediate
	ori.b	#$fe,d0
	and.b	(a6)+,d0
	and.b	d1,d0
	NextInstStat2

I8C					;STY - Absolute
	MovepAbs
	MMU2	I8Cb
	move.b	d2,0(a0,d7.l)
	NextInstStat2
I8Cb
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d2,d6
	_OUTPUT2

I8D					;STA - Absolute
	MovepAbs
	MMU2	I8Db
	move.b	d0,0(a0,d7.l)
	NextInstStat2
I8Db
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d0,d6
	_OUTPUT2

I8E					;STX - Absolute
	MovepAbs
	MMU2	I8Eb
	move.b	d1,0(a0,d7.l)
	NextInstStat2
I8Eb
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d1,d6
	_OUTPUT2

I8F					;+ STAX - Absolute
	MovepAbs
	MMU2	I8Fb
	move.b	d0,d6
	and.b	d1,d6
	move.b	d6,0(a0,d7.l)
	NextInstStat2
I8Fb
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d0,d6
	and.b	d1,d6
	_OUTPUT2

I90					;BCC
	move.b	(a6)+,d7
	tst.b	d4
	bne.s	I90a
	ext.w	d7
	adda.w	d7,a6
I90a
	NextInstStat2

I91					;STA - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	MMU2	I91b
	move.b	d0,0(a0,d7.l)
	NextInstStat2
I91b
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d0,d6
	_OUTPUT2

I92					;???
	NextInstStat2

I93					;+ STAX21 - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	MMU2	I93b
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	move.b	d6,0(a0,d7.l)
	NextInstStat2
I93b
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	_OUTPUT2

I94					;STY - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.b	d2,0(a0,d6.l)
	NextInstStat2

I95					;STA - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.b	d0,0(a0,d6.l)
	NextInstStat2

I96					;STX - Zero Page,Y
	move.b	(a6)+,d6
	add.b	d2,d6			;Y
	move.b	d1,0(a0,d6.l)
	NextInstStat2

I97					;+ STAX - Zero Page,Y
	move.b	(a6)+,d6
	add.b	d2,d6
	move.b	d0,d7			;A
	and.b	d1,d7			;X
	move.b	d7,0(a0,d6.l)
	NextInstStat2

I98					;TYA
	move.b	d2,d0
	NextInstStat

I99					;STA - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	MMU2	I99b
	move.b	d0,0(a0,d7.l)
	NextInstStat2
I99b
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d0,d6
	_OUTPUT2

I9A					;TXS
	move.w	#$0100,d7
	move.b	d1,d7
	lea	1(a0,d7.l),a1
	NextInstStat2

I9B					;+ STAX21SP - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	MMU2	I9Bb
	lea	0(a0,d7.l),a2
	move.w	#$0100,d7
	move.b	d0,d7
	and.b	d1,d7
	lea	1(a0,d7.l),a1
	andi.b	#$21,d7
	move.b	d7,(a2)
	NextInstStat2
I9Bb
	SetAStatus
	move.l	d7,a2
	move.w	#$0100,d7
	move.b	d0,d7
	and.b	d1,d7
	lea	1(a0,d7.l),a1
	move.w	d6,d7
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	_OUTPUT2

I9C					;+ STAY21 - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	MMU2	I9Cb
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d2,d6
	move.b	d6,0(a0,d7.l)
	NextInstStat2
I9Cb
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d2,d6
	_OUTPUT2

I9D					;STA - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	MMU2	I9Db
	move.b	d0,0(a0,d7.l)
	NextInstStat2
I9Db
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	move.b	d0,d6
	_OUTPUT2

I9E					;+ STAX21 - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	MMU2	I9Eb
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	move.b	d6,0(a0,d7.l)
	NextInstStat2
I9Eb
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	_OUTPUT2
	NextInstStat2

I9F					;+ STAX21 - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	MMU2	I9Fb
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	move.b	d6,0(a0,d7.l)
	NextInstStat2
I9Fb
	SetAStatus
	move.l	d7,a2
	move.w	d6,d7
	moveq	#$21,d6
	and.b	d0,d6
	and.b	d1,d6
	_OUTPUT2

IA0					;LDY - Immediate
	move.b	(a6)+,d2
	move.w	d2,d3			;N & Z
	NextInst

IA1					;LDA - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	move.b	0(a0,d7.l),d0
	NextInstStat

IA2					;LDX - Immediate
	move.b	(a6)+,d1
	move.w	d1,d3			;N & Z
	NextInst

IA3					;+ LDAX - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	move.b	0(a0,d7.l),d0
	move.b	d0,d1
	NextInstStat

IA4					;LDY - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d2
	move.w	d2,d3			;N & Z
	NextInst

IA5					;LDA - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d0
	NextInstStat

IA6					;LDX - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d1
	move.w	d1,d3			;N & Z
	NextInst

IA7					;+ LDAX - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d0
	move.b	d0,d1
	NextInstStat

IA8					;TAY
	move.b	d0,d2
	NextInstStat

IA9					;LDA - Immediate
	move.b	(a6)+,d0
	NextInstStat

IAA					;TAX
	move.b	d0,d1
	NextInstStat

IAB					;+ LDAX - Immediate
	move.b	(a6)+,d0
	move.b	d0,d1
	NextInstStat

IAC					;LDY - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d2
	move.w	d2,d3			;N & Z
	NextInst

IAD					;LDA - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d0
	NextInstStat

IAE					;LDX - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d1
	move.w	d1,d3			;N & Z
	NextInst

IAF					;+ LDAX - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d0
	move.b	d0,d1
	NextInstStat

IB0					;BCS
	move.b	(a6)+,d7
	tst.b	d4
	beq.s	IB0a
	ext.w	d7
	adda.w	d7,a6
IB0a
	NextInstStat2

IB1					;LDA - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d0
	NextInstStat

IB2					;???
	NextInstStat2

IB3					;+ LDAX - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d0
	move.b	d0,d1
	NextInstStat

IB4					;LDY - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.b	0(a0,d6.l),d2
	move.w	d2,d3			;N & Z
	NextInst

IB5					;LDA - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.b	0(a0,d6.l),d0
	NextInstStat

IB6					;LDX - Zero Page,Y
	move.b	(a6)+,d6
	add.b	d2,d6			;Y
	move.b	0(a0,d6.l),d1
	move.w	d1,d3			;N & Z
	NextInst

IB7					;+ LDAX - Zero Page,Y
	move.b	(a6)+,d6
	add.b	d2,d6			;Y
	move.b	0(a0,d6.l),d0
	move.b	d0,d1
	NextInstStat

IB8					;CLV
	sub.b	d5,d5			;V
	NextInstStat2

IB9					;LDA - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d0
	NextInstStat

IBA					;TSX
	move.w	a1,d1
	sub.w	a0,d1
	andi.w	#$00ff,d1
	subq.b	#1,d1
	move.w	d1,d3			;N & Z
	NextInst

IBB					;+ SPMAXSP - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d6
	move.w	a1,d7
	sub.w	a0,d7
	subq.b	#1,d7
	and.b	d7,d6
	move.b	d6,d0
	move.b	d6,d1
	move.w	#$0100,d7
	move.b	d6,d7
	lea	1(a0,d7.l),a1
	NextInstStat

IBC					;LDY - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	move.b	0(a0,d7.l),d2
	move.w	d2,d3			;N & Z
	NextInst

IBD					;LDA - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	move.b	0(a0,d7.l),d0
	NextInstStat

IBE					;LDX - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d1
	move.w	d1,d3			;N & Z
	NextInst

IBF					;+ LDAX - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d0
	move.b	d0,d1
	NextInstStat

IC0					;CPY - Immediate
	move.w	d2,d3
	sub.b	(a6)+,d3		;N & Z
	scc	d4			;C
	NextInst

IC1					;CMP - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	move.w	d0,d3			;N & Z
	sub.b	0(a0,d7.l),d3
	scc	d4			;C
	NextInst

IC2					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

IC3					;+ DEC,CMP - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

IC4					;CPY - Zero Page
	move.b	(a6)+,d6
	move.w	d2,d3			;N & Z
	sub.b	0(a0,d6.w),d3
	scc	d4			;C
	NextInst

IC5					;CMP - Zero Page
	move.b	(a6)+,d6
	move.w	d0,d3			;N & Z
	sub.b	0(a0,d6.w),d3
	scc	d4			;C
	NextInst

IC6					;DEC - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

IC7					;+ DEC,CMP - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

IC8					;INY
	addq.b	#1,d2
	move.w	d2,d3			;N & Z
	NextInst

IC9					;CMP - Immediate
	move.w	d0,d3
	sub.b	(a6)+,d3		;N & Z
	scc	d4			;C
	NextInst

ICA					;DEX
	subq.b	#1,d1
	move.w	d1,d3			;N & Z
	NextInst

ICB					;+ AXM - Immediate
	and.b	d0,d1
	sub.b	(a6)+,d1
	move.w	d1,d3			;N & Z
	NextInst

ICC					;CPY - Absolute
	MovepAbs
	move.w	d2,d3			;N & Z
	sub.b	0(a0,d7.l),d3
	scc	d4			;C
	NextInst

ICD					;CMP - Absolute
	MovepAbs
	move.w	d0,d3			;N & Z
	sub.b	0(a0,d7.l),d3
	scc	d4			;C
	NextInst

ICE					;DEC - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

ICF					;+ DEC,CMP - Absolute
	MovepAbs
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

ID0					;BNE
	move.b	(a6)+,d7
	tst.b	d3			;Z
	beq.s	ID0a
	ext.w	d7
	adda.w	d7,a6
ID0a
	NextInst
	IfStatus
	move.b	(a6)+,d7
	tst.b	d0
	beq.s	ID0b
	ext.w	d7
	adda.w	d7,a6
ID0b
	NextInstStat2

ID1					;CMP - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	move.w	d0,d3
	sub.b	0(a0,d7.l),d3		;N & Z
	scc	d4			;C
	NextInst

ID2					;???
	NextInstStat2

ID3					;+ DEC,CMP - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

ID4					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

ID5					;CMP - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	move.w	d0,d3
	sub.b	0(a0,d6.l),d3		;N & Z
	scc	d4			;C
	NextInst

ID6					;DEC - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

ID7					;+ DEC,CMP - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

ID8					;CLD
	andi.w	#$F7FF,d5		;D
	tst.w	d4			;D+
	bpl.s	ID8a
	move.l	#$FFFF0000,a2
	add.l	a2,a4
	add.l	a2,a5
	andi.w	#$7fff,d4
	jmp	ID8a(pc,a2.l)
ID8a
	NextInstStat2

ID9					;CMP - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.w	d0,d3
	sub.b	0(a0,d7.l),d3		;N & Z
	scc	d4			;C
	NextInst

IDA					;+ NOP
	NextInstStat2

IDB					;+ DEC,CMP - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

IDC					;+ NOP - Absolute
	addq.l	#2,a6
	NextInstStat2

IDD					;CMP - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	move.w	d0,d3
	sub.b	0(a0,d7.l),d3		;N & Z
	scc	d4			;C
	NextInst

IDE					;DEC - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

IDF					;+ DEC,CMP - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	subq.b	#1,d6
	move.b	d6,(a2)
	move.w	d0,d3			;N & Z
	sub.b	d6,d3
	scc	d4			;C
	NextInst

IE0					;CPX - Immediate
	move.w	d1,d3
	sub.b	(a6)+,d3		;N & Z
	scc	d4			;C
	NextInst

IE1					;SBC - (Indirect,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	move.b	0(a0,d7.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IE2					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

IE3					;+ INC,SBC - (Ind,X)
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	MovepInd
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IE4					;CPX - Zero Page
	move.b	(a6)+,d6
	move.w	d1,d3
	sub.b	0(a0,d6.l),d3		;N & Z
	scc	d4			;C
	NextInst

IE5					;SBC - Zero Page
	move.b	(a6)+,d6
	move.b	0(a0,d6.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IE6					;INC - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

IE7					;+ INC,SBC - Zero Page
	move.b	(a6)+,d6
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IE8					;INX
	addq.b	#1,d1
	move.w	d1,d3			;N & Z
	NextInst

IE9					;SBC - Immediate
	move.b	(a6)+,d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IEA					;NOP
	NextInstStat2

IEB					;+ SBC - Immediate
	move.b	(a6)+,d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IEC					;CPX - Absolute
	MovepAbs
	move.w	d1,d3
	sub.b	0(a0,d7.l),d3		;N & Z
	scc	d4			;C
	NextInst

IED					;SBC - Absolute
	MovepAbs
	move.b	0(a0,d7.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IEE					;INC - Absolute
	MovepAbs
	MMU2	IEEb
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst
IEEb
	INPUT
	addq.b	#1,d6
	move.w	d6,d3			;N & Z
	_OUTPUT

IEF					;+ INC,SBC - Absolute
	MovepAbs
	MMU2	IEFb
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat
IEFb
	INPUT
	addq.b	#1,d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	move.w	d0,d3			;N & Z
	_OUTPUT

IF0					;BEQ
	move.b	(a6)+,d7
	tst.b	d3
	bne.s	IF0a
	ext.w	d7
	adda.w	d7,a6
IF0a
	NextInst
	IfStatus
	move.b	(a6)+,d7
	tst.b	d0
	bne.s	IF0b
	ext.w	d7
	adda.w	d7,a6
IF0b
	NextInstStat2

IF1					;SBC - (Indirect),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IF2					;???
	NextInstStat2

IF3					;+ INC,SBC - (Ind),Y
	move.b	(a6)+,d6
	MovepInd
	add.w	d2,d7			;Y
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IF4					;+ NOP - Zero Page
	addq.l	#1,a6
	NextInstStat2

IF5					;SBC - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6
	move.b	0(a0,d6.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IF6					;INC - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst

IF7					;+ INC,SBC - Zero Page,X
	move.b	(a6)+,d6
	add.b	d1,d6			;X
	lea	0(a0,d6.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IF8					;SED
	ori.w	#$0800,d5		;D
	tst.w	d4			;D+
	bmi.s	IF8a
	move.l	#$00010000,a2
	add.l	a2,a4
	add.l	a2,a5
	ori.w	#$8000,d4
	jmp	IF8a(pc,a2.l)
IF8a
	NextInstStat2

IF9					;SBC - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	move.b	0(a0,d7.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IFA					;+ NOP
	NextInstStat2

IFB					;+ INC,SBC - Absolute,Y
	MovepAbs
	add.w	d2,d7			;Y
	MMU2	IFBb
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat
IFBb
	INPUT
	addq.b	#1,d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	move.w	d0,d3			;N & Z
	_OUTPUT

IFC					;+ NOP - Absolute
	addq.l	#2,a6
	NextInstStat2

IFD					;SBC - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	move.b	0(a0,d7.l),d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat

IFE					;INC - Absolute,X
	MovepAbs
	add.w	d1,d7
	MMU2	IFEb
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.w	d6,d3			;N & Z
	move.b	d6,(a2)
	NextInst
IFEb
	INPUT
	addq.b	#1,d6
	move.w	d6,d3			;N & Z
	_OUTPUT

IFF					;+ INC,SBC - Absolute,X
	MovepAbs
	add.w	d1,d7			;X
	MMU2	IFFb
	lea	0(a0,d7.l),a2
	move.b	(a2),d6
	addq.b	#1,d6
	move.b	d6,(a2)
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	NextInstStat
IFFb
	INPUT
	addq.b	#1,d6
	not.b	d4
	neg.b	d4			;C
	DecimalMode2
	scc	d4			;C
	svs	d5			;V
	move.w	d0,d3			;N & Z
	_OUTPUT

IEND
*-----------------------------------------------------------------------*


*=======================================================================*
*									*
*	BSS SECTION							*
*									*
*=======================================================================*
	section	.bss,bss
*-----------------------------------------------------------------------*
VolumeTable	ds.l	($1000)/4
Enve1		ds.l	(env_SIZEOF+3)/4
Enve2		ds.l	(env_SIZEOF+3)/4
Enve3		ds.l	(env_SIZEOF+3)/4
Chan1		ds.l	(ch_SIZEOF+3)/4
Chan2		ds.l	(ch_SIZEOF+3)/4
Chan3		ds.l	(ch_SIZEOF+3)/4
Chan4		ds.l	(ch4_SIZEOF+3)/4
Display		ds.l	(dd_SIZEOF+3)/4
AttackDecay	ds.l	($800)/4
SustainRelease	ds.l	($800)/4
SustainTable	ds.l	$10
AttackTable	ds.l	$100

_CiabBase	ds.l	1
_PlaySidBase	ds.l	1

; reSID data areas for three SID instances
residData      ds.b    resid_SIZEOF
residData2     ds.b    resid_SIZEOF
residData3     ds.b    resid_SIZEOF

*-----------------------------------------------------------------------*


		include	external.asm

*-----------------------------------------------------------------------*
*
* reSID-68k 
*
*-----------------------------------------------------------------------*

        section    .text,code

  ifd __VASM
    ; Turn on optimization for reSID
    opt o+
    ; Disable "move.l to moveq" optimization, it may add "swap" which is
    ; pOEP-only
    opt o4-
  endif

        include resid-68k.s

        section    .text,code


@SetVolume 
    move    d0,psb_Volume(a6)
    bsr     isResidActive
    bne     .1
    rts
.1
    * Adjust sample volume    
    push    d0
    move.l  psb_reSID(a6),a0
    jsr     sid_set_volume

    move.l  (sp),d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_set_volume
    
    pop     d0
    move.l  psb_reSID3(a6),a0
    jmp     sid_set_volume
    
* Turns the reSID filters on and off.
* In:
*   d0 = 0 or 1, disable or enable the filter
*   d1 = 0 or 1, disable or enable the external filter
@SetResidFilter
  if DEBUG
    and.l   #$ff,d0
    and.l   #$ff,d1
    DPRINT  "SetResidFilter internal=%ld external=%ld"
  endif
    push    d1
    push    d0
    
    ;move.l  (sp),d0
    move.l  psb_reSID(a6),a0
    jsr     sid_enable_filter

    move.l  (sp),d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_enable_filter

    move.l  (sp)+,d0
    move.l  psb_reSID3(a6),a0
    jsr     sid_enable_filter

    move.l  (sp),d0
    move.l  psb_reSID(a6),a0
    jsr     sid_enable_external_filter

    move.l  (sp),d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_enable_external_filter

    move.l  (sp)+,d0
    move.l  psb_reSID3(a6),a0
    jsr     sid_enable_external_filter
    rts

* Sets the volume boost factor for reSID.
* In:
*   d0 = reSID volume boost, 0 or 1 do nothing, 2x is double, 4x is quadruple
@SetResidBoost:
    DPRINT  "SetResidBoost %ld"
 
    push    d0
    move.l  psb_reSID(a6),a0
    jsr     sid_set_output_boost

    move.l  (sp),d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_set_output_boost

    move.l  (sp)+,d0
    move.l  psb_reSID3(a6),a0
    jmp     sid_set_output_boost


* Out:
*   d0 = buffer length in samples
*   d1 = period value used
*   a0 = audio buffer pointer sid
*   a1 = same as a0 or audio buffer pointer for sid 2
@GetResidAudioBuffer
    move.l  sidBufferAHi,a0
    move.l  a0,a1
    tst.w   psb_Sid2Address(a6)
    beq     .1
    move.l  sid2BufferAHi,a1
.1
    move.l  psb_SamplesPerFrame(a6),d0
    lsr.l   #7,d0
    move.l  #PAULA_PERIOD,d1
    rts


* Initialize reSID, safe to call whenever.
* In:
*    a6 = PlaySID base
initResid:
    DPRINT  "initResid"
    movem.l d1-a6,-(sp)
    move.l  psb_reSID(a6),a0
    jsr     sid_constructor
    move.l  psb_reSID2(a6),a0
    jsr     sid_constructor
    move.l  psb_reSID3(a6),a0
    jsr     sid_constructor

    moveq   #0,d0
    move    psb_ResidMode(a6),d0
    DPRINT  "residmode=%ld"

    * Map psb_ResidMode into reSID mode

 if ENABLE_14BIT
    tst.l   psb_AhiMode(a6)
    bne     .ahi
    ; ---------------------------------
    ; Paula gets 14-bit output
    DPRINT  "Paula"
    moveq   #SAMPLING_METHOD_OVERSAMPLE2x14,d1
    cmp     #REM_OVERSAMPLE2,d0
    beq.b   .go
    moveq   #SAMPLING_METHOD_OVERSAMPLE3x14,d1
    cmp     #REM_OVERSAMPLE3,d0
    beq.b   .go
    moveq   #SAMPLING_METHOD_OVERSAMPLE4x14,d1
    cmp     #REM_OVERSAMPLE4,d0
    beq.b   .go
    ; ---------------------------------
    moveq   #SAMPLING_METHOD_INTERPOLATE14,d1
    cmp     #REM_INTERPOLATE,d0
    beq.b   .go
    ; ---------------------------------
    ; Default mode
    moveq   #SAMPLING_METHOD_SAMPLE_FAST14,d1
 else
    moveq   #SAMPLING_METHOD_SAMPLE_FAST8,d1
 endif
    bra     .go
.ahi
    ; ---------------------------------
    ; AHI gets 16-bit output
    DPRINT  "AHI"
    moveq   #SAMPLING_METHOD_OVERSAMPLE2x16,d1
    cmp     #REM_OVERSAMPLE2,d0
    beq.b   .go
    moveq   #SAMPLING_METHOD_OVERSAMPLE3x16,d1
    cmp     #REM_OVERSAMPLE3,d0
    beq.b   .go
    moveq   #SAMPLING_METHOD_OVERSAMPLE4x16,d1
    cmp     #REM_OVERSAMPLE4,d0
    beq.b   .go
    ; ---------------------------------
    ; Default mode for AHI
    moveq   #SAMPLING_METHOD_SAMPLE_FAST16,d1
.go
    ; ---------------------------------

 if DEBUG
    moveq   #0,d0
    move.b  d1,d0
    DPRINT  "sampling method=%ld"
 endif
    * d1 = sampling method
    move.l  #985248,d0
    move.l  #PAULA_PERIOD,d2
    pushm   d0-d2
    move.l  psb_reSID(a6),a0
    jsr     sid_set_sampling_parameters_paula
    move.l  a1,clockRoutine

 if DEBUG
    push    d0
    move.l  a1,d0
    DPRINT  "clockRoutine=%lx"
    pop     d0
 endif

    movem.l (sp),d0-d2
    move.l  psb_reSID2(a6),a0
    jsr     sid_set_sampling_parameters_paula
    
    popm    d0-d2
    move.l  psb_reSID3(a6),a0
    jsr     sid_set_sampling_parameters_paula

    * Initial value for cyclesPerFrame, 50 Hz
    tst.w   psb_TimerConstB(a6)
    bne     .2
    move.w  #28419/2,psb_TimerConstB(a6)
.2  bsr     calcSamplesAndCyclesPerFrameFromCIATicks

    move.l  psb_reSID(a6),a0
    jsr     sid_reset
    move.l  psb_reSID2(a6),a0
    jsr     sid_reset
    move.l  psb_reSID3(a6),a0
    jsr     sid_reset

    ; ---------------------------------
    ; Determine chip model - operating mode
    moveq   #CHIP_MODEL_MOS6581,d0
    cmp.w   #OM_RESID_6581,psb_OperatingMode(a6)
    beq.b   .1
    moveq   #CHIP_MODEL_MOS8580,d0
    cmp.w   #OM_RESID_8580,psb_OperatingMode(a6)
    beq.b   .1
    cmp.w   #OM_RESID_AUTO,psb_OperatingMode(a6)
    bne     .1
    ; Determine chip model - based on header
    moveq   #CHIP_MODEL_MOS6581,d0
    cmp     #%01,psb_HeaderChipVersion(a6)
    beq     .1
    moveq   #CHIP_MODEL_MOS8580,d0
    cmp     #%10,psb_HeaderChipVersion(a6)
    beq     .1
    * Default fallback
    moveq   #CHIP_MODEL_MOS6581,d0
.1
    push    d0
    move.l  psb_reSID(a6),a0
    jsr     sid_set_chip_model
    move.l  (sp),d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_set_chip_model
    pop     d0
    move.l  psb_reSID3(a6),a0
    jsr     sid_set_chip_model
    ; ---------------------------------

    * Default external filter: no external filter
    moveq   #0,d0
    move.l  psb_reSID(a6),a0
    jsr     sid_enable_external_filter
    DPRINT  "extfilter disabled by default"

    moveq   #0,d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_enable_external_filter

    moveq   #0,d0
    move.l  psb_reSID3(a6),a0
    jsr     sid_enable_external_filter

    * Default boost: no boost
    moveq   #0,d0
    move.l  psb_reSID(a6),a0
    jsr     sid_set_output_boost
    moveq   #0,d0
    move.l  psb_reSID2(a6),a0
    jsr     sid_set_output_boost
    moveq   #0,d0
    move.l  psb_reSID3(a6),a0
    jsr     sid_set_output_boost

    movem.l (sp)+,d1-a6
    rts

* Assuming Paula playback period 128, given the amount of CIA
* timer ticks, calculates how many audio samples and SID cycles
* the amount of ticks corresponds to. This defines both the
* audio interrupt interval and timing for the playback.
* May be called from interrupt.
* in:
*   a6 = PlaySidBase
calcSamplesAndCyclesPerFrameFromCIATicks:
    cmp.w   #OM_RESID_6581,psb_OperatingMode(a6)
    beq.b   .go
    cmp.w   #OM_RESID_8580,psb_OperatingMode(a6)
    beq.b   .go
    cmp.w   #OM_RESID_AUTO,psb_OperatingMode(a6)
    beq.b   .go
    rts
.go
      movem.l d0-d2/a0,-(sp)
; Freq in Hz =  709379.1 / (28419/2) = 49.9228
; samples per frame = 27710.1171875 /(709379.1 / (28419/2) )
; samples per frame = (27710.1171875 * (28419/2)) / 709379.1 
; r/(c/t) -> r*t/c -> (r/c)*t
; 27710.1171875 / 709379.1 = 0.03906249449342389704 
; 0.03906249449342389704*(1<<10) = 39.99999436126607056791
* 0.03906249449342389704*(1<<7)  = 4.99999929515825882112 = 5!
; cia ticks * 40 = samples per frame 22.10 FP
; cia ticks * 5  = samples per frame 25.7 FP

    * Safety check: check if higher than 600 Hz in case of spurious
    * or NULL values, and revert to 50 Hz. 1178 = 600 Hz
    move.w  psb_TimerConstB(a6),d0   
    cmp.w   #1170,d0
    bhi.b   .1
    move    #28419/2,d0
.1
    mulu.w  #5,d0
    * d0 = samples per frame 25.7 FP
    move.l  d0,psb_SamplesPerFrame(a6)

    ;cycles_per_sample = clock_freq / sample_freq * (1 << FIXP_SHIFT) + 0.5);
    
    * Calculate how many cycles are needed per frame
    * samples per frame is 25.7 FP 
    * sid_cycles_per_sample is 16.16 FP
    move.l  psb_reSID(a6),a0
    move.l  sid_cycles_per_sample(a0),d1
    bsr     mulu_64
    * Shift result by 16+7 for correct FP
    moveq   #16+7,d2
    lsr.l   d2,d1
    moveq   #32-16-7,d2
    lsl.l   d2,d0
    or.l    d1,d0    
 REM
    * 64-bit instructions avoided
    mulu.l  sid_cycles_per_sample(a0),d1:d0
    divu.l  #1<<(16+7),d1:d0
 EREM
    move.l  d0,cyclesPerFrame
    movem.l (sp)+,d0-d2/a0
    rts


;umult64 - mulu.l d0,d0:d1
;by Meynaf/English Amiga Board
mulu_64
     move.l d2,-(a7)
     move.w d0,d2
     mulu d1,d2
     move.l d2,-(a7)
     move.l d1,d2
     swap d2
     move.w d2,-(a7)
     mulu d0,d2
     swap d0
     mulu d0,d1
     mulu (a7)+,d0
     add.l d2,d1
     moveq #0,d2
     addx.w d2,d2
     swap d2
     swap d1
     move.w d1,d2
     clr.w d1
     add.l (a7)+,d1
     addx.l d2,d0
     move.l (a7)+,d2
 	rts



* Allocate audio buffers
* Two 8-bit buffers per 14-bit channel per SID
* Times two for double buffering
* Times three for three SIDs
RESID_BUFFERS_SIZE=(SAMPLE_BUFFER_SIZE)*2*2*3

* Out:
*    d0 = 0: out of mem, non-1: ok
allocResidMemory:
    push   a6
    bsr     isResidActive
    beq     .y

    move.l  a6,a0
    move.l  #RESID_BUFFERS_SIZE,d0
  
    move.l  #MEMF_CHIP!MEMF_CLEAR,d1
    tst.l   psb_AhiMode(a6)
    beq     .2
    * AHI buffers can be in public mem
    move.l  #MEMF_PUBLIC!MEMF_CLEAR,d1
.2
    move.l  4.w,a6
    jsr     _LVOAllocMem(a6)
    tst.l   d0
    beq     .x

    move.l  d0,a0
    move.l  a0,bufferMemoryPtr
    move.l  a0,a2
    lea     sidBufferAHi(pc),a1
    moveq   #12-1,d0    * set 12 bufs
.1  move.l  a0,(a1)+
    lea     SAMPLE_BUFFER_SIZE(a0),a0
    dbf     d0,.1

    * Also set up ahi sounds, these are word buffers
    move.l  #SAMPLE_BUFFER_SIZE*2,d0
    lea     ahiSound1(pc),a0
    move.l  a2,4(a0)
    move.l  d0,8(a0)
    add.l   d0,a2
    lea     ahiSound2(pc),a0
    move.l  a2,4(a0)
    move.l  d0,8(a0)
    add.l   d0,a2
    lea     ahiSound3(pc),a0
    move.l  a2,4(a0)
    move.l  d0,8(a0)
    add.l   d0,a2
    lea     ahiSound4(pc),a0
    move.l  a2,4(a0)
    move.l  d0,8(a0)
    add.l   d0,a2
    lea     ahiSound5(pc),a0
    move.l  a2,4(a0)
    move.l  d0,8(a0)
    add.l   d0,a2
    lea     ahiSound6(pc),a0
    move.l  a2,4(a0)
    move.l  d0,8(a0)

.y  moveq   #1,d0
.x  tst.l   d0
    pop     a6
    rts

resetResid:
    move.l  psb_reSID(a6),a0
    jsr     sid_reset
    move.l  psb_reSID2(a6),a0
    jsr     sid_reset
    move.l  psb_reSID3(a6),a0
    jmp     sid_reset


freeResidMemory:
    push    a6
    lea     bufferMemoryPtr(pc),a2
    tst.l   (a2)
    beq.b   .y
    move.l  (a2),a1
    clr.l   (a2)
    move.l  #RESID_BUFFERS_SIZE,d0
    move.l  4.w,a6
    jsr     _LVOFreeMem(a6)
.y  pop     a6
    rts

createResidWorkerTask:
    DPRINT  "createResidWorkerTask"
    movem.l d0-a6,-(sp)
    tst.l   residWorkerTask
    bne     .x
    move.l  a6,a5

    move.l  4.w,a6
    sub.l   a1,a1
    jsr     _LVOFindTask(a6)
    move.l  d0,mainTask

    moveq   #0,d0
    moveq   #SIGF_SINGLE,d1
    jsr     _LVOSetSignal(a6)

    move.l  psb_DOSBase(a5),a6
    move.l  #.tags,d1
    jsr     _LVOCreateNewProcTagList(a6)

    * Wait here until the task is fully running
    moveq   #SIGF_SINGLE,d0
    jsr     _LVOWait(a6)
.x
    movem.l (sp)+,d0-a6
    rts

.tags
    dc.l    NP_Entry,residWorkerEntryPoint
    dc.l    NP_Name,.workerTaskName
    dc.l    TAG_END

.workerTaskName
    dc.b    "reSID",0
    even

stopResidWorkerTask:    
    DPRINT  "stopResidWorkerTask"    
    movem.l d0-a6,-(sp)
    tst.l   residWorkerTask
    beq     .done
    move.l  4.w,a6
    moveq   #0,d0
    moveq   #SIGF_SINGLE,d1
    jsr     _LVOSetSignal(a6)

    ; Send a break to the worker
    move.l  residWorkerTask(pc),a1
    move.l  #SIGBREAKF_CTRL_C,d0
    jsr     _LVOSignal(a6)

    ; Wait for confirmation
    moveq   #SIGF_SINGLE,d0
    jsr     _LVOWait(a6)

 if COUNTERS

    jsr     sid_get_counters
* a2 = array
* d3 = count - 1
    move.l  a2,a0
    move    d3,d0
    addq    #1,d0
    ;bsr     .sort
    
    jsr     sid_get_counters
* a2 = array
* d3 = count - 1

    lea     -20(sp),sp
.cl
    * 4char id
    move.l  8(a2),(sp)
    clr.b   4(sp)
    move.l  sp,d0

    * Count
    ;move.l  (a2),d1
    ;move.l  4(a2),d2
    move.l  4(a2),d1
    add     #12,a2

    tst.l   d1
    beq     .s
    DPRINT  "%s=%08.8lx"
.s
    dbf     d3,.cl
   
    lea     20(sp),sp
 endif

.done 
    movem.l (sp)+,d0-a6
    rts

 if COUNTERS
***************************************************************************
* Insertion sort 
*
* in:
*  a0 = array of string pointers
*  d0 = length of the array, unsigned 16-bit
* out:
*  a0 = sorted array
.sort
	cmp	#1,d0
	bls.b	.x
	movem.l d1/d2/d3/d6/d7/a1/a2,-(sp)
	moveq	#1,d1 
.sortLoopOuter
	move	d1,d2
.sortLoopInner
	move	d2,d3
	;lsl	#2,d3   * 4
    mulu    #12,d3  * element is 12 bytes
	;movem.l	-12(a0,d3),a1/a2
    lea     -12(a0,d3),a1
    lea     -12+12(a0,d3),a2
.strCmp 
    move.l  4(a1),d6    * counter 1
    move.l  4(a2),d7    * counter 2
;	cmp.l	d6,d7
;	blo.b	.swap
;	tst.b	d6
;	beq.b	.exitLoop
;	tst.b	d7
;	beq.b	.exitLoop
;	cmp.b	d6,d7
;	beq.b	.strCmp
	cmp.l	d6,d7
	bhi.b	.exitLoop
.swap
    ; swap items
    lea     -12(a0,d3),a1
    lea     -12+12(a0,d3),a2
    move.l  (a1),-(sp)
    move.l  4(a1),-(sp)
    move.l  8(a1),-(sp)

    move.l  (a2),(a1)
    move.l  4(a2),4(a1)
    move.l  8(a2),8(a1)

    move.l  (sp)+,8(a2)
    move.l  (sp)+,4(a2)
    move.l  (sp)+,0(a2)

;	movem.l	-12(a0,d3),a1/a2
;	exg	a1,a2
;	movem.l	a1/a2,-12(a0,d3)
	
	subq	#1,d2
;	bra.b 	.sortLoopInner
	bne.b	.sortLoopInner	
.exitLoop
	addq	#1,d1
	cmp 	d0,d1
	bne.b 	.sortLoopOuter
    movem.l (sp)+,d1/d2/d3/d6/d7/a1/a2
.x	rts


 endif


* Playback task
* Not actually used for playback at the moment since 
* the default mode is interrupt playback instead of task playback.
residWorkerEntryPoint
    SPRINT  "task:starting"
    move.l  4.w,a6
    sub.l   a1,a1
    jsr     _LVOFindTask(a6)
    move.l  d0,residWorkerTask

    move.l  _PlaySidBase,a6
    tst.l   psb_AhiMode(a6)
    beq     .notAhi

    bsr     ahiInit
    SPRINT  "task:ahiInit=%ld"
    ; TODO: ERROR case
    tst.l   d0
    beq     .x
    clr.l   psb_AhiBankLeft(a6)
    clr.l   psb_AhiBankRight(a6)
    clr.l   psb_AhiBankMiddle(a6)
    bsr     ahiSwitchAndFillLeftBuffer
    bsr     ahiSwitchAndFillRightBuffer
    bsr     ahiSwitchAndFillMiddleBuffer
	moveq	#AHISF_IMM,d4
    bsr     ahiPlayLeftBuffer
    DPRINT  "task:left=%ld"
	moveq	#AHISF_IMM,d4
    bsr     ahiPlayRightBuffer
    DPRINT  "task:right=%ld"
	moveq	#AHISF_IMM,d4
    bsr     ahiPlayMiddleBuffer
    DPRINT  "task:middle=%ld"
    bra     .continue

.notAhi
    SPRINT  "task:normal init"

 ifne ENABLE_LEV4PLAY 
    move.l  #residLevel1Intr,residLevel4Intr1Data
 else
    move.l  d0,residLevel4Intr1Data
 endif
    * Max softint priority
    move.b  #32,LN_PRI+residLevel1Intr
    * Store this for easy access
    move.l  _PlaySidBase,residLevel1Data

    SPRINT  "task:clear intena+intreq+dmacon"
    ; Stop all 
    move.w  #INTF_AUD0!INTF_AUD1!INTF_AUD2!INTF_AUD3,intena+$dff000
    move.w  #INTF_AUD0!INTF_AUD1!INTF_AUD2!INTF_AUD3,intreq+$dff000
    move.w  #DMAF_AUD0!DMAF_AUD1!DMAF_AUD2!DMAF_AUD3,dmacon+$dff000

 if DEBUG
    move.l  #residLevel1HandlerDebug,residLevel1HandlerPtr
 else
    move.l  #residLevel1Handler,residLevel1HandlerPtr
    tst.w   psb_Debug(a6)
    beq     .1
    move.l  #residLevel1HandlerDebug,residLevel1HandlerPtr
.1
 endif
    SPRINT  "task:SetIntVector"

    lea     residLevel4Intr1,a1
    moveq   #INTB_AUD0,d0		; Allocate Level 4
    move.l  4.w,a6
    jsr     _LVOSetIntVector(a6)
    move.l  d0,oldVecAud0

    move.l  _PlaySidBase,a6

    * CH0 = high 8 bits - full volume
    * CH3 = low 6 bits  - volume 1
    * CH1 = high 8 bits - full volume
    * CH2 = low 6 bits  - volume 1
    move    #PAULA_PERIOD,$a6+$dff000
    move    #PAULA_PERIOD,$b6+$dff000
    move    #PAULA_PERIOD,$c6+$dff000
    move    #PAULA_PERIOD,$d6+$dff000
    
    bsr     residSetVolume
    bsr     switchAndFillBuffer
    bsr     dmawait     * probably not needed

    SPRINT  "task:enable audio interrupt"

  ifne ENABLE_14BIT
    move    #DMAF_SETCLR!DMAF_AUD0!DMAF_AUD1!DMAF_AUD2!DMAF_AUD3,dmacon+$dff000
  else
    move    #DMAF_SETCLR!DMAF_AUD0!DMAF_AUD1,dmacon+$dff000
  endif
   
    move.w  #INTF_SETCLR!INTF_AUD0,intena+$dff000

    ; buffer A now plays
    ; interrupt will be triggered soon to queue the next sample
    ; wait for the interrupt and queue buffer B
    ; fill buffer B
    ; after A has played, B will start
    ; interrupt will be triggered
    ; queue buffer A
    ; fill A
    ; ... etc
.continue
    ; Signal that we're running
    move.l  4.w,a6
    move.l  mainTask(pc),a1
    moveq   #SIGF_SINGLE,d0
    jsr     _LVOSignal(a6)

    SPRINT  "task:active"
.loop
    move.l  4.w,a6
    move.l  #SIGBREAKF_CTRL_C!SIGBREAKF_CTRL_D,d0
    jsr     _LVOWait(a6)
    and.l   #SIGBREAKF_CTRL_C,d0
    bne.b   .x

    SPRINT  "task:signal"

  ifeq ENABLE_LEV4PLAY
    push    a6
    move.l  _PlaySidBase,a6
    bsr     switchAndFillBuffer
    pop     a6
  endif
    bra     .loop

.x
    SPRINT  "task:stopping"

    move.l  _PlaySidBase,a6
    tst.l   psb_AhiMode(a6)
    beq     .notAhi2
    bsr     ahiStop

    SPRINT  "task:ahi stopped"
    
    move.l  4.w,a6
    jsr     _LVOForbid(a6)
    jsr     _LVODisable(a6)
    bra     .continueExit

.notAhi2
    move.l  4.w,a6
    jsr     _LVOForbid(a6)
    jsr     _LVODisable(a6)

    ; First stop audio interrupt, as stopping DMA first would go into
    ; manual mode and start triggering audio interrupts after every word.
    move.w  #INTF_AUD0!INTF_AUD1!INTF_AUD2!INTF_AUD3,intena+$dff000
    move.w  #INTF_AUD0!INTF_AUD1!INTF_AUD2!INTF_AUD3,intreq+$dff000
    move    #$f,dmacon+$dff000
    bsr     residClearVolume

    moveq	#INTB_AUD0,d0
    move.l  oldVecAud0(pc),a1
    jsr     _LVOSetIntVector(a6)
    move.l  d0,oldVecAud0

.continueExit
    clr.l   residWorkerTask

    move.l  mainTask(pc),a1
    moveq   #SIGF_SINGLE,d0
    jsr     _LVOSignal(a6)
    SPRINT  "task:stopped"
    rts

residSetVolume:
  ifne ENABLE_14BIT 
    move    #64,$a8+$dff000 * ch1 left
    move    #1,$d8+$dff000  * ch4 left
    move    #64,$b8+$dff000 * ch2 right
    move    #1,$c8+$dff000  * ch3 right

    tst.w   psb_Sid3Address(a6)
    beq     .no3
    move    #64,$c8+$dff000
.no3

  else
    move    #64,$a8+$dff000
    move    #0,$d8+$dff000
    move    #64,$b8+$dff000
    move    #0,$c8+$dff000   
  endif
    rts

residClearVolume:
    clr     $dff0a8
    clr     $dff0b8
    clr     $dff0c8
    clr     $dff0d8
    rts


;  Interrupt register usage
;  D0 - scratch
;  D1 - scratch (on entry: active
;       interrupts -> equals INTENA & INTREQ)
;  A0 - scratch (on entry: pointer to base of custom chips
;       for fast indexing)
;  A1 - scratch (on entry: Interrupt's IS_DATA pointer)
;  A5 - jump vector register (scratch on call)
;  A6 - Exec library base pointer (scratch on call)
;       all other registers must be preserve
;       Softints must preserve a6

* Level 4 interrupt handler
* In:
*   a0 = custom
*   a1 = is_data
*   a6 = execbase
residLevel4Handler1
    move.w  #INTF_AUD0,intreq(a0)
 ifeq ENABLE_LEV4PLAY
    * a1 = task
    move.l  #SIGBREAKF_CTRL_D,d0
    jmp     _LVOSignal(a6)
 else
    * a1 = residLevel1Intr
    basereg residLevel1Intr,a1
    
    * Check if lev1 is done with the previous frame
    tst.b   framePending(a1)
    beq.b   .1
 ifne DEBUG
    ;move    #$f00,$dff180
 endif
    rts
.1
    * Start processing a new frame
    st      framePending(a1)
    jmp     _LVOCause(a6)
    endb    a1
 endif


* Level 1 interrupt handler, debug colors
* In:
*    a1 = IS_Data = PlaySidBase
residLevel1HandlerDebug:
    move    #$ff0,$dff180
    bsr.b   residLevel1Handler
    clr     $dff180
   	rts

* Level 1 interrupt handler
* In:
*    a1 = IS_Data = PlaySidBase
residLevel1Handler:
   	movem.l d2-d7/a2-a4/a6,-(sp)
    move.l  a1,a6

    cmp.w   #PM_PLAY,psb_PlayMode(a6)
    bne.b   .x

    tst.w   psb_Sid2Address(a6)
    bne.b   .xx
    * Play samples in the 4th channel along with reSID.
    * Do it before the next cycle to correct
    * the sync with the reSID sound output somewhat.
	move.l	psb_C64Mem(a6),a5
	add.l	#$0000D400,a5
	lea	_custom,a4		;HardwareBase
    jsr     CreateFour
    * Store Ch4 activation status.
    * This prevents reSID poking ch4 registers.
	move.l	psb_Chan4(a6),a0
    move.b  ch4_Active(a0),d0
    or.b    d0,ch4_WasActive(a0)
.xx
    jsr     Play64
.x
    bsr.b   switchAndFillBuffer
    clr.w   framePending
   	movem.l (sp)+,d2-d7/a2-a4/a6
    rts

* in:
*   a6 = PlaySidBase
switchAndFillBuffer:
    lea     sidBufferAHi(pc),a0

    tst.w   psb_Sid2Address(a6)
    bne.b   .sid2

    basereg sidBufferAHi,a0
    * Swap SID buffers A and B
    movem.l sidBufferAHi(a0),d0/d1/a1/a2
    movem.l d0/d1,sidBufferBHi(a0)
    movem.l a1/a2,sidBufferAHi(a0)
    endb    a0

    move.l  a1,$a0+$dff000
    move.l  a1,$b0+$dff000 
    move.l  a2,$c0+$dff000 

	move.l	psb_Chan4(a6),a0
    move.b  ch4_WasActive(a0),-(sp)
    bne.b   .1 
    * Poke ch4 if not used for digisamples
    move.l  a2,$d0+$dff000 
.1
 
    move.l   psb_reSID(a6),a0

    * output buffer pointers a1 and a2 set above
    move.l  cyclesPerFrame(pc),d0
    * buffer size limit
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  clockRoutine(pc),a3
    jsr     (a3)
    * d0 = bytes received, make words
    * rounds down, so may discard one byte

    lsr     #1,d0
    move    d0,$a4+$dff000   * words
    move    d0,$b4+$dff000   * words
    move    d0,$c4+$dff000   * words
    tst.b   (sp)+
    bne.b   .2
    * Poke ch4 if not used for digisamples
    move    d0,$d4+$dff000   * words
.2
    rts

.sid2
    tst.w   psb_Sid3Address(a6)
    bne    .sid3

    basereg sidBufferAHi,a0
    * Swap SID buffers A and B
    movem.l sidBufferAHi(a0),d0/d1/a1/a2/a3/a4/a5/a6
    movem.l d0/d1,sidBufferBHi(a0)
    movem.l a1/a2,sidBufferAHi(a0)

    * Swap SID2 buffers A and B
    movem.l a3/a4,sid2BufferBHi(a0)
    movem.l a5/a6,sid2BufferAHi(a0)
    endb    a0

    move.l  a1,$a0+$dff000 
    move.l  a2,$d0+$dff000 
    move.l  a3,$b0+$dff000 
    move.l  a4,$c0+$dff000 
 
    ; SID 1

    movem.l sidBufferAHi(pc),a1/a2
    move.l  cyclesPerFrame(pc),d0
    * buffer size limit
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  clockRoutine(pc),a3
    lea     residData,a0
    jsr     (a3)

    ; SID 2

    movem.l sid2BufferBHi(pc),a1/a2
    move.l  cyclesPerFrame(pc),d0
    * buffer size limit
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  clockRoutine(pc),a3
    lea     residData2,a0
    jsr     (a3)

    * d0 = bytes received, make words
    * rounds down, so may discard one byte
    lsr     #1,d0
    move    d0,$a4+$dff000   * words
    move    d0,$d4+$dff000   * words
    move    d0,$b4+$dff000   * words
    move    d0,$c4+$dff000   * words
    rts

* Three SIDs
* SID 1: paula 0 + 1, 14-bit
* SID 2: paula 2, 8-bit
* SID 3: paula 3, 8-bit
.sid3
    basereg sidBufferAHi,a0
    * Swap SID buffers A and B
    movem.l sidBufferAHi(a0),d0/d1/a1/a2/a3/a4/a5/a6
    movem.l d0/d1,sidBufferBHi(a0)
    movem.l a1/a2,sidBufferAHi(a0)

    * Swap SID2 buffers A and B
    movem.l a3/a4,sid2BufferBHi(a0)
    movem.l a5/a6,sid2BufferAHi(a0)

    move.l  a1,$a0+$dff000  * ch1 left: SID 1 high
    move.l  a2,$d0+$dff000  * ch4 left: SID 1 low
    move.l  a3,$b0+$dff000  * ch2 right: SID 2 high

     * Swap SID3 buffers A and B
    movem.l sid3BufferAHi(a0),d0/d1/a1/a2
    movem.l d0/d1,sid3BufferBHi(a0)
    movem.l a1/a2,sid3BufferAHi(a0)

    move.l  a1,$c0+$dff000  * ch3 right: SID 3 high

    endb    a0
 
    ; SID 1

    movem.l sidBufferAHi(pc),a1/a2
    move.l  cyclesPerFrame(pc),d0
    * buffer size limit
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  clockRoutine(pc),a3
    lea     residData,a0
    jsr     (a3)

    ; SID 2

    movem.l sid2BufferBHi(pc),a1/a2
    move.l  cyclesPerFrame(pc),d0
    * buffer size limit
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  clockRoutine(pc),a3
    lea     residData2,a0
    jsr     (a3)

    ; SID 3

    movem.l sid3BufferBHi(pc),a1/a2
    move.l  cyclesPerFrame(pc),d0
    * buffer size limit
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  clockRoutine(pc),a3
    lea     residData3,a0
    jsr     (a3)

    * d0 = bytes received, make words
    * rounds down, so may discard one byte
    lsr     #1,d0
    move    d0,$a4+$dff000   * words
    move    d0,$d4+$dff000   * words
    move    d0,$b4+$dff000   * words
    move    d0,$c4+$dff000   * words
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


* Calculates four frames of sound and measures the time taken.
* In:
*   d0 = reSID mode to test, RM_NORMAL... etc
*   d1 = Enable filter
*   d2 = Enable extfilter
* Out:
*   d0 = millisecs taken
*   d1 = reference value 
@MeasureResidPerformance:
    movem.l d2-d7/a2-a6,-(sp)
    * Stuff filter settings into d5 for later
    move.b  d1,d5
    lsl     #8,d5
    move.b  d2,d5

    moveq   #SAMPLING_METHOD_OVERSAMPLE2x14,d4
    cmp.b   #REM_OVERSAMPLE2,d0
    beq.b   .go

    moveq   #SAMPLING_METHOD_OVERSAMPLE3x14,d4
    cmp.b   #REM_OVERSAMPLE3,d0
    beq.b   .go

    moveq   #SAMPLING_METHOD_OVERSAMPLE4x14,d4
    cmp.b   #REM_OVERSAMPLE4,d0
    beq.b   .go

    moveq   #SAMPLING_METHOD_INTERPOLATE14,d4
    cmp.b   #REM_INTERPOLATE,d0
    beq.b   .go

    * Default measuring mode
    moveq   #SAMPLING_METHOD_SAMPLE_FAST14,d4
.go
  if DEBUG
    and.l   #$ff,d0
    move.l  d4,d1
    DPRINT  "MeasureResidPerformance REM=%ld METHOD=%ld"
  endif

    ;----------------------------------
    moveq   #-1,d7
    move.l	4.w,a6
    move	LIB_VERSION(a6),d0
    cmp     #36,d0
    blo     .x
    ;----------------------------------
    lea     timerDeviceName(pc),a0
    moveq	#UNIT_ECLOCK,d0
    moveq	#0,d1
    lea     timerRequest(pc),a1
    jsr	    _LVOOpenDevice(a6)		; d0=0 if success
    tst.l	d0
    bne     .error
    ;----------------------------------
    moveq   #0,d6
    move.l  #(4*SAMPLE_BUFFER_SIZE),d0
    move.l  #MEMF_CHIP!MEMF_CLEAR,d1
    jsr     _LVOAllocMem(a6)
    tst.l   d0
    beq     .error2
    move.l  d0,d6
    ;----------------------------------
    lea     residData,a0
    jsr	    sid_constructor
    
    move.l  #985248,d0
    move.b  d4,d1       * select sampling mode
    move.l  #PAULA_PERIOD,d2
    lea     residData,a0
    jsr     sid_set_sampling_parameters_paula
    move.l  a1,a4       * grab the clock routine
    
    move.b  d5,d0
 if DEBUG
    and.l   #$ff,d0
    DPRINT  "Perf: extfilter=%ld"
 endif
    lea     residData,a0
    jsr     sid_enable_external_filter
    lsr     #8,d5
    move.b  d5,d0
 if DEBUG
    and.l   #$ff,d0
    DPRINT  "Perf: filter=%ld"
 endif
    lea     residData,a0
    jsr     sid_enable_filter


 if DEBUG
    move.l  d4,d0
    move.l  a1,d1
    DPRINT  "samplingMode=%ld clockRoutine=%lx"
 endif

    move.l  #SAMPLES_PER_FRAME_200Hz,d0
    lea     residData,a0
    mulu.l  sid_cycles_per_sample(a0),d1:d0
    * Shift by 16 and 10 to get the FP to 
    * the correct position
    divu.l  #1<<(16+10),d1:d0
    move.l  d0,d5
    DPRINT  "cycles per frame=%ld"

    ;----------------------------------

    move.l  4.w,a6
    jsr     _LVOForbid(a6)

    lea     clockStart(pc),a0
    move.l	IO_DEVICE+timerRequest(pc),a6
    jsr     _LVOReadEClock(a6)

    ;----------------------------------

    move.l  d6,-(sp)
    * Write both 14-bit bytes into same buffer, doesn't matter here
    move.l  d6,a1   * output buffer high byte
    move.l  d6,a2   * output buffer low byte
    move.l  d5,d0  * cycles
    lsl.l   #2,d0  * do 4 frames
    move.l  #(4*SAMPLE_BUFFER_SIZE),d1 * buffer limit
    lea     residData,a0
    ;;jsr     (a4)    * call clock routine
    move.l  (sp)+,d6

    ;----------------------------------

    lea     clockEnd(pc),a0
    move.l	IO_DEVICE+timerRequest(pc),a6
    jsr     _LVOReadEClock(a6)

    move.l  d0,-(sp)
    move.l  4.w,a6
    jsr     _LVOPermit(a6)
    move.l  (sp)+,d0

    ;----------------------------------

     * D0 will be 709379 for PAL.
	move.l	d0,d2
	; d2 = ticks/s
	divu	#10000,d2
	; d2 = ticks/10ms
	ext.l	d2
	
    ; Calculate diff between start and stop times
	; in 64-bits
	move.l	EV_HI+clockEnd(pc),d0
	move.l	EV_LO+clockEnd(pc),d1
	move.l	EV_HI+clockStart(pc),d3
	sub.l	EV_LO+clockStart(pc),d1
	subx.l	d3,d0

	; Turn the diff into millisecs
	; Divide d0:d1 by d2
	divu.l  d2,d0:d1
   ; d0:d1 is now d0:d1/d2
	; take the lower 32-bits
    move.l  d1,d7

    ;----------------------------------

    lea     residData,a0
    jsr     sid_reset

.error2
    ;----------------------------------

    lea     timerRequest(pc),a1
    move.l  4.w,a6
    jsr     _LVOCloseDevice(a6)

    tst.l   d6
    beq.b   .x
    move.l  d6,a1
    move.l  #(4*SAMPLE_BUFFER_SIZE),d0
    jsr     _LVOFreeMem(a6)
.x
    move.l  d7,d0
    move.l  #200,d1 * reference value
    movem.l (sp)+,d2-d7/a2-a6
    rts
.error
    bra     .x


timerDeviceName dc.b	"timer.device",0
	even



* Frame $b from "Advanced Chemistry"
pokeSound:
    move.b  #$00,d0
    move.b  #$15,d1 * fc_lo
    bsr     .write
;   000b 1601 000b 17f1 
    move.b  #$01,d0
    move.b  #$16,d1 * fc_hi
    bsr     .write
    move.b  #$f1,d0 * res=f, filter voice 1
    move.b  #$17,d1 * res_filt
    bsr     .write
;00000420:   186f   0507   06a2   0200  ...o............
    move.b  #$6f,d0 * filter mode=6 (hp+bp), vol=f
    move.b  #$18,d1 * mode_vol
    bsr     .write
    move.b  #$07,d0 * attack=0, decay=7
    move.b  #$05,d1 * v1 attack decay
    bsr     .write
    move.b  #$a2,d0 * sustain=a, release=2
    move.b  #$06,d1 * v1 sustain release
    bsr     .write
    move.b  #$00,d0
    move.b  #$02,d1 * v1 pw lo
    bsr     .write
;00000430:   0387   0043   0103   0441  .......C.......A
    move.b  #$87,d0
    move.b  #$03,d1 * v1 pw hi
    bsr     .write
    move.b  #$43,d0
    move.b  #$00,d1 * v1 freq lo
    bsr     .write
    move.b  #$03,d0
    move.b  #$01,d1 * v1 freq hi
    bsr     .write
    move.b  #$41,d0 * gate, pulse
    move.b  #$04,d1 * v1 control
    bsr     .write
;00000440:   0c00   0d64   0900   0a84  .......d........
    move.b  #$00,d0 * attack=0, decay=0
    move.b  #$0c,d1 * v2 attack decay
    bsr     .write
    move.b  #$64,d0 * sustain=6, release=4
    move.b  #$0d,d1 * v2 sustain release
    bsr     .write
    move.b  #$00,d0
    move.b  #$09,d1 * v2 pw lo
    bsr     .write
    move.b  #$84,d0
    move.b  #$0a,d1 * v2 pw hi
    bsr     .write
;00000450:   0714   0827   0b41   1300  .......'...A....
    move.b  #$14,d0
    move.b  #$07,d1 * v2 freq lo
    bsr     .write
    move.b  #$27,d0
    move.b  #$08,d1 * v2 freq hi
    bsr     .write
    move.b  #$41,d0 * gate, pulse
    move.b  #$0b,d1 * v2 control
    bsr     .write
    move.b  #$00,d0 * attack=0, decay=0
    move.b  #$13,d1 * v3 attack decay
    bsr     .write
;00000460:   14c2   10a0   1180   0e8d  ................
    move.b  #$c2,d0 * sustain=c, release=2
    move.b  #$14,d1 * v3 sustain release
    bsr     .write
    move.b  #$a0,d0
    move.b  #$10,d1 * v3 pw lo
    bsr     .write
    move.b  #$80,d0
    move.b  #$11,d1 * v3 pw hi
    bsr     .write
    move.b  #$8d,d0
    move.b  #$0e,d1 * v3 freq lo
    bsr     .write
;00000470:   0f3a   1241 
    move.b  #$3a,d0
    move.b  #$0f,d1 * v3 freq hi
    bsr     .write
    move.b  #$41,d0 * gate, pulse
    move.b  #$12,d1 * v3 control 
    bsr     .write
    rts    

.write  
    lea     residData,a0
    jmp     sid_write





timerRequest      ds.b    IOTV_SIZE
clockStart        ds.b    EV_SIZE
clockEnd          ds.b    EV_SIZE
cyclesPerFrame    dc.l    0
clockRoutine      dc.l    0
bufferMemoryPtr   dc.l    0
sidBufferAHi      dc.l    0
sidBufferALo      dc.l    0
sidBufferBHi      dc.l    0
sidBufferBLo      dc.l    0
sid2BufferAHi     dc.l    0
sid2BufferALo     dc.l    0
sid2BufferBHi     dc.l    0
sid2BufferBLo     dc.l    0
sid3BufferAHi     dc.l    0
sid3BufferALo     dc.l    0
sid3BufferBHi     dc.l    0
sid3BufferBLo     dc.l    0

mainTask          dc.l    0
residWorkerTask:  dc.l    0
oldVecAud0        dc.l    0
residTimerRequest      ds.b    IOTV_SIZE
residClock             ds.b    EV_SIZE
framePending           dc.w    0
  ifne DEBUG
bob1
     dc.w   $0f0
  endif


residLevel4Intr1	
        dc.l	0		; Audio Interrupt
        dc.l	0
        dc.b	2
        dc.b	0
        dc.l	residLevel4Name1
residLevel4Intr1Data:
        dc.l	0		            ;is_Data
        dc.l	residLevel4Handler1	;is_Code

residLevel4Name1
    dc.b    "reSID Audio",0
    even

residLevel1Intr
      	dc.l	0
        dc.l	0
        dc.b	2
        dc.b	0
        dc.l    residLevel4Name1    
residLevel1Data:
        dc.l	0
residLevel1HandlerPtr:
        dc.l	residLevel1Handler




*-----------------------------------------------------------------------*
*
* AHI inteface
*
*-----------------------------------------------------------------------*


ahiInit:
    SPRINT  "ahiInit"
	pushm	all

    move.l  _PlaySidBase,a5

	sub.l	a1,a1
	move.l	4.w,a6
	jsr     _LVOFindTask(a6)
	move.l	d0,psb_AhiTask(a5)
	SPRINT	"task=%lx"

	OPENAHI	1
    DPRINT  "base=%lx"
	move.l	d0,psb_AhiBase(a5)
    beq	.ahi_error	
	move.l	d0,a6


    lea     ahiChannels(pc),a0
    move.l  #1,(a0)
    tst.w   psb_Sid2Address(a5)
    beq     .mm
    addq.l  #1,(a0)
    tst.w   psb_Sid3Address(a5)
    beq     .mm
    addq.l  #1,(a0)
.mm
 if DEBUG
    move.l  (a0),d0
    DPRINT  "AHI channels=%ld"
 endif

	lea	ahiTags(pc),a1
	jsr	_LVOAHI_AllocAudioA(a6)
    DPRINT  "AllocAudio=%lx"
	move.l	d0,psb_AhiCtrl(a5)
	beq	.ahi_error
	move.l	d0,a2

	moveq	#0,d0				;sample 1
	moveq	#AHIST_DYNAMICSAMPLE,d1
	lea	ahiSound1(pc),a0
	jsr	_LVOAHI_LoadSound(a6)
    DPRINT  "LoadSound=%lx"
	tst.l	d0
	bne	.ahi_error

	moveq	#1,d0				;sample 2
	moveq	#AHIST_DYNAMICSAMPLE,d1
	lea	ahiSound2(pc),a0
	jsr	_LVOAHI_LoadSound(a6)
    DPRINT  "LoadSound=%lx"
	tst.l	d0
	bne	.ahi_error

	moveq	#2,d0				;sample 3
	moveq	#AHIST_DYNAMICSAMPLE,d1
	lea	ahiSound3(pc),a0
	jsr	_LVOAHI_LoadSound(a6)
    DPRINT  "LoadSound=%lx"
	tst.l	d0
	bne	.ahi_error

	moveq	#3,d0				;sample 4
	moveq	#AHIST_DYNAMICSAMPLE,d1
	lea	ahiSound4(pc),a0
	jsr	_LVOAHI_LoadSound(a6)
    DPRINT  "LoadSound=%lx"
	tst.l	d0
	bne	.ahi_error

	moveq	#4,d0				;sample 5
	moveq	#AHIST_DYNAMICSAMPLE,d1
	lea	ahiSound5(pc),a0
	jsr	_LVOAHI_LoadSound(a6)
    DPRINT  "LoadSound=%lx"
	tst.l	d0
	bne	.ahi_error

	moveq	#5,d0				;sample 6
	moveq	#AHIST_DYNAMICSAMPLE,d1
	lea	ahiSound6(pc),a0
	jsr	_LVOAHI_LoadSound(a6)
    DPRINT  "LoadSound=%lx"
	tst.l	d0
	bne	.ahi_error


    ; ---------- Frequency ch1
    moveq	#0,d0		* channel
    move.l  #PLAYBACK_FREQ,d1
	moveq	#AHISF_IMM,d2	* flags
	move.l	psb_AhiCtrl(a5),a2
	jsr     _LVOAHI_SetFreq(a6)
    DPRINT  "SetFreq=%lx"

    ; ---------- Volume ch1
	moveq	#0,d0		* channel
    move.l  #$10000,d1  * max volume

    move.l  #$8000,d2   * pan to center
    tst.w   psb_Sid2Address(a5)
    beq     .monoPan
    moveq   #0,d2       * if stereo, max left
.monoPan
	moveq	#AHISF_IMM,d3	* flags
	move.l	psb_AhiCtrl(a5),a2
	jsr	    _LVOAHI_SetVol(a6)
    DPRINT  "SetVol=%lx"

    tst.w   psb_Sid2Address(a5)
    beq     .mono

    ; ---------- Frequency ch2
	moveq	#1,d0		* channel
    move.l  #PLAYBACK_FREQ,d1
	moveq	#AHISF_IMM,d2	* flags
	move.l	psb_AhiCtrl(a5),a2
	jsr	_LVOAHI_SetFreq(a6)
    DPRINT  "SetFreq=%lx"

    ; ---------- Volume ch2
	moveq	#1,d0		* channel
    move.l  #$10000,d1  * max volume
    move.l  #$10000,d2  * pan max right
	moveq	#AHISF_IMM,d3	* flags
	move.l	psb_AhiCtrl(a5),a2
	jsr	_LVOAHI_SetVol(a6)
    DPRINT  "SetVol=%lx"

    tst.w   psb_Sid3Address(a5)
    beq     .stereo

    ; ---------- Frequency ch3
	moveq	#2,d0		* channel
    move.l  #PLAYBACK_FREQ,d1
	moveq	#AHISF_IMM,d2	* flags
	move.l	psb_AhiCtrl(a5),a2
	jsr	_LVOAHI_SetFreq(a6)
    DPRINT  "SetFreq=%lx"

    ; ---------- Volume ch3
	moveq	#2,d0		* channel
    move.l  #$10000,d1  * max volume
    move.l  #$8000,d2  * pan middle
	moveq	#AHISF_IMM,d3	* flags
	move.l	psb_AhiCtrl(a5),a2
	jsr	_LVOAHI_SetVol(a6)
    DPRINT  "SetVol=%lx"

.stereo
.mono

	lea	ahiCtrlTags(pc),a1

	jsr	_LVOAHI_ControlAudioA(a6)
    DPRINT  "ControlAudio=%lx"
	tst.l	d0
	bne.b	.ahi_error

	popm	all
    SPRINT  "ahiInit ok"
	moveq	#1,d0   * ok
	rts

.ahi_error
	popm	all
    SPRINT  "ahiInit error"
	moveq	#0,d0   * error
	rts



* in:
*   a6 = PlaySidBase
ahiSwitchAndFillLeftBuffer:
    eor.w   #1,psb_AhiBankLeft+2(a6)
    
    * Select target sound
    lea     ahiSound1(pc),a3
    tst.l   psb_AhiBankLeft(a6)
    beq     .0
    lea     ahiSound2(pc),a3
.0  
    * a1 = output buffer
    move.l  4(a3),a1

    move.l  cyclesPerFrame(pc),d0
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  psb_reSID(a6),a0
    move.l  clockRoutine(pc),a3
    jsr     (a3)
    move.l  _PlaySidBase,a6
    move.l  d0,psb_AhiSamplesOutLeft(a6)
    rts

ahiSwitchAndFillRightBuffer:
    tst.w   psb_Sid2Address(a6)
    beq     .x

    eor.w   #1,psb_AhiBankRight+2(a6)
    
    * Select target sound
    lea     ahiSound3(pc),a3
    tst.l   psb_AhiBankRight(a6)
    beq     .0
    lea     ahiSound4(pc),a3
.0  
    * a1 = output buffer
    move.l  4(a3),a1

    move.l  cyclesPerFrame(pc),d0
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  psb_reSID2(a6),a0
    move.l  clockRoutine(pc),a3
    jsr     (a3)
    move.l  _PlaySidBase,a6
    move.l  d0,psb_AhiSamplesOutRight(a6)
.x
    rts

ahiSwitchAndFillMiddleBuffer:
    tst.w   psb_Sid3Address(a6)
    beq     .x

    eor.w   #1,psb_AhiBankMiddle+2(a6)
    
    * Select target sound
    lea     ahiSound5(pc),a3
    tst.l   psb_AhiBankMiddle(a6)
    beq     .0
    lea     ahiSound6(pc),a3
.0  
    * a1 = output buffer
    move.l  4(a3),a1

    move.l  cyclesPerFrame(pc),d0
    move.l  #SAMPLE_BUFFER_SIZE,d1
    move.l  psb_reSID3(a6),a0
    move.l  clockRoutine(pc),a3
    jsr     (a3)
    move.l  _PlaySidBase,a6
    move.l  d0,psb_AhiSamplesOutMiddle(a6)
.x
    rts

* in:
*   d4 = ahi flags
ahiPlayLeftBuffer:
	move	#0,d0		* channel
    move.l  psb_AhiBankLeft(a6),d1  * sound number to play, 0 or 1
	moveq	#0,d2		* offset
	move.l	psb_AhiSamplesOutLeft(a6),d3	* samples to play 
	;moveq   #0,d4
	move.l	psb_AhiCtrl(a6),a2
    push    a6
	move.l	psb_AhiBase(a6),a6
	jsr     _LVOAHI_SetSound(a6)
    pop     a6
    rts

* in:
*   d4 = ahi flags
ahiPlayRightBuffer:
    tst.w   psb_Sid2Address(a6)
    beq     .x

	move	#1,d0		* channel
    move.l  psb_AhiBankRight(a6),d1  * sound number to play, 2 or 3
    addq.l  #2,d1
	moveq	#0,d2		* offset
	move.l	psb_AhiSamplesOutRight(a6),d3		* samples to play 
	;moveq   #0,d4
	move.l	psb_AhiCtrl(a6),a2
    push    a6
	move.l	psb_AhiBase(a6),a6
	jsr     _LVOAHI_SetSound(a6)
    pop     a6
.x
    rts

* in:
*   d4 = ahi flags
ahiPlayMiddleBuffer:
    tst.w   psb_Sid3Address(a6)
    beq     .x

	move	#2,d0		* channel
    move.l  psb_AhiBankMiddle(a6),d1  * sound number to play, 4 or 5
    addq.l  #4,d1
	moveq	#0,d2		* offset
	move.l	psb_AhiSamplesOutMiddle(a6),d3		* samples to play 
	;moveq   #0,d4
	move.l	psb_AhiCtrl(a6),a2
    push    a6
	move.l	psb_AhiBase(a6),a6
	jsr     _LVOAHI_SetSound(a6)
    pop     a6
.x
    rts


* Two per channel for double buffering

ahiSound1
	dc.l	AHIST_M16S	* type
	dc.l	0	* addr
	dc.l	0	* len

ahiSound2
	dc.l	AHIST_M16S
	dc.l	0	* addr
	dc.l	0	* len

ahiSound3
	dc.l	AHIST_M16S
	dc.l	0	* addr
	dc.l	0	* len

ahiSound4
	dc.l	AHIST_M16S
	dc.l	0	* addr
	dc.l	0	* len

ahiSound5
	dc.l	AHIST_M16S
	dc.l	0	* addr
	dc.l	0	* len

ahiSound6
	dc.l	AHIST_M16S
	dc.l	0	* addr
	dc.l	0	* len

ahiStop:
    SPRINT  "ahiStop"
	pushm	all
    move.l  _PlaySidBase,a5

 	sub.l	a1,a1
	move.l	4.w,a6
	jsr     _LVOFindTask(a6)
	cmp.l	psb_AhiTask(a5),d0
	bne 	.x

	move.l	psb_AhiBase(a5),d0
    beq 	.1
	move.l	d0,a6

    lea	    ahiStopCtrlTags(pc),a1
	move.l	psb_AhiCtrl(a5),a2
	jsr	_LVOAHI_ControlAudioA(a6)
    DPRINT  "AHI_ControlAudioA=%ld"

	move.l	psb_AhiCtrl(a5),a2
	jsr	_LVOAHI_FreeAudio(a6)
	SPRINT	"AHI_FreeAudio done"
	CLOSEAHI
    SPRINT	"CLOSE AHI done"
.1	
    clr.l   psb_AhiBase(a5)
.x	
    popm	all
	rts

ahiCtrlTags:
	dc.l	AHIC_Play,1
	dc.l	TAG_DONE

ahiStopCtrlTags:
	dc.l	AHIC_Play,0
	dc.l	TAG_DONE

ahiTags
	dc.l	AHIA_MixFreq,PLAYBACK_FREQ
	dc.l	AHIA_Channels,2
ahiChannels = *-4
	dc.l	AHIA_Sounds,6 * For 3 SIDs
	dc.l	AHIA_AudioID,$20004	; paula 8-bit stereo
ahiMode = *-4

	dc.l	AHIA_SoundFunc,.soundFunc
	dc.l	TAG_DONE

.soundFunc:
	ds.b	MLN_SIZE
	dc.l	.soundFuncImpl
	dc.l	0
	dc.l	0

* in:
* a0	struct Hook *
* a1	struct AHISoundMessage *
* a2	struct AHIAudioCtrl *
.soundFuncImpl:
    move.w  ahism_Channel(a1),d0
    beq     .left
    subq    #1,d0
    beq     .right
    subq    #1,d0
    beq     .middle
    rts

* SID 3
.middle
    pushm   d2-d7/a2-a6
    move.l  _PlaySidBase,a6
    bsr     ahiSwitchAndFillMiddleBuffer
    moveq   #0,d4
    bsr     ahiPlayMiddleBuffer
    popm    d2-d7/a2-a6
    rts

* SID 1, drives the output
.left
    pushm   d2-d7/a2-a6
    move.l  _PlaySidBase,a6
    cmp.w   #PM_PLAY,psb_PlayMode(a6)
    bne.b   .x
    jsr     Play64
.x
    bsr     ahiSwitchAndFillLeftBuffer
    moveq   #0,d4
    bsr     ahiPlayLeftBuffer
    popm    d2-d7/a2-a6
.y
	rts

* SID 2
.right
    pushm   d2-d7/a2-a6
    move.l  _PlaySidBase,a6
    bsr     ahiSwitchAndFillRightBuffer
    moveq   #0,d4
    bsr     ahiPlayRightBuffer
    popm    d2-d7/a2-a6
    rts




*-----------------------------------------------------------------------*
*
* Debug
*
*-----------------------------------------------------------------------*


  ifne ENABLE_REGDUMP
saveDump
    lea     .d(pc),a0
    lea     regDump,a1
    move.l  regDumpOffset,d0
    DPRINT  "save reg dump offset=%ld"
    mulu.l  #4,d0
    bsr     plainSaveFile
    rts

.d  dc.b    "sys:psid.bin",0
    even

* Saves a file
* in:	
*  a0 = file path
*  a1 = data address
*  d0 = data length
*  a6 = dos base
* out: 
*  d0 = Written bytes or -1 if error
plainSaveFile:
	movem.l	d1-a6,-(sp)
    tst.l   a6
    beq     .openErr

    moveq	#-1,d7
	move.l	a1,d4
	move.l 	d0,d5
    
	move.l	a0,d1
	move.l	#MODE_NEWFILE,d2
	jsr     _LVOOpen(a6)
	move.l	d0,d6
	beq.b	.openErr

	move.l	d6,d1	* file
	move.l	d4,d2	* buffer
	move.l	d5,d3  	* len
	jsr     _LVOWrite(a6)
    DPRINT  "write=%ld"
	move.l  d0,d7 

	move.l	d6,d1 
	jsr     _LVOClose(a6)
.openErr 

	move.l	d7,d0
	movem.l (sp)+,d1-a6
	rts
  endif

    section .bss,bss

workerTaskStack     ds.b    4096
workerTaskStruct    ds.b    TC_SIZE

  ifne ENABLE_REGDUMP
regDumpTime         ds.w    1
regDumpOffset       ds.l    1
regDump
    * time(w),reg(b),data(b)
    ds.l    REGDUMP_SIZE
  endif

 if DEBUG

   section debug,code

PRINTOUT_DEBUGBUFFER
	pea     _debugDesBuf(pc)
	bsr.b   PRINTOUT
	rts

PRINTOUT
	pushm	d0-d3/a0/a1/a5/a6
	move.l	_output(pc),d1
	bne.w	.open

    move.b  _DOSBase(pc),d0
    bne.b   .1
    move.l  4.w,a6
    lea     .dosname(pc),a1
    jsr     _LVOOldOpenLibrary(a6)
    move.l  d0,_DOSBase
.1


	* try tall window firsr
	move.l	#.bmb,d1
	move.l	#MODE_NEWFILE,d2
    move.l  _DOSBase(pc),a6
	jsr 	_LVOOpen(a6)
	move.l	d0,_output
	bne.b	.open
	* smaller next
	move.l	#.bmbSmall,d1
	move.l	#MODE_NEWFILE,d2
	jsr 	_LVOOpen(a6)
	move.l	d0,_output
	bne.b	.open
	* still not open! exit
	bra.b	.x

.bmb		dc.b	"CON:20/10/350/190/PlaySID debug",0
.bmbSmall  	dc.b	"CON:20/10/350/90/PlaySID debug",0
    even


.open
	move.l	32+4(sp),a0

	moveq	#0,d3
	move.l	a0,d2
.p	addq	#1,d3
	tst.b	(a0)+
	bne.b	.p
    move.l  _DOSBase(pc),a6
 	jsr     _LVOWrite(a6)
.x	popm	d0-d3/a0/a1/a5/a6
	move.l	(sp)+,(sp)
	rts
 

.dosname     dc.b    "dos.library",0
    even

desmsgDebugAndPrint
	* sp contains the return address, which is
	* the string to print
	movem.l	d0-d7/a0-a3/a6,-(sp)
	* get string
	move.l	4*(8+4+1)(sp),a0
	* find end of string
	move.l	a0,a1
.e	tst.b	(a1)+
	bne.b	.e
	move.l	a1,d7
	btst	#0,d7
	beq.b	.even
	addq.l	#1,d7
.even
	* overwrite return address 
	* for RTS to be just after the string
	move.l	d7,4*(8+4+1)(sp)

	lea	    _debugDesBuf(pc),a3
	move.l	sp,a1	
 ifne SERIALDEBUG
    lea     .putCharSerial(pc),a2
 else
	lea	.putc(pc),a2	
 endif
	move.l	4.w,a6
	jsr	    _LVORawDoFmt(a6)
	movem.l	(sp)+,d0-d7/a0-a3/a6
 ifeq SERIALDEBUG
	bsr	PRINTOUT_DEBUGBUFFER
 endif
	rts	* teleport!
.putc	
	move.b	d0,(a3)+	
	rts

.putCharSerial
    ;_LVORawPutChar
    ; output char in d0 to serial
    move.l  4.w,a6
    jsr     -516(a6)
    rts

CloseDebug:
    pushm   all
    move.l  _DOSBase(pc),a6
    cmp.w   #0,a6
    beq     .2
    move.l  _output(pc),d1
    beq.b   .1
 	jsr     _LVOClose(a6)
.1
    move.l  a6,a1
    move.l  4.w,a6
    jsr     _LVOCloseLibrary(a6)
.2
    clr.l   _DOSBase
    clr.l   _output
    popm    all
    rts

_DOSBase        ds.l    1
_output			ds.l 	1
_debugDesBuf	ds.b	1024
 endif ;; DEBUG

