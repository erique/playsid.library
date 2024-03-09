	IFND  PLAYSID_LIBDEFS_I
PLAYSID_LIBDEFS_I SET  1

	IFND EXEC_TYPES_I
	INCLUDE "exec/types.i"
	ENDC

	IFND EXEC_LIBRARIES_I
	INCLUDE "exec/libraries.i"
	ENDC

;************************************************************************
; Private definitions for emul_lib.s
;************************************************************************
	include "git.gen.i"

PSIDLIB_VERSION		equ	1
PSIDLIB_REVISION	equ	6

PSIDLIB_NAME	MACRO
		dc.b	"playsid.library",0
		ENDM

PSIDLIB_IDSTRING MACRO
		dc.b	"playsid.library 1.6 (November 2023) reSID+SIDBlaster (git:"
		GIT
		dc.b	")",13,10,0
		ENDM

PSIDLIB_COPYRIGHT MACRO
		dc.b	"© 1996 by Per Håkan Sundell & Ron Birk",0
		ENDM


; ========================================================================;

CALLEXEC	MACRO
		move.l	$4.w,a6
		CALLLIB	_LVO\1
		ENDM

CALLCIAB	MACRO	
		move.l	_CiabBase,a6
		CALLLIB	_LVO\1
		ENDM

_custom	= $dff000
_ciaa	= $bfe001
_ciab	= $bfd000

; ========================================================================;
; === Memory Allocation ==================================================;
; ========================================================================;

PRGMEM_SIZE		equ	$20000
MMUMEM_SIZE		equ	$10000
C64MEM_SIZE		equ	$10000
ENVELOPEMEM_SIZE	equ	$8004
SAMPLEMEM_SIZE		equ	$8800

ALLOC		MACRO	
		move.l	#\2,d0
		move.l	#\3!MEMF_CLEAR,d1
		move.l	a6,-(a7)
		CALLEXEC AllocMem
		move.l	(a7)+,a6
		move.l	d0,\1
		ENDM

FREE		MACRO
		tst.l	\1
		beq.s	.\@
		move.l	#\2,d0
		move.l	\1,a1
		move.l	a6,-(a7)
		CALLEXEC FreeMem
		move.l	(a7)+,a6
		clr.l	\1
.\@
		ENDM

; ========================================================================;
; === PlaySidBase ========================================================;
; ========================================================================;

	STRUCTURE PlaySidBase,0
	STRUCT	psb_LibNode,LIB_SIZE
	UBYTE	psb_Flags
	UBYTE	psb_Pad
	APTR	psb_SysLib
	APTR	psb_SegList

	UWORD	psb_PlayMode
	UWORD	psb_TimeSeconds
	UWORD	psb_TimeMinutes
	APTR	psb_DisplayData

	APTR	psb_SongLocation
	UWORD	psb_SongLength
	UWORD	psb_SongStart
	UWORD	psb_SongInit
	UWORD	psb_SongMain
	UWORD	psb_SongNumber
	UWORD	psb_SongDefault
	ULONG	psb_SongSpeedMask
	UWORD	psb_SongFlags

	UWORD	psb_SongTune
	UWORD	psb_SongSpeed
	UWORD	psb_SongLoop

	UWORD	psb_VertFreq
	UWORD	psb_TimeEnable
	APTR	psb_TimeSignalTask
	ULONG	psb_TimeSignalMask
	UWORD	psb_DisplayEnable
	APTR	psb_DisplaySignalTask
	ULONG	psb_DisplaySignalMask
	UWORD	psb_ReverseEnable
	UWORD	psb_EmulResourceFlag
	UWORD	psb_SongSetFlag
	STRUCT	psb_ChannelEnable,8

	APTR	psb_VolumePointer
	STRUCT	psb_VolumePointers,64
	UWORD	psb_IntVecAudFlag
	APTR	psb_OldIntVecAud0
	APTR	psb_OldIntVecAud1
	APTR	psb_OldIntVecAud2
	APTR	psb_OldIntVecAud3
	UWORD	psb_TimerAFlag
	UWORD	psb_TimerBFlag
	APTR	psb_CalcFTable
	APTR	psb_SIDSampleNoise
	APTR	psb_SIDSampleTri
	APTR	psb_SIDSampleSaw
	APTR	psb_SIDSamplePulse
	APTR	psb_SIDSampleTPul
	APTR	psb_SIDSampleTSaw
	APTR	psb_SIDSampleFree
	APTR	psb_SIDSampleFour
	APTR	psb_SIDSampleFConv
	APTR	psb_FourMemList
	APTR	psb_SoundRemPars
	APTR	psb_PlayBackPars
	UWORD	psb_TimerConstA
	UWORD	psb_TimerConstB
	UWORD	psb_TimerConst50Hz
	UWORD	psb_ConvClockConst
	UWORD	psb_ConvFourConst
	UWORD	psb_CPUVersion
	UWORD	psb_OldC64TimerA
	UWORD	psb_NewFreq
	UWORD	psb_LastNoise
	UWORD	psb_PulseOffset
	UWORD	psb_UpdateFreq
	UWORD	psb_UpdateCounter
	UWORD	psb_RememberMode
	APTR	psb_Enve1
	APTR	psb_Enve2
	APTR	psb_Enve3
	APTR	psb_Chan1
	APTR	psb_Chan2
	APTR	psb_Chan3
	APTR	psb_Chan4
	APTR	psb_AttDecRelStep
	APTR	psb_VolumeTable
	APTR	psb_AttackDecay
	APTR	psb_SustainRelease
	APTR	psb_SustainTable
	APTR	psb_AttackTable
	APTR	psb_PrgMem
	APTR	psb_MMUMem
	APTR	psb_C64Mem
	APTR	psb_EnvelopeMem
	APTR	psb_SampleMem
	UWORD	psb_AudioDevice
	APTR	psb_AudioIO
	APTR	psb_AudioMP
    ; New fields added by KPK:
    UWORD   psb_Volume
    APTR    psb_reSID
    UWORD   psb_OperatingMode
    UWORD   psb_ResidMode
    APTR    psb_DOSBase
    APTR    psb_reSID2
    APTR    psb_reSID3
    UWORD   psb_HeaderChipVersion
    UWORD   psb_Sid2Address
    UWORD   psb_Sid3Address
    ULONG   psb_SamplesPerFrame
    UWORD   psb_Debug
	UWORD	psb_OldC64TimerB
    ULONG   psb_AhiMode
    APTR    psb_AhiTask
    APTR    psb_AhiBase
    APTR    psb_AhiCtrl
    ULONG   psb_AhiBankLeft
    ULONG   psb_AhiSamplesOutLeft
    ULONG   psb_AhiBankRight
    ULONG   psb_AhiSamplesOutRight
    ULONG   psb_AhiBankMiddle
    ULONG   psb_AhiSamplesOutMiddle
	LABEL	psb_SIZEOF

; --- Error --------------------------------------------------------------
SID_NOMEMORY      equ -1
SID_NOAUDIODEVICE equ -2
SID_NOCIATIMER    equ -3
SID_NOPAUSE       equ -4
SID_NOMODULE      equ -5
SID_NOICON        equ -6
SID_BADTOOLTYPE   equ -7
SID_NOLIBRARY     equ -8
SID_BADHEADER     equ -9
SID_NOSONG        equ -10
SID_LIBINUSE      equ -11
SID_NOSIDBLASTER  equ -12

; --- Playing Modes ------------------------------------------------------
PM_STOP		equ	0
PM_PLAY		equ	1
PM_PAUSE	equ	2

; --- Remember Modes -----------------------------------------------------
RM_NONE		equ	$0000
RM_REMEMBER	equ	$4000
RM_PLAYBACK	equ	$8000

; --- Operating Modes -----------------------------------------------------
OM_NORMAL         equ 0
OM_RESID_6581     equ 1
OM_RESID_8580     equ 2
OM_RESID_AUTO     equ 3
OM_SIDBLASTER_USB equ 4

; --- reSID Modes -----------------------------------------------------
REM_NORMAL         equ 0
REM_OVERSAMPLE2    equ 1
REM_OVERSAMPLE3    equ 2
REM_OVERSAMPLE4    equ 3
REM_INTERPOLATE    equ 4

; ========================================================================;
; === DisplayData ========================================================;
; ========================================================================;

	STRUCTURE	DisplayData,0
	APTR	dd_Sample1
	APTR	dd_Sample2
	APTR	dd_Sample3
	APTR	dd_Sample4
        WORD	dd_Length1
        WORD	dd_Length2
        WORD	dd_Length3
        WORD	dd_Length4
	WORD	dd_Period1
	WORD	dd_Period2
	WORD	dd_Period3
	WORD	dd_Period4
	WORD	dd_Enve1
	WORD	dd_Enve2
	WORD	dd_Enve3
	WORD	dd_Enve4
	WORD	dd_SyncLength1
	WORD	dd_SyncLength2
	WORD	dd_SyncLength3
	WORD	dd_Volume
	BYTE	dd_SyncInd1
	BYTE	dd_SyncInd2
	BYTE	dd_SyncInd3
	LABEL	dd_SIZEOF


; ========================================================================;
; === Envelope ===========================================================;
; ========================================================================;

	STRUCTURE	Envelope,0
	UWORD	env_CurrentAddr
	UWORD	env_CurrentAddrDec
	UWORD	env_Attack
	UWORD	env_AttackDec
	UWORD	env_Decay
	UWORD	env_DecayDec
	UWORD	env_Sustain
	UWORD	env_Release
	UWORD	env_ReleaseDec
	UWORD	env_Mode		;The modes are listed below
	LABEL	env_SIZEOF

; --- Envelope Modes ------------------------------------------------------
EM_RELEASE	equ	$0000	;Release - gate off
EM_SUSTAIN	equ	$4000	;Sustain - gate on
EM_DECAY	equ	$8000	;Decay - gate on
EM_ATTACK	equ	$FF00	;Attack - gate on
EM_QUIET	equ	$0080	;Quiet - gate off


; ========================================================================;
; === Channel ============================================================;
; ========================================================================;

	STRUCTURE	Channel,0
	APTR	ch_ProgPointer
	APTR	ch_SamAdrOld
	APTR	ch_SamAdrNew
	ULONG	ch_SamLenDec
	ULONG	ch_SamLenHDec
	ULONG	ch_SamIndStart
	ULONG	ch_SamIndStop
	ULONG	ch_SyncLenOld
	ULONG	ch_SyncLenNew
	UWORD	ch_Freq64Old
	UWORD	ch_Freq64New
	UWORD	ch_SamPer
	UWORD	ch_SamLen
	UWORD	ch_SamPerOld
	UWORD	ch_SamPerNew
	UWORD	ch_SamLenOld
	UWORD	ch_SamLenNew
	UBYTE	ch_SyncIndOld
	UBYTE	ch_SyncIndNew
	UBYTE	ch_WaveOld
	UBYTE	ch_WaveNew
	UBYTE	ch_AudIRQType		;See Type list below
	UBYTE	ch_RSyncToggle
	LABEL	ch_SIZEOF

; --- Channel Audio IRQ Types ---------------------------------------------
CAI_START	equ	$00	;
CAI_SYNC	equ	$01	;
CAI_RING	equ	$02	;
CAI_RINGSYNC	equ	$03	;
CAI_NONE	equ	$FF	;


; ========================================================================;
; === Channel4 ===========================================================;
; ========================================================================;

	STRUCTURE	Channel4,0
	APTR	ch4_ProgPointer
	APTR	ch4_Adress
	APTR	ch4_SamAdr
	APTR	ch4_SamRepAdr
	UWORD	ch4_LoopWait
	UWORD	ch4_NullWait
	UWORD	ch4_SamLen
	UWORD	ch4_SamPer
	UWORD	ch4_SamRepLen
	UWORD	ch4_SamVol
	UWORD   ch4_SamVolMultiplier
	UBYTE	ch4_Repeat
	UBYTE	ch4_Mode
	UBYTE	ch4_Active
    UBYTE   ch4_WasActive
	UBYTE	ch4_Counter
	UBYTE	ch4_AverageVol
	LABEL	ch4_SIZEOF

; --- Four Modes ---------------------------------------------------------
FM_NONE		equ	$00
FM_GALWAYON	equ	$01
FM_GALWAYOFF	equ	$81
FM_HUELSON	equ	$02
FM_HUELSOFF	equ	$82


; ========================================================================;
; === SoundInterfaceDevice ===============================================;
; ========================================================================;

	STRUCTURE	SoundInterfaceDevice,0
	UBYTE	sid_Voice1FreqLow
	UBYTE	sid_Voice1FreqHigh
	UBYTE	sid_Voice1PulseLow
	UBYTE	sid_Voice1PulseHigh
	UBYTE	sid_Voice1Control
	UBYTE	sid_Envelope1AttDec
	UBYTE	sid_Envelope1SusRel
	UBYTE	sid_Voice2FreqLow
	UBYTE	sid_Voice2FreqHigh
	UBYTE	sid_Voice2PulseLow
	UBYTE	sid_Voice2PulseHigh
	UBYTE	sid_Voice2Control
	UBYTE	sid_Envelope2AttDec
	UBYTE	sid_Envelope2SusRel
	UBYTE	sid_Voice3FreqLow
	UBYTE	sid_Voice3FreqHigh
	UBYTE	sid_Voice3PulseLow
	UBYTE	sid_Voice3PulseHigh
	UBYTE	sid_Voice3Control
	UBYTE	sid_Envelope3AttDec
	UBYTE	sid_Envelope3SusRel
	UBYTE	sid_FilterFreqLow
	UBYTE	sid_FilterFreqHigh
	UBYTE	sid_FilterControl
	UBYTE	sid_Volume
	UBYTE	sid_PotX
	UBYTE	sid_PotY
	UBYTE	sid_Osc3Random
	UBYTE	sid_Enve3Output


; ========================================================================;
; === Extended SoundInterfaceDevice ======================================;
; ========================================================================;

	STRUCTURE	ExtSoundInterfaceDevice,0
	STRUCT	ext_Gap1,$1d
	LABEL	ext_Counter			;Galway
	UBYTE	ext_Control		;The codes are listed below
	UBYTE	ext_AdrLow
	UBYTE	ext_AdrHigh
	STRUCT	ext_Gap2,$1d
	LABEL	ext_ToneLen			;Galway
	UBYTE	ext_EndAdrLow
	LABEL	ext_Volume			;Galway
	UBYTE	ext_EndAdrHigh
	LABEL	ext_Period			;Galway
	UBYTE	ext_Repeat
	STRUCT	ext_Gap3,$1d
	LABEL	ext_PeriodNull			;Galway
	UBYTE	ext_PeriodLow
	UBYTE	ext_PeriodHigh
	UBYTE	ext_Octave
	STRUCT	ext_Gap4,$1d
	UBYTE	ext_SamOrder		;The modes are listed below
	UBYTE	ext_RepAdrLow
	UBYTE	ext_RepAdrHigh

; --- Control Codes -------------------------------------------------------
CC_STOP		equ	$FD		;Stop sample
CC_START	equ	$FF		;Start sample with full volume
CC_STARTHALF	equ	$FE		;Start sample with half volume
CC_STARTQUART	equ	$FC		;Start sample with quarter volume

; --- Sample Order Modes --------------------------------------------------
SO_LOWHIGH	equ	$00
SO_HIGHLOW	equ	$01


; ========================================================================;
; === FourMemList ========================================================;
; ========================================================================;

	STRUCTURE	FourMemList,-4
	ULONG	fml_AllocLen
	APTR	fml_Next
	UWORD	fml_Adr
	UWORD	fml_EndAdr
	UBYTE	fml_Octave
	UBYTE	fml_SamOrder
	UWORD	fml_Len
	UBYTE	fml_AverageVol
	UBYTE	fml_Unused
	LABEL	fml_Sample


; ========================================================================;
; === SoundRememberList ==================================================;
; ========================================================================;

DATA_BLOCK	equ	31
BLOCKS_SET	equ	40

	STRUCTURE	RegisterData,0
	UBYTE	rd_Data
	UBYTE	rd_Repeats
	LABEL	rd_SIZEOF

	STRUCTURE	RegisterRememberList,0
	UWORD	rrl_NextBlock
	UWORD	rrl_PrecBlock
	STRUCT	rrl_RegData,rd_SIZEOF*DATA_BLOCK
	LABEL	rrl_SIZEOF

	STRUCTURE	SoundRememberList,0
	APTR	srl_Next
	APTR	srl_Preceed
	STRUCT	srl_Registers,rrl_SIZEOF*BLOCKS_SET
	LABEL	srl_SIZEOF

	STRUCTURE	SoundRememberParameters,0
	APTR	srp_SoundRemList
	ULONG	srp_MemoryUsage
	LABEL	srp_ORDINARY
	APTR	srp_NextFree_Base
	UWORD	srp_NextFree_Offset
	UWORD	srp_NextFree_Block
	ULONG	srp_Step
	STRUCT	srp_D400_Base,BLOCKS_SET*4	;40 * APTR
	STRUCT	srp_D400_Offset,BLOCKS_SET*2	;40 * UWORD
	STRUCT	srp_D400_Blocks,BLOCKS_SET*2	;40 * UWORD
	STRUCT	srp_D400_Data,BLOCKS_SET	;40 * UBYTE
	STRUCT	srp_D400_Repeat,BLOCKS_SET	;40 * UBYTE
	LABEL	srp_SIZEOF

	STRUCTURE	PlaybackSoundParameters,0
	APTR	psp_NextFree_Base
	UWORD	psp_NextFree_Offset
	UWORD	psp_NextFree_Block
	ULONG	psp_Step
	STRUCT	psp_D400_Base,BLOCKS_SET*4	;40 * APTR
	STRUCT	psp_D400_Offset,BLOCKS_SET*2	;40 * UWORD
	STRUCT	psp_D400_Blocks,BLOCKS_SET*2	;40 * UWORD
	STRUCT	psp_D400_Data,BLOCKS_SET	;40 * UBYTE
	STRUCT	psp_D400_Repeat,BLOCKS_SET	;40 * UBYTE
	LABEL	psp_EXTRA
	STRUCT	psp_D400_Counts,BLOCKS_SET	;40 * UBYTE
	LABEL	psp_SIZEOF

*************************************************************************
*=======================================================================*
*	INTERNAL DEFINITIONS						*
*=======================================================================*
*	C64 Clock NTSC	1.022727.1428 MHz
*	C64 Clock PAL	0.985248.4444 MHz
*     Amiga Clock NTSC	3.579545 MHz
*     Amiga Clock PAL	3.546895 MHz
FREQPAL		equ	60397988		;(CLOCK PAL Amiga/CLOCK PAL C64)*16777216
FREQNTSC	equ	60953965		;(CLOCK NTSC Amiga/CLOCK PAL C64)*16777216
ENVTIMEPAL	equ	709			;(CLOCK PAL Amiga/5)/1000
ENVTIMENTSC	equ	716			;(CLOCK NTSC Amiga/5)/1000
INTTIMEPAL50	equ	14188			;(CLOCK PAL Amiga/5)/50
INTTIMENTSC50	equ	14318			;(CLOCK NTSC Amiga/5)/50
INTTIMEPAL60	equ	11823			;(CLOCK PAL Amiga/5)/60
INTTIMENTSC60	equ	11932			;(CLOCK NTSC Amiga/5)/60
CONVCLOCKPAL	equ	47186			;(CLOCK PAL Amiga/CLOCK PAL C64)*(65536/5)
CONVCLOCKNTSC	equ	47620			;(CLOCK NTSC Amiga/CLOCK PAL C64)*(65536/5)
CONVFOURPAL	equ	29491			;(CLOCK PAL Amiga/CLOCK PAL C64)*8192
CONVFOURNTSC	equ	29763			;(CLOCK NTSC Amiga/CLOCK PAL C64)*8192
hunkStatus	equ	$AFFF
hunkDecAdd	equ	$AFFE
hunkDecSub	equ	$AFFD
hunkIfStat	equ	$AFFC
hunkNextInst	equ	$AFFB
hunkNextInst0	equ	$FFFF
hunkNextInst1	equ	$FFFE
hunkNextInst2	equ	$FFFD
hunkMovepAbs	equ	$AFFA
hunkMovepInd	equ	$AFF9
*=======================================================================*
*	AMIGA CUSTOM AND CIA DEFINITIONS				*
*=======================================================================*

VPOSR		equ	vposr
VHPOSR		equ	vhposr

DMACONR		equ	dmaconr
DMACON		equ	dmacon

INTENAR		equ	intenar
INTREQR		equ	intreqr
INTENA		equ	intena
INTREQ		equ	intreq

ADKCONR		equ	adkconr
ADKCON		equ	adkcon

AUD0LC		equ	aud0
AUD0LCH		equ	aud0
AUD0LCL		equ	aud0+$02
AUD0LEN		equ	aud0+$04
AUD0PER		equ	aud0+$06
AUD0VOL		equ	aud0+$08
AUD0DAT		equ	aud0+$0A

AUD1LC		equ	aud1
AUD1LCH		equ	aud1
AUD1LCL		equ	aud1+$02
AUD1LEN		equ	aud1+$04
AUD1PER		equ	aud1+$06
AUD1VOL		equ	aud1+$08
AUD1DAT		equ	aud1+$0A

AUD2LC		equ	aud2
AUD2LCH		equ	aud2
AUD2LCL		equ	aud2+$02
AUD2LEN		equ	aud2+$04
AUD2PER		equ	aud2+$06
AUD2VOL		equ	aud2+$08
AUD2DAT		equ	aud2+$0A

AUD3LC		equ	aud3
AUD3LCH		equ	aud3
AUD3LCL		equ	aud3+$02
AUD3LEN		equ	aud3+$04
AUD3PER		equ	aud3+$06
AUD3VOL		equ	aud3+$08
AUD3DAT		equ	aud3+$0A


*=======================================================================*
*	MACRO DEFINITIONS						*
*=======================================================================*

SoundRemTable	MACRO
		dc.w	$D400,$D401,$D402,$D403,$D404,$D405,$D406,$D407
		dc.w	$D408,$D409,$D40A,$D40B,$D40C,$D40D,$D40E,$D40F
		dc.w	$D410,$D411,$D412,$D413,$D414,$D415,$D416,$D417
		dc.w	$D418,$D41D,$D41E,$D41F,$D43D,$D43E,$D43F,$D45D
		dc.w	$D45E,$D45F,$D47D,$D47E,$D47F,$DC04,$DC05,$D420
		dc.w	$0000
		ENDM

MMU2		MACRO
		move.b	0(a3,d7.l),d6
		bmi.s	\1
		ENDM

INPUT		MACRO
		lea	.1(pc),a2
		jmp	ReadIO
.1
		ENDM

_OUTPUT		MACRO
		move.l	d7,a2
		moveq	#$00,d7
		move.b	0(a3,a2.l),d7
		jmp	WriteIO
		ENDM

_OUTPUT2	MACRO
		jmp	WriteIO
		ENDM

CheckDecMode	MACRO
		btst	#11,d5
		beq.s	.1
		tst.w	d4
		bmi.s	.2
		move.l	#$00010000,a2
		add.l	a2,a4
		add.l	a2,a5
		ori.w	#$8000,d4
		jmp	.2(pc,a2.l)
.1		tst.w	d4
		bpl.s	.2
		move.l	#$FFFF0000,a2
		add.l	a2,a4
		add.l	a2,a5
		andi.w	#$7fff,d4
		jmp	.2(pc,a2.l)
.2
		ENDM

SetAStatus	MACRO
		dc.w	hunkStatus
		ENDM

DecimalMode1	MACRO
		dc.w	hunkDecAdd	;abcd.b d6,d0 - addx.b d6,d0
		ENDM

DecimalMode2	MACRO
		dc.w	hunkDecSub	;sbcd.b	d6,d0 - subx.b d6,d0
		ENDM

IfStatus	MACRO
		dc.w	hunkIfStat
		ENDM

Next_Inst	MACRO
		move.b	(a6)+,-(a7)
		move.w	(a7)+,d7
		clr.b	d7
		jmp	0(a4,d7.w)
		ENDM

NextInst	MACRO
		dc.w	hunkNextInst,hunkNextInst0
		dc.l	$FFFFFFFF
		dc.w	$FFFF
		ENDM

NextInstStat	MACRO
		dc.w	hunkNextInst,hunkNextInst1
		dc.l	$FFFFFFFF
		dc.w	$FFFF
		ENDM

NextInstStat2	MACRO
		dc.w	hunkNextInst,hunkNextInst2
		dc.l	$FFFFFFFF
		dc.w	$FFFF
		ENDM

MovepAbs	MACRO
		dc.w	hunkMovepAbs
		dc.l	$FFFFFFFF
		dc.w	$FFFF
		ENDM


MovepInd	MACRO
		dc.w	hunkMovepInd
		dc.l	$FFFFFFFF, $FFFFFFFF
		ENDM

; ========================================================================;
; === Module Header ======================================================;
; ========================================================================;

SID_HEADER	EQU	"PSID"
SID_VERSION	EQU	2
HEADERINFO_SIZE EQU	32

SID_SIDSONG	EQU	(0)
SIDF_SIDSONG	EQU	(1<<SID_SIDSONG)

		STRUCTURE SIDHeader,0
		ULONG	sidh_id
		UWORD	sidh_version
		UWORD	sidh_length
		UWORD	sidh_start
		UWORD	sidh_init
		UWORD	sidh_main
		UWORD	sidh_number
		UWORD	sidh_defsong
		ULONG	sidh_speed
		STRUCT	sidh_name,HEADERINFO_SIZE
		STRUCT	sidh_author,HEADERINFO_SIZE
		STRUCT	sidh_copyright,HEADERINFO_SIZE
		UWORD	sidh_flags
		ULONG	sidh_reserved
		LABEL	sidh_sizeof

	ENDC


