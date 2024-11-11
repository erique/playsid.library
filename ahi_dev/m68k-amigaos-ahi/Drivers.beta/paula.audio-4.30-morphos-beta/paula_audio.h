#ifndef PAULA_AUDIO_H
#define PAULA_AUDIO_H
/*
:ts=4

  paula.audio MorphOS version
  © 2002-2003 Sigbjørn "CISC" Skjæret and Harry "Piru" Sintonen
*/

#include <exec/memory.h>
#include <exec/resident.h>
#include <exec/initializers.h>
#include <exec/execbase.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <dos/dostags.h>
#include <graphics/gfxbase.h>
#include <proto/graphics.h>
#include <intuition/intuitionbase.h>
#include <intuition/screens.h>
#include <proto/intuition.h>
#include <utility/utility.h>
#include <utility/hooks.h>
#include <proto/utility.h>
#include <proto/cardres.h>
#include <proto/misc.h>

#include <devices/ahi.h>
#include <libraries/ahi_sub.h>
#include <devices/audio.h>
#include <proto/timer.h>

#include <resources/misc.h>
#include <resources/card.h>

#include <hardware/cia.h>
#include <hardware/custom.h>
#include <hardware/dmabits.h>
#include <hardware/intbits.h>


#define BETTERTIMING
#define USE_HWPOKEMODE		1


#if USE_HWPOKEMODE

#define PAULACHANNELSSEMA "paula.audio channels"
struct paulasemaphore
{
	struct SignalSemaphore ps_sema;

	UBYTE                  ps_name[sizeof(PAULACHANNELSSEMA) + 1];
};

#endif /* USE_HWPOKEMODE */

struct paulaBase
{
	struct Library pb_Lib;
	UBYTE pb_Flags;
	UBYTE pb_Pad1;
	UWORD pb_Pad2;

	struct ExecBase *pb_SysBase;
	BPTR pb_SegList;
	struct GfxBase *pb_GfxBase;
	struct Library *pb_UtilityBase;
	struct DosLibrary *pb_DOSBase;
	struct IntuitionBase *pb_IntuitionBase;
	struct Library *pb_TimerBase;
	struct Library *pb_MiscBase;
	struct Library *pb_CardResource;
	ULONG pb_AudioFreq;	/* PAL/NTSC clock constant */
};

#define SysBase			paulaBase->pb_SysBase
#define GfxBase			paulaBase->pb_GfxBase
#define UtilityBase		paulaBase->pb_UtilityBase
#define DOSBase			paulaBase->pb_DOSBase
#define IntuitionBase	paulaBase->pb_IntuitionBase
#define TimerBase		paulaBase->pb_TimerBase
#define MiscBase		paulaBase->pb_MiscBase
#define CardResource	paulaBase->pb_CardResource


#define AQuote(string) #string								/* Put quotes around the whole thing */
#define AVersion(major,minor) AQuote(major ## . ## minor)	/* Concatenate the two version-numbers */
#define AmVersion(major,minor) AVersion(major,minor)		/* We need to do it this way to elimate the blank spaces */

#ifdef __GNUC__
#ifdef __MORPHOS__
#include <emul/emulinterface.h>
#include <emul/emulregs.h>
#include <public/quark/quark.h>
#include <public/proto/quark/syscall_protos.h>
#define REG(reg,arg) arg
#else
#define REG(reg,arg) arg __asm(#reg)
#define LIB __saveds
#define ASM
#endif
#else
#define REG(reg,arg) register __ ## reg arg
#define LIB __saveds __asm
#define ASM __asm
#endif

#define LIB_NAME		"paula.audio"
#define LIB_VERSION		4
#define LIB_REVISION	30
#define LIB_DATE		"(30.03.03)"

#ifndef LIBCPU
	#ifdef __MORPHOS__
		#define LIBCPU " [MorphOS]"
	#else
		#if defined(_M68060) || defined(mc68060)
			#if defined(_M68881) || defined(__HAVE_68881__)
				#define LIBCPU " [060/FPU]"
			#else
				#define LIBCPU " [060]"
			#endif
		#elif defined(_M68040) || defined(mc68040)
			#if defined(_M68881) || defined(__HAVE_68881__)
				#define LIBCPU " [040/FPU]"
			#else
				#define LIBCPU " [040]"
			#endif
		#elif defined(_M68030) || defined(mc68030)
			#if defined(_M68881) || defined(__HAVE_68881__)
				#define LIBCPU " [030/FPU]"
			#else
				#define LIBCPU " [030]"
			#endif
		#elif defined(_M68020) || defined(mc68020)
			#if defined(_M68881) || defined(__HAVE_68881__)
				#define LIBCPU " [020/FPU]"
			#else
				#define LIBCPU " [020]"
			#endif
		#else
			#define LIBCPU
		#endif
	#endif
#endif

#define LIB_ID LIB_NAME " " AmVersion(LIB_VERSION,LIB_REVISION) " " LIB_DATE LIBCPU


#ifdef __MORPHOS__
struct Library *LibInit(struct paulaBase *paulaBase, BPTR SegList, struct ExecBase *sysbase);
struct Library *LIB_Open(void);
BPTR LIB_Close(void);
BPTR LIB_Expunge(void);

ULONG AHIsub_AllocAudio(void);
void AHIsub_FreeAudio(void);
void AHIsub_Disable(void);
void AHIsub_Enable(void);
ULONG AHIsub_Start(void);
ULONG AHIsub_Update(void);
ULONG AHIsub_Stop(void);
ULONG AHIsub_SetVol(void);
ULONG AHIsub_SetFreq(void);
ULONG AHIsub_SetSound(void);
ULONG AHIsub_SetEffect(void);
ULONG AHIsub_LoadSound(void);
ULONG AHIsub_UnloadSound(void);
LONG AHIsub_GetAttr(void);
LONG AHIsub_HardwareControl(void);
#else
struct Library * ASM LibInit(REG(d0, struct paulaBase *paulaBase), REG(a0, BPTR SegList), REG(a6, struct ExecBase *sysbase));
struct Library * ASM LIB_Open(REG(a6, struct paulaBase *paulaBase));
BPTR ASM LIB_Close(REG(a6, struct paulaBase *paulaBase));
BPTR ASM LIB_Expunge(REG(a6, struct paulaBase *paulaBase));

ULONG AHIsub_AllocAudio(REG(a1, struct TagItem *), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
void AHIsub_FreeAudio(REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
void AHIsub_Disable(REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
void AHIsub_Enable(REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
ULONG AHIsub_Start(REG(d0, ULONG), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
ULONG AHIsub_Update(REG(d0, ULONG), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
ULONG AHIsub_Stop(REG(d0, ULONG), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
ULONG AHIsub_SetVol(REG(d0, UWORD), REG(d1, Fixed), REG(d2, sposition), REG(a2, struct AHIAudioCtrlDrv *), REG(d3, ULONG), REG(a6, struct paulaBase *));
ULONG AHIsub_SetFreq(REG(d0, UWORD), REG(d1, ULONG), REG(a2, struct AHIAudioCtrlDrv *), REG(d2, ULONG), REG(a6, struct paulaBase *));
ULONG AHIsub_SetSound(REG(d0, UWORD), REG(d1, UWORD), REG(d2, ULONG), REG(d3, LONG), REG(a2, struct AHIAudioCtrlDrv *), REG(d4, ULONG), REG(a6, struct paulaBase *));
ULONG AHIsub_SetEffect(REG(a0, APTR), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
ULONG AHIsub_LoadSound(REG(d0, UWORD), REG(d1, ULONG), REG(a0, struct AHISampleInfo *), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
ULONG AHIsub_UnloadSound(REG(d0, UWORD), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
LONG AHIsub_GetAttr(REG(d0, ULONG), REG(d1, LONG), REG(d2, LONG), REG(a1, struct TagItem *), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
LONG AHIsub_HardwareControl(REG(d0, ULONG), REG(d1, LONG), REG(a2, struct AHIAudioCtrlDrv *), REG(a6, struct paulaBase *));
#endif


/* used in DMA mode */
struct Channel
{
	UWORD	ch_IntMask;		/* This channels interrupt bit */
	UWORD	ch_DMAMask;		/* This channels DMA bit */
	UWORD	ch_Stereo;		/* 0 = Left, 1 = Right */
	UWORD	ch_DMALength;
	UBYTE	ch_EndOfSample;	/* Flag */
	UBYTE	ch_NoInt;		/* SetFreq() must not cause interrupt */
	UWORD	ch_Pad;
	volatile struct AudChannel *ch_RegBase;		/* This channels hardware register base */

	ULONG	ch_Cleared;		/* Samples already cleared */
	ULONG	ch_Cleared2;	/* Samples already cleared */

	ULONG	ch_Count;		/* How many samples played? (In samples) */

	APTR	ch_Address;		/* Current sample address */
	APTR	ch_NextAddress;	/* Next sample address */

	ULONG	ch_Offset;		/* Where are we playing? (In samples) */
	ULONG	ch_NextOffset;	/* Next... */

	ULONG	ch_Length;		/* Current sample length (In samples) */
	ULONG	ch_NextLength;	/* Next sample length */

	ULONG	ch_Type;		/* Current sample type */
	ULONG	ch_NextType;	/* Next sample type */

	UWORD	ch_PerVol[2];
	UWORD	ch_NextPerVol[2];

	UWORD	ch_VolumeNorm;
	UWORD	ch_NextVolumeNorm;

	UWORD	ch_Scale;		/* Current frequency scale (2^ch_Scale) */
	UWORD	ch_NextScale;	/* Next frequency scale */

	struct AHISoundMessage	ch_SndMsg;
};

#define ch_Period ch_PerVol[0]			/* Current period (0 = stopped) */
#define ch_Volume ch_PerVol[1]			/* Current volume (scaled) */
#define ch_NextPeriod ch_NextPerVol[0]	/* Next period */
#define ch_NextVolume ch_NextPerVol[1]	/* Next volume  (scaled) */

/* used in DMA mode */
struct Sound
{
	ULONG	so_Type;
	APTR	so_Address;
	ULONG	so_Length;
};

/* Record data structure */
struct Record
{
	APTR	rc_AuraAddress;

	ULONG *rc_RecFillPtr;
	UWORD	rc_RecFillCount;
	UWORD	rc_Pad2;
	APTR	rc_RecBuffer1;
	APTR	rc_RecBuffer2;
	struct Interrupt *rc_RecSoftIntPtr;
};

/* ahiac_DriverData points to this structure */
struct Paula
{
	UBYTE	p_Flags;
	UBYTE	p_Parallel;			/* TRUE if parport allocated */
	UBYTE	p_Filter;			/* TRUE if filter was on when alocating */
	UBYTE	p_Pad0;
	UWORD	p_DisableCount;		/* AHIsub_Enable/AHIsub_Disable cnt */
	UWORD	p_IRQMask;

	struct paulaBase *p_PaulaBase;		/* Pointer to library base (DMA only) */
	struct AHIAudioCtrlDrv *p_AudioCtrl;		/* Backpointer to AudioCtrl struct. */

	UBYTE	p_SwapChannels;		/* TRUE if left/right should be swapped */
	UBYTE	p_ScreenIsDouble;	/* TRUE if screen mode allows >28kHz */

	UWORD	p_MixTaskPri;
	struct Process *p_MixTask;
	APTR	p_ReplyTask;

	ULONG	p_MinBufferLength;	/* Minimum length of chipmem playbuffer */
	APTR	p_CalibrationTable;	/* Pointer to 14 bit conversion tables */

	APTR	p_DMAbuffer;		/* Chipmem play buffer */
	ULONG	p_DoubleBufferOffset;	/* Buffer flag */

	APTR	p_AudPtrs[8];		/* Pointers to chipmem play buffer */


	struct MsgPort *p_audioport;		/* For audio.device */
	struct IOAudio *p_audioreq;			/* For audio.device */
	ULONG	p_audiodev;			/* For audio.device */

#if USE_HWPOKEMODE

	struct SignalSemaphore *p_paulasema;
	struct Interrupt *p_oldaudint[4];

#endif /* USE_HWPOKEMODE */

	APTR	p_ParBitsUser;		/* Parallel port locking */
	APTR	p_ParPortUser;		/* Parallel port locking */
	APTR	p_SerBitsUser;		/* Serial port locking */
	struct CardHandle *p_CardHandle;		/* Aura PCMCIA card handle */

	struct Interrupt p_PlayInt;	/* Player hardware interrupt */
	struct Interrupt p_PlaySoftInt;	/* Player software interrupt (mixing only) */
	struct Interrupt p_RecInt;	/* Recorder hardware interrupt (mixing only) */
	struct Interrupt p_RecSoftInt;	/* Recorder software interrupt (mixing only) */

	UWORD	p_AudPer;			/* Playback period (mixing only) */
	UWORD	p_OutputVolume;		/* Hardware volume (mixing only) */
	UWORD	p_MonitorVolume;	/* Monitor volume (mixing only) */
	UWORD	p_Input;			/* Input select (mixing only) */

#ifdef BETTERTIMING
	ULONG	p_LoopLeftovers;	/* (mixing only) */
	ULONG	p_SampleFrameShift;	/* Size of sample fram is 2^x (mixing only) */
#else
	ULONG	p_LoopTimes;		/* (mixing only) */
#endif

	APTR	p_PlayerHook;		/* PlayerHook */
	ULONG	p_Reserved;
	APTR	p_PlayerEntry;		/* p_PlayerHook->h_Entry */

	APTR	p_MixHook;			/* MixingHook (mixing only) */
	APTR	p_Mixbuffer;
	APTR	p_MixEntry;			/* p_MixHook->h_Entry */

	struct Record p_Record;

	ULONG	p_rmType;			/* Message used with SamplerFunc() */
	APTR	p_rmBuffer;
	ULONG	p_rmLength;

	ULONG	p_EClock;			/* System E clock freq. (DMA only) */
	ULONG	p_EPeriod;			/* PlayerFunc() E clk period (DMA only) */
	struct EClockVal p_EAlarm;	/* E Clock to wait for (DMA only) */
	struct MsgPort p_TimerPort;	/* (DMA only) */
	struct Interrupt p_TimerInt;	/* (DMA only) */
	struct timerequest *p_TimerReq;			/* Used to drive PlayerFunc() (DMA only) */
	UBYTE	p_TimerDev;			/* (DMA only) */
	UBYTE	p_TimerPad;
	UWORD	p_TimerCommFlag;	/* Used to end timer (DMA only) */

	ULONG	p_MasterVolume;		/* Effect parameter (DMA only) */
	struct AHIEffChannelInfo *p_ChannelInfo;		/* Effect structure (DMA only) */

	struct Sound *p_Sounds;
	struct Channel p_Channels[4];	/* DMA playback channel info */

	UBYTE	p_CalibrationArray[256];	/* 14 bit calibration prefs */
};

#define p_RecIntDataAura p_Record	/* Record data structure for Aura sampl. */
#define p_RecIntData     p_Record
#define p_AuraAddress    p_Record.rc_AuraAddress
#define p_RecFillPtr     p_Record.rc_RecFillPtr
#define p_RecFillCount   p_Record.rc_RecFillCount
#define p_RecBuffer1     p_Record.rc_RecBuffer1
#define p_RecBuffer2     p_Record.rc_RecBuffer2
#define p_RecSoftIntPtr  p_Record.rc_RecSoftIntPtr
#define p_RecordMessage  p_rmType

#endif /* PAULA_AUDIO_H */
