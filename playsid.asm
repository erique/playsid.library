
*=======================================================================*
*									*
* 	C64 MUSIC EMULATOR FOR AMIGA					*
*	(C) 1990-1994 HÅKAN SUNDELL & RON BIRK				*
*									*
*=======================================================================*

*=======================================================================*
*	INCLUDES							*
*=======================================================================*
	NOLIST
		include	lvo/exec_lib.i
		include	exec/execbase.i
		include	exec/initializers.i
		include	exec/memory.i
		include	exec/libraries.i
		include	exec/resident.i
		include intuition/intuition.i
		include	resources/cia.i
		include	lvo/cia_lib.i
		include	hardware/custom.i
		include	hardware/cia.i
		include	hardware/dmabits.i
		include	hardware/intbits.i

		include	playsid_libdefs.i
	LIST
*=======================================================================*
*	EXTERNAL REFERENCES						*
*=======================================================================*
		xref	_custom,_ciaa,_ciab
		xref	@AllocEmulAudio,@FreeEmulAudio,@ReadIcon

                xdef    _PlaySidBase
*=======================================================================*
*									*
*	CODE SECTION							*
*									*
*=======================================================================*
		section	EmulSID_library,CODE
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

		clr.w	psb_TimeSeconds(a6)		;Set time to 00:00
		clr.w	psb_TimeMinutes(a6)
		clr.w	psb_UpdateCounter(a6)

.end		move.l	a6,d0
		rts

@Close		moveq	#$00,d0
		subq.w	#1,LIB_OPENCNT(a6)
		bne.s	.1
		bsr	@FreeEmulResource
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
		;CALLEXEC Forbid
		movem.l	d2-d7/a2-a6,-(a7)
		tst.w	psb_EmulResourceFlag(a6)
		beq.s	.LibOK
		moveq	#SID_LIBINUSE,d0
		bra.s	.Exit
.LibOK		bsr	AllocEmulMem
		tst.l	d0
		bne.s	.Exit
.MemOK		bsr	CheckCPU
		bsr	Make6502Emulator
		bsr	MakeMMUTable
		bsr	MakeVolume
		bsr	MakeSIDSamples
		bsr	MakeEnvelope
		move.w	#PM_STOP,psb_PlayMode(a6)
		move.w	#1,psb_EmulResourceFlag(a6)
		moveq	#0,d0
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*
@FreeEmulResource
		;CALLEXEC Forbid
		movem.l	d2-d7/a2-a6,-(a7)
		tst.w	psb_EmulResourceFlag(a6)
		beq.s	.Exit
		bsr	@StopSong
		bsr	FreeEmulMem
		clr.w	psb_EmulResourceFlag(a6)
.Exit		movem.l	(a7)+,d2-d7/a2-a6
		;CALLEXEC Permit
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
@SetDisplaySignal	move.l	a0,psb_DisplaySignalTask(a6)
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
		;CALLEXEC Permit
		rts

*-----------------------------------------------------------------------*
@StartSong	;CALLEXEC Forbid
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
		moveq	#0,d0
		rts

.Error		bsr	FreeEmulMem
		moveq	#SID_NOMEMORY,D0
		rts

*-----------------------------------------------------------------------*
FreeEmulMem
		FREE	psb_PrgMem(a6),PRGMEM_SIZE
		FREE	psb_MMUMem(a6),MMUMEM_SIZE
		FREE	psb_C64Mem(a6),C64MEM_SIZE
		FREE	psb_EnvelopeMem(a6),ENVELOPEMEM_SIZE
		FREE	psb_SampleMem(a6),SAMPLEMEM_SIZE
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
Init64		movem.l	d2-d7,-(a7)
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
Play64		bsr	EmulNextStep
		bsr	DoSound
		bsr	CalcTime
		bsr	ReadDisplayData
		bsr	DisplayRequest
		bsr	CheckC64TimerA
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
		movem.l	(a7)+,d2-d3
		rts

*-----------------------------------------------------------------------*
InitSID		movem.l	a2-a3,-(a7)
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

		movem.l	(a7)+,a2-a3
		rts
.Clear
		clr.b	(a0)+
		subq.w	#1,d0
		bne.s	.Clear

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

		rts
.Clear
		clr.b	(a0)+
		subq.w	#1,d0
		bne.s	.Clear

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
		bsr	.Calculate
		move.w	d0,$dff0a8
		move.l	psb_Enve2(a6),a0
		bsr.s	.Calculate
		move.w	d0,$dff0b8
		move.l	psb_Enve3(a6),a0
		bsr.s	.Calculate
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
	bsr.s	.Make
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

.D400	dc.b	$80,$81,$82,$83,$84,$85,$86,$87	;$D400-$D418
	dc.b	$88,$89,$8a,$8b,$8c,$8d,$8e,$8f
	dc.b	$90,$91,$92,$93,$94,$95,$96,$97
	dc.b	$98,$00,$00,$00,$00,$00,$00,$00
	
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

*-----------------------------------------------------------------------*
WriteIO					;Write 64 I/O $D000-$DFFF
					;D7=IOReg,D6=Byte,A2=Addr
					;USAGE: D6,D7,A2
	add.b	d7,d7
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

.D400						;80
	move.w	#$D400,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D401
	move.w	#$D401,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D402
	move.w	#$D402,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D403
	move.w	#$D403,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D404
	move.w	#$D404,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D405
	move.w	#$D405,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D406
	move.w	#$D406,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D407
	move.w	#$D407,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D408
	move.w	#$D408,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D409
	move.w	#$D409,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D40A
	move.w	#$D40A,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D40B
	move.w	#$D40B,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D40C
	move.w	#$D40C,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D40D
	move.w	#$D40D,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D40E
	move.w	#$D40E,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D40F
	move.w	#$D40F,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D410
	move.w	#$D410,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D411
	move.w	#$D411,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D412
	move.w	#$D412,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D413
	move.w	#$D413,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D414
	move.w	#$D414,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst
.D415
	move.w	#$D415,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D416
	move.w	#$D416,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D417
	move.w	#$D417,d7
	move.b	d6,0(a0,d7.l)
	Next_Inst
.D418
	move.w	#$D418,d7
	move.b	d6,0(a0,d7.l)
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
	Next_Inst

*-----------------------------------------------------------------------*

*=======================================================================*
*	INTERRUPT HANDLING ROUTINES					*
*=======================================================================*
OpenIRQ		move.l	a6,timerAIntrPSB
		move.l	a6,PlayIntrPSB
		move.l	psb_Chan1(a6),level4Intr1Data
		move.l	psb_Chan2(a6),level4Intr2Data
		move.l	psb_Chan3(a6),level4Intr3Data
		move.l	psb_Chan4(a6),level4Intr4Data

		lea	_custom,a0
		move.w	#INTF_AUD0+INTF_AUD1+INTF_AUD2+INTF_AUD3,INTENA(a0)
		move.w	#INTF_AUD0+INTF_AUD1+INTF_AUD2+INTF_AUD3,INTREQ(a0)

		tst.w	psb_IntVecAudFlag(a6)
		bne.s	.1

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

		moveq	#INTB_AUD3,d0
		lea	level4Intr4,a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
		move.l	d0,psb_OldIntVecAud3(a6)

		move.w	#1,psb_IntVecAudFlag(a6)

.1		lea	CiabName,a1	; Open Cia Resource
		moveq	#0,d0
		move.l	a6,-(a7)
		CALLEXEC	OpenResource
		move.l	(a7)+,a6
		move.l	d0,_CiabBase
		beq.s	.error

		tst.w	psb_TimerAFlag(a6)
		bne.s	.2
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
		lea	timerBIntr,a1
		moveq	#CIAICRB_TB,d0
		move.l	a6,-(a7)
		CALLCIAB	AddICRVector
		move.l	(a7)+,a6
		tst.l	d0
		bne.s	.error
		move.w	#1,psb_TimerBFlag(a6)

.3		bsr	PlayDisable
		moveq	#0,d0
		rts
.error		bsr	CloseIRQ
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
		move.l	psb_OldIntVecAud3(a6),a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
		moveq	#INTB_AUD2,d0
		move.l	psb_OldIntVecAud2(a6),a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
		moveq	#INTB_AUD1,d0
		move.l	psb_OldIntVecAud1(a6),a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
		moveq	#INTB_AUD0,d0
		move.l	psb_OldIntVecAud0(a6),a1
		move.l	a6,-(a7)
		CALLEXEC	SetIntVector
		move.l	(a7)+,a6
		move.w	#0,psb_IntVecAudFlag(a6)
.3
		rts

*-----------------------------------------------------------------------*
InitTimers
		bsr	StopTimerA
		move.w	psb_TimerConstA(a6),d0		; ~700
		bsr	SetTimerA
		bsr	StartTimerA
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
		lea	_ciab,a0
		and.b	#CIACRAF_TODIN+CIACRAF_SPMODE+CIACRAF_OUTMODE+CIACRAF_PBON,ciacra(a0)	; Timer A Cia B
		bclr	#CIACRAB_START,ciacra(a0)
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
		lea	_custom,a0
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
timerBServer	CALLEXEC 	Cause		; Ready for Player
		moveq	#0,d0			; A1=softwIntr
		rts

*-----------------------------------------------------------------------*
softwServer	move.l	a6,-(a7)		; Play it..
		move.l	a1,a6
		bsr	Play64
		move.l	(a7)+,a6
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
		move.l	ch4_ProgPointer(a1),a5
		jmp	(a5)

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
		move.w	ch4_SamVol(a1),AUD3VOL(a0)
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
		move.w	ch4_SamVol(a1),AUD3VOL(a0)
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
@AllocEmulAudio	jmp	@AllocEmulAudio_impl.l

*=======================================================================*
*                                                                       *
*	DATA SECTION							*
*                                                                       *
*=======================================================================*
	Section	DATA,data
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
	section	BSS,bss
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

*-----------------------------------------------------------------------*
		include	external.asm
