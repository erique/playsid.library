/*
:ts=4

  paula.audio MorphOS version
  © 2002-2003 Sigbjørn "CISC" Skjæret and Harry "Piru" Sintonen
*/

#include "paula_audio.h"

#define DEBUG_DMA(x)	;


#undef CUSTOM
#define CIAA	((volatile struct CIA *)0x00BFE001)
#define CIAB	((volatile struct CIA *)0x00BFD000)
#define CUSTOM	((volatile struct Custom *)0x00DFF000)

#define INTF_AUDIO	(INTF_AUD3 | INTF_AUD2 | INTF_AUD1 | INTF_AUD0)

#define PALFREQ		(3546895)
#define NTSCFREQ	(3579545)
#define MINPER		(62)

#define DMABUFFSAMPLES	(512)	/* 8 of these will be allocated! */
#define RECORDSAMPLES	(1024)

#define EXTRASAMPLES	(4)
#define EXTRABUFFSIZE	(EXTRASAMPLES*8)	/* 4 samples of max size ( 2×32 bit: hifi stereo ) */

/* paula.audio extra tags */
#define AHIDB_Paula14Bit	(AHIDB_UserBase+0)
#define AHIDB_PaulaTable	(AHIDB_UserBase+1)
#define AHIDB_PaulaDMA		(AHIDB_UserBase+2)

#define PB_14BIT	(0)
#define PF_14BIT	(1<<PB_14BIT)
#define PB_HIFI		(1)
#define PF_HIFI		(1<<PB_HIFI)
#define PB_STEREO	AHIACB_STEREO	/* =2 */
#define PF_STEREO	AHIACF_STEREO
#define PB_DMA		(3)
#define PF_DMA		(1<<PB_DMA)


/* Reserved library-function and dummy entrypoint */
LONG LIB_Reserved(void)
{
	return -1;
}

static const ULONG LibVectors[] =
{
#ifdef __MORPHOS__
	FUNCARRAY_32BIT_NATIVE,
#endif
	(ULONG) &LIB_Open,
	(ULONG) &LIB_Close,
	(ULONG) &LIB_Expunge,
	(ULONG) &LIB_Reserved,

	(ULONG) &AHIsub_AllocAudio,
	(ULONG) &AHIsub_FreeAudio,
	(ULONG) &AHIsub_Disable,
	(ULONG) &AHIsub_Enable,
	(ULONG) &AHIsub_Start,
	(ULONG) &AHIsub_Update,
	(ULONG) &AHIsub_Stop,
	(ULONG) &AHIsub_SetVol,
	(ULONG) &AHIsub_SetFreq,
	(ULONG) &AHIsub_SetSound,
	(ULONG) &AHIsub_SetEffect,
	(ULONG) &AHIsub_LoadSound,
	(ULONG) &AHIsub_UnloadSound,
	(ULONG) &AHIsub_GetAttr,
	(ULONG) &AHIsub_HardwareControl,
	0xFFFFFFFF
};

struct LibInitStruct
{
	ULONG	LibSize;
	void	*FuncTable;
	void	*DataTable;
	void	(*InitFunc)(void);
};

struct LibInitStruct LibInitStruct =
{
	sizeof(struct paulaBase),
	(void *) LibVectors,
	NULL,
	(void (*)(void)) &LibInit
};

static const char LibVersion[] = "$VER: " LIB_ID;

static const struct Resident RomTag __attribute__((__aligned__(2))) =
{
	RTC_MATCHWORD,
	(struct Resident *) &RomTag,
	(struct Resident *) &RomTag + 2,
#ifdef __MORPHOS__
	RTF_EXTENDED | RTF_PPC | RTF_AUTOINIT,
#else
	RTF_AUTOINIT,
#endif
	LIB_VERSION,
	NT_LIBRARY,
	0,
	LIB_NAME,
	(UBYTE *) &LibVersion[6],
	&LibInitStruct
#ifdef __MORPHOS__
	,LIB_REVISION,
	NULL		/* no tags for now */
#endif
};


#ifdef __MORPHOS__
ULONG __abox__  = 1;
ULONG __amigappc__ = 1;
#endif


static void LibCleanup(struct paulaBase *paulaBase)
{
	if (DOSBase)
	{
		CloseLibrary((struct Library *)DOSBase);
		DOSBase = NULL;
	}

	if (UtilityBase)
	{
		CloseLibrary((struct Library *)UtilityBase);
		UtilityBase = NULL;
	}

	if (GfxBase)
	{
		CloseLibrary((struct Library *)GfxBase);
		GfxBase = NULL;
	}

	if (IntuitionBase)
	{
		CloseLibrary((struct Library *)IntuitionBase);
		IntuitionBase = NULL;
	}

	FreeMem((APTR)((ULONG)(paulaBase) - (ULONG)(paulaBase->pb_Lib.lib_NegSize)),
			paulaBase->pb_Lib.lib_NegSize + paulaBase->pb_Lib.lib_PosSize);
}

BPTR LibExpunge(struct paulaBase *paulaBase)
{
	if ((paulaBase->pb_Lib.lib_OpenCnt == 0))
	{
		BPTR seglist;

		seglist = paulaBase->pb_SegList;

		Forbid();
		Remove(&paulaBase->pb_Lib.lib_Node);
		Permit();

		LibCleanup(paulaBase);

		return seglist;
	}
	else
		paulaBase->pb_Lib.lib_Flags |= LIBF_DELEXP;

	return 0L;
}

#ifdef __MORPHOS__
struct Library *LibInit(struct paulaBase *paulaBase, BPTR SegList, struct ExecBase *sysbase)
#else
struct Library * ASM LibInit(REG(d0, struct paulaBase *paulaBase), REG(a0, BPTR SegList), REG(a6, struct ExecBase *sysbase))
#endif
{
	SysBase = sysbase;

	if ((DOSBase = (struct DosLibrary *)OpenLibrary("dos.library", 37))
	 && (UtilityBase = (struct Library *)OpenLibrary("utility.library", 37))
	 && (GfxBase = (APTR)OpenLibrary("graphics.library", 39))
	 && (IntuitionBase = (APTR)OpenLibrary("intuition.library", 37))
	 && (MiscBase = OpenResource("misc.resource"))
	)
	{
		CardResource = OpenResource("card.resource");

		paulaBase->pb_Lib.lib_Revision     = LIB_REVISION;
		paulaBase->pb_SegList              = SegList;

		paulaBase->pb_AudioFreq = ((GfxBase->DisplayFlags & REALLY_PAL) ? PALFREQ : NTSCFREQ);

		return &paulaBase->pb_Lib;
	}

	LibCleanup(paulaBase);
	return NULL;
}

#ifdef __MORPHOS__
struct Library *LIB_Open(void)
{
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
struct Library * ASM LIB_Open(REG(a6, struct paulaBase *paulaBase))
{
#endif
	paulaBase->pb_Lib.lib_Flags &= ~LIBF_DELEXP;
	paulaBase->pb_Lib.lib_OpenCnt++;

	return &paulaBase->pb_Lib;
}

#ifdef __MORPHOS__
BPTR LIB_Close(void)
{
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
BPTR ASM LIB_Close(REG(a6, struct paulaBase *paulaBase))
{
#endif
	if (paulaBase->pb_Lib.lib_OpenCnt > 0) paulaBase->pb_Lib.lib_OpenCnt--;

	if ((paulaBase->pb_Lib.lib_OpenCnt == 0) && (paulaBase->pb_Lib.lib_Flags & LIBF_DELEXP))
		return LibExpunge(paulaBase);

	return 0L;
}

#ifdef __MORPHOS__
BPTR LIB_Expunge(void)
{
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
BPTR ASM LIB_Expunge(REG(a6, struct paulaBase *paulaBase))
{
#endif
	return LibExpunge(paulaBase);
}


#ifdef __MORPHOS__
#define BeginIO(MyIORequest) \
{ \
	struct IORequest *_MyIORequest = (struct IORequest *)(MyIORequest); \
	REG_A1 = (ULONG) _MyIORequest; \
	REG_A6 = (ULONG) _MyIORequest->io_Device; \
	(*MyEmulHandle->EmulCallDirectOS)(-30); \
}
#endif

#ifndef NEWLIST
#define	NEWLIST(MyList) \
{ struct List *_MyList = (MyList); \
	_MyList->lh_TailPred = (struct Node *) _MyList; \
	_MyList->lh_Tail = (struct Node *) NULL; \
	_MyList->lh_Head = (struct Node *) &_MyList->lh_Tail; \
}
#endif

static __inline LONG GetVarInt(STRPTR name, LONG def, struct paulaBase *paulaBase)
{
	LONG ret;
	UBYTE buf[8];

	if ((ret=GetVar(name, buf, sizeof(buf), 0)) > 0)
	{
		int i;
		ULONG len = ret;

		ret = 0;
		for (i=0; i < len && buf[i] >= '0' && buf[i] <= '9'; i++)
		{
			ret = 10 * ret + (buf[i] - '0');
		}
	}
	else
		ret = def;

	return ret;
}

static void __inline Paula_Disable(struct Paula *paula, struct paulaBase *paulaBase)
{
	Disable();
	CUSTOM->intena = INTF_AUDIO;
	paula->p_DisableCount++;
	Enable();
}

static void __inline Paula_Enable(struct Paula *paula, struct paulaBase *paulaBase)
{
	Disable();
	if (paula->p_DisableCount > 0) paula->p_DisableCount--;
	if (paula->p_DisableCount == 0) CUSTOM->intena = paula->p_IRQMask;
	Enable();
}

static BOOL checkvideo(struct paulaBase *paulaBase)
{
	LONG samplelimit;

	if ((samplelimit = GetVarInt("AHIpaulaSampleLimit", -1, paulaBase)) == -1)
	{
		if (GfxBase->ChipRevBits0 & (GFXF_HR_DENISE | GFXF_AA_LISA))
		{
			ULONG ilock;
			ULONG modeid;

			ilock = LockIBase(NULL);
			modeid = GetVPModeID(&IntuitionBase->FirstScreen->ViewPort);
			UnlockIBase(ilock);

			if (modeid & 0x40000000)
			{
				/* Native */
				struct MonitorInfo info;

				if (GetDisplayInfoData(NULL, (UBYTE *)&info, sizeof(struct MonitorInfo), DTAG_MNTR, modeid))
				{
					ULONG rows = (info.TotalRows - info.MinRow + 1) * 2;
					ULONG clock = info.TotalColorClocks * info.TotalRows;

					if (rows)
					{
						if ((clock / rows) <= 64) return TRUE;
					}
				}
			}
			else
			{
				/* GfxCard */
				APTR p96task;

				Forbid();	/* Make PatchWork happy */
				p96task = FindTask("Picasso96");
				Permit();

				if (p96task)
				{
					/* Picasso96 */
					UBYTE buf[4];

					if (GetVar("Picasso96/AmigaVideo", buf, sizeof(buf), 0) != -1)
					{
						if (buf[0] == '3' && buf[1] == '1') return TRUE;
					}
				}
				else
				{
					/* CyberGraphX */
					if (GfxBase->copinit->fm0[0] != 0x01FC) return TRUE;
					if (GfxBase->copinit->fm0[1] & 0xC000) return TRUE;
				}
			}
		}
	}
	else if (samplelimit > 0)
		return TRUE;

	return FALSE;
}

static UWORD calcperiod(ULONG *MixFreq, struct paulaBase *paulaBase)
{
	ULONG temp = paulaBase->pb_AudioFreq;
	ULONG mixfreq = *MixFreq;
	UWORD period;

	period = temp / mixfreq;
	temp %= mixfreq;
	temp <<= 1;

	if (temp >= mixfreq) period++;

	temp = (checkvideo(paulaBase)) ? MINPER * 2 : MINPER;

	if (temp > period) period = temp;

	temp = mixfreq;
	*MixFreq = paulaBase->pb_AudioFreq / period;
	temp %= period;
	temp <<= 1;

	if (temp >= period) (*MixFreq)++;

	return period;
}

static const ULONG freqlist[] =
{
	4410,
	4800,
	5513,
	6000,
	7350,
	8000,
	9600,
	11025,
	12000,
	14700,
	16000,
	17640,
	18900,
	19200,
	22050,
	24000,
	27429,
/* ECS */
	29400,
	32000,
	33075,
	37800,
	44100,
	48000,

	0xFFFFFFFF
};

static ULONG findfreq(ULONG freq)
{
	ULONG index = 0;
	ULONG maxidx = sizeof(freqlist) / sizeof(*freqlist) - 2;

	while (index <= maxidx)
	{
		if (freqlist[index] >= freq || index == maxidx)
			break;

		index++;
	}

	return index;
}

static void CreateTable(UBYTE *table, UBYTE *array)
{
	LONG i, steps, stretch;
	WORD hi, lo, count, add;
	BYTE *addtab;

	/* positive range */

	i = 127;
	steps = 0;
	addtab = (BYTE *)array + 128;

	do { steps += *addtab++; } while (i--);

	i = 32767;
	stretch = 32768;
	hi = lo = 0;
	addtab = (BYTE *)array + 128;
	count = add = *addtab++;

	for (;;)
	{
		if (count > 0)
		{
			*table++ = (UBYTE)hi;
			*table++ = (UBYTE)lo;
			stretch -= steps;

			if (stretch < 0)
			{
				stretch += 32768;
				lo++;
				count--;
			}

			if (!i--) break;
		}
		else
		{
			hi++;
			lo -= add;
			count += (add = *addtab++);
		}
	}

	/* negative range */

	i = 127;
	steps = 0;
	addtab = (BYTE *)array + 128;

	do { steps += *--addtab; } while (i--);

	i = 32767;
	stretch = 32768;
	hi = lo = -1;
	table += 65536;
	addtab = (BYTE *)array + 128;
	lo += (count = *--addtab);

	for (;;)
	{
		if (count > 0)
		{
			*--table = (UBYTE)lo;
			*--table = (UBYTE)hi;
			stretch -= steps;

			if (stretch < 0)
			{
				stretch += 32768;
				lo--;
				count--;
			}

			if (!i--) break;
		}
		else
		{
			hi--;
			lo += *--addtab;
			count += *addtab;
		}
	}
}

static __inline void ClearSample(ULONG samples, ULONG *dest)
{
	if ((samples = (samples + 3) >> 2))
	{
		while (samples--)
		{
			*dest++ = 0;
		}
	}
}

static __inline void CopySample(ULONG samples, LONG scale, ULONG *dst, const UBYTE *src)
{
	while (samples--)
	{
		*dst++ = src[scale * 0] << 24 |
		         src[scale * 1] << 16 |
		         src[scale * 2] << 8 |
		         src[scale * 3];

		src += scale * 4;
	}
}

static __inline void CopySampleM8S(ULONG samples, LONG offset, LONG scale, ULONG *dst, const UBYTE *src)
{
	if ((samples = (samples + 3) >> 2))
	{
		src += offset;

		if (src) CopySample(samples, scale, dst, src);
	}
}

static __inline void CopySampleM16S(ULONG samples, LONG offset, LONG scale, ULONG *dst, const UBYTE *src)
{
	if ((samples = (samples + 3) >> 2))
	{
		offset <<= 1;
		scale <<= 1;

		src += offset;

		if (src) CopySample(samples, scale, dst, src);
	}
}

static __inline void CopySampleS8S(ULONG samples, LONG offset, LONG scale, ULONG *dst, const UBYTE *src, struct Channel *channel)
{
	if ((samples = (samples + 3) >> 2))
	{
		offset <<= 1;
		scale <<= 1;

		src += offset;

		if (src)
		{
			src += channel->ch_Stereo;
			CopySample(samples, scale, dst, src);
		}
	}
}

static __inline void CopySampleS16S(ULONG samples, LONG offset, LONG scale, ULONG *dst, const UBYTE *src, struct Channel *channel)
{
	if ((samples = (samples + 3) >> 2))
	{
		offset <<= 2;
		scale <<= 2;

		src += offset;

		if (src)
		{
			src += channel->ch_Stereo * 2;
			CopySample(samples, scale, dst, src);
		}
	}
}

#ifdef __MORPHOS__
ULONG PlayerFunc_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
ULONG PlayerFunc(REG(a1, struct Paula *paula))
{
#endif
	struct AHIAudioCtrlDrv *audioctrl = paula->p_AudioCtrl;
	struct paulaBase *paulaBase = paula->p_PaulaBase;

	DEBUG_DMA(dprintf("PlayerFunc:\n"));

	/* Remove message */
	(void) GetMsg(&paula->p_TimerPort);

	if (paula->p_TimerCommFlag == 0)
	{
		struct EClockVal curr;
		struct EClockVal diff;
		struct Hook *hook;

		*((unsigned long long *)(&paula->p_EAlarm)) += paula->p_EPeriod;

		ReadEClock(&curr);

		if ((*((signed long long *)(&diff)) = *((unsigned long long *)(&paula->p_EAlarm)) - *((unsigned long long *)(&curr))) < 0)
		{
			diff.ev_hi = 0;
			diff.ev_lo = 1;
		}

		paula->p_TimerReq->tr_node.io_Command = TR_ADDREQUEST;
		paula->p_TimerReq->tr_time.tv_secs  = diff.ev_hi;
		paula->p_TimerReq->tr_time.tv_micro = diff.ev_lo;
		BeginIO(paula->p_TimerReq);

		Paula_Disable(paula, paulaBase);

		if (paula->p_ChannelInfo)
		{
			ULONG *offset = paula->p_ChannelInfo->ahieci_Offset;
			WORD chans = paula->p_ChannelInfo->ahieci_Channels;

			if (chans > 0)
			{
				struct Channel *channels = paula->p_Channels;

				while (chans--)
				{
					*offset++ = channels->ch_Offset;
					channels++;
				}

				if ((hook = paula->p_ChannelInfo->ahieci_Func))
				{
					DEBUG_DMA(dprintf("PlayerFunc: call channelinfo hook->h_Entry 0x%lx\n", hook->h_Entry));
#ifdef __MORPHOS__
					REG_A0 = (ULONG)hook;
					REG_A2 = (ULONG)audioctrl;
					REG_A1 = (ULONG)paula->p_ChannelInfo;
					(*MyEmulHandle->EmulCallDirect68k)(hook->h_Entry);
#else
					CallHookPkt(hook, audioctrl, paula->p_ChannelInfo);
#endif
				}
			}
		}

		if ((hook = audioctrl->ahiac_PlayerFunc))
		{
			DEBUG_DMA(dprintf("PlayerFunc: call playerfunc hook->h_Entry 0x%lx\n", hook->h_Entry));
#ifdef __MORPHOS__
			REG_A0 = (ULONG)hook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)NULL;
			(*MyEmulHandle->EmulCallDirect68k)(hook->h_Entry);
#else
			CallHookPkt(hook, audioctrl, NULL);
#endif
		}

		Paula_Enable(paula, paulaBase);
	}
	else
	{
		paula->p_TimerCommFlag = 0;
	}

	DEBUG_DMA(dprintf("PlayerFunc: done, return 0\n"));

	return 0;	/* Really necessary? */
}

#ifdef __MORPHOS__
static const struct EmulLibEntry PlayerFunc_GATE = { TRAP_LIB, 0, (void (*)(void))PlayerFunc_Entry };
#define PlayerFunc ((void(*)(void))&PlayerFunc_GATE)
#endif

#undef SysBase

void MixTask(void)
{
	struct ExecBase *SysBase = *(struct ExecBase **)4;
	struct paulaBase *paulaBase;
	struct Paula *paula;
	struct Task *mytask;
	ULONG signal;

	mytask = FindTask(NULL);
	paula = (struct Paula *)mytask->tc_UserData;
	paulaBase = paula->p_PaulaBase;

	while (1)
	{
		signal = Wait(SIGBREAKF_CTRL_C | SIGBREAKF_CTRL_D);

		if (signal & SIGBREAKF_CTRL_C) break;

		if (signal & SIGBREAKF_CTRL_D)
		{
			REG_A5 = (ULONG)paula->p_PlaySoftInt.is_Code;
			REG_A1 = (ULONG)paula->p_PlaySoftInt.is_Data;
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlaySoftInt.is_Code);
		}
	}

	Forbid();
	if (paula->p_ReplyTask) Signal(paula->p_ReplyTask, SIGF_SINGLE);
	/* Permit */
}

#ifdef __MORPHOS__
void Interrupt_Dummy_Entry(void)
{
#else
void Interrupt_Dummy(void)
{
#endif
	CUSTOM->intreq = INTF_AUDIO;
}

#ifdef __MORPHOS__
static const struct EmulLibEntry Interrupt_Dummy_GATE = { TRAP_LIBNR, 0, (void (*)(void))Interrupt_Dummy_Entry };
#define Interrupt_Dummy ((void(*)(void))&Interrupt_Dummy_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_Dummy_Entry(void)
{
#else
void SoftInt_Dummy(void)
{
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_Dummy_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_Dummy_Entry };
#define SoftInt_Dummy ((void(*)(void))&SoftInt_Dummy_GATE)
#endif

static const ULONG convtable[] =
{
	0x80808080,
	0x81818181,
	0x82828282,
	0x83838383,
	0x84848484,
	0x85858585,
	0x86868686,
	0x87878787,
	0x88888888,
	0x89898989,
	0x8a8a8a8a,
	0x8b8b8b8b,
	0x8c8c8c8c,
	0x8d8d8d8d,
	0x8e8e8e8e,
	0x8f8f8f8f,
	0x90909090,
	0x91919191,
	0x92929292,
	0x93939393,
	0x94949494,
	0x95959595,
	0x96969696,
	0x97979797,
	0x98989898,
	0x99999999,
	0x9a9a9a9a,
	0x9b9b9b9b,
	0x9c9c9c9c,
	0x9d9d9d9d,
	0x9e9e9e9e,
	0x9f9f9f9f,
	0xa0a0a0a0,
	0xa1a1a1a1,
	0xa2a2a2a2,
	0xa3a3a3a3,
	0xa4a4a4a4,
	0xa5a5a5a5,
	0xa6a6a6a6,
	0xa7a7a7a7,
	0xa8a8a8a8,
	0xa9a9a9a9,
	0xaaaaaaaa,
	0xabababab,
	0xacacacac,
	0xadadadad,
	0xaeaeaeae,
	0xafafafaf,
	0xb0b0b0b0,
	0xb1b1b1b1,
	0xb2b2b2b2,
	0xb3b3b3b3,
	0xb4b4b4b4,
	0xb5b5b5b5,
	0xb6b6b6b6,
	0xb7b7b7b7,
	0xb8b8b8b8,
	0xb9b9b9b9,
	0xbabababa,
	0xbbbbbbbb,
	0xbcbcbcbc,
	0xbdbdbdbd,
	0xbebebebe,
	0xbfbfbfbf,
	0xc0c0c0c0,
	0xc1c1c1c1,
	0xc2c2c2c2,
	0xc3c3c3c3,
	0xc4c4c4c4,
	0xc5c5c5c5,
	0xc6c6c6c6,
	0xc7c7c7c7,
	0xc8c8c8c8,
	0xc9c9c9c9,
	0xcacacaca,
	0xcbcbcbcb,
	0xcccccccc,
	0xcdcdcdcd,
	0xcececece,
	0xcfcfcfcf,
	0xd0d0d0d0,
	0xd1d1d1d1,
	0xd2d2d2d2,
	0xd3d3d3d3,
	0xd4d4d4d4,
	0xd5d5d5d5,
	0xd6d6d6d6,
	0xd7d7d7d7,
	0xd8d8d8d8,
	0xd9d9d9d9,
	0xdadadada,
	0xdbdbdbdb,
	0xdcdcdcdc,
	0xdddddddd,
	0xdededede,
	0xdfdfdfdf,
	0xe0e0e0e0,
	0xe1e1e1e1,
	0xe2e2e2e2,
	0xe3e3e3e3,
	0xe4e4e4e4,
	0xe5e5e5e5,
	0xe6e6e6e6,
	0xe7e7e7e7,
	0xe8e8e8e8,
	0xe9e9e9e9,
	0xeaeaeaea,
	0xebebebeb,
	0xecececec,
	0xedededed,
	0xeeeeeeee,
	0xefefefef,
	0xf0f0f0f0,
	0xf1f1f1f1,
	0xf2f2f2f2,
	0xf3f3f3f3,
	0xf4f4f4f4,
	0xf5f5f5f5,
	0xf6f6f6f6,
	0xf7f7f7f7,
	0xf8f8f8f8,
	0xf9f9f9f9,
	0xfafafafa,
	0xfbfbfbfb,
	0xfcfcfcfc,
	0xfdfdfdfd,
	0xfefefefe,
	0xffffffff,
	0x00000000,
	0x01010101,
	0x02020202,
	0x03030303,
	0x04040404,
	0x05050505,
	0x06060606,
	0x07070707,
	0x08080808,
	0x09090909,
	0x0a0a0a0a,
	0x0b0b0b0b,
	0x0c0c0c0c,
	0x0d0d0d0d,
	0x0e0e0e0e,
	0x0f0f0f0f,
	0x10101010,
	0x11111111,
	0x12121212,
	0x13131313,
	0x14141414,
	0x15151515,
	0x16161616,
	0x17171717,
	0x18181818,
	0x19191919,
	0x1a1a1a1a,
	0x1b1b1b1b,
	0x1c1c1c1c,
	0x1d1d1d1d,
	0x1e1e1e1e,
	0x1f1f1f1f,
	0x20202020,
	0x21212121,
	0x22222222,
	0x23232323,
	0x24242424,
	0x25252525,
	0x26262626,
	0x27272727,
	0x28282828,
	0x29292929,
	0x2a2a2a2a,
	0x2b2b2b2b,
	0x2c2c2c2c,
	0x2d2d2d2d,
	0x2e2e2e2e,
	0x2f2f2f2f,
	0x30303030,
	0x31313131,
	0x32323232,
	0x33333333,
	0x34343434,
	0x35353535,
	0x36363636,
	0x37373737,
	0x38383838,
	0x39393939,
	0x3a3a3a3a,
	0x3b3b3b3b,
	0x3c3c3c3c,
	0x3d3d3d3d,
	0x3e3e3e3e,
	0x3f3f3f3f,
	0x40404040,
	0x41414141,
	0x42424242,
	0x43434343,
	0x44444444,
	0x45454545,
	0x46464646,
	0x47474747,
	0x48484848,
	0x49494949,
	0x4a4a4a4a,
	0x4b4b4b4b,
	0x4c4c4c4c,
	0x4d4d4d4d,
	0x4e4e4e4e,
	0x4f4f4f4f,
	0x50505050,
	0x51515151,
	0x52525252,
	0x53535353,
	0x54545454,
	0x55555555,
	0x56565656,
	0x57575757,
	0x58585858,
	0x59595959,
	0x5a5a5a5a,
	0x5b5b5b5b,
	0x5c5c5c5c,
	0x5d5d5d5d,
	0x5e5e5e5e,
	0x5f5f5f5f,
	0x60606060,
	0x61616161,
	0x62626262,
	0x63636363,
	0x64646464,
	0x65656565,
	0x66666666,
	0x67676767,
	0x68686868,
	0x69696969,
	0x6a6a6a6a,
	0x6b6b6b6b,
	0x6c6c6c6c,
	0x6d6d6d6d,
	0x6e6e6e6e,
	0x6f6f6f6f,
	0x70707070,
	0x71717171,
	0x72727272,
	0x73737373,
	0x74747474,
	0x75757575,
	0x76767676,
	0x77777777,
	0x78787878,
	0x79797979,
	0x7a7a7a7a,
	0x7b7b7b7b,
	0x7c7c7c7c,
	0x7d7d7d7d,
	0x7e7e7e7e,
	0x7f7f7f7f
};

static __inline void ri_Filled(struct Record *record, struct ExecBase *SysBase)
{
	APTR tmp;

	tmp = record->rc_RecBuffer2;
	record->rc_RecBuffer2 = record->rc_RecBuffer1;
	record->rc_RecFillPtr = record->rc_RecBuffer1 = tmp;

	record->rc_RecFillCount = RECORDSAMPLES;
	Cause(record->rc_RecSoftIntPtr);
}

#ifdef __MORPHOS__
void RecordInterrupt_Entry(void)
{
	volatile struct Custom *custom = (volatile struct Custom *)REG_A0;
	struct Record *record = (struct Record *)REG_A1;
	struct ExecBase *SysBase = (struct ExecBase *)REG_A6;
#else
void RecordInterrupt(REG(a0, volatile struct Custom *custom), REG(a1, struct Record *record), REG(a6, struct ExecBase *SysBase))
{
#endif
	ULONG sample;

	custom->intreq = INTF_AUD2 | INTF_AUD3;

	sample = convtable[CIAA->ciaprb];

	custom->aud[2].ac_dat = sample;
	custom->aud[3].ac_dat = sample;

	*record->rc_RecFillPtr++ = sample;

	if (!(--record->rc_RecFillCount)) ri_Filled(record, SysBase);
}

#ifdef __MORPHOS__
static const struct EmulLibEntry RecordInterrupt_GATE = { TRAP_LIBNR, 0, (void (*)(void))RecordInterrupt_Entry };
#define RecordInterrupt ((void(*)(void))&RecordInterrupt_GATE)
#endif

#ifdef __MORPHOS__
void RecordInterruptClarity_Entry(void)
{
	volatile struct Custom *custom = (volatile struct Custom *)REG_A0;
	struct Record *record = (struct Record *)REG_A1;
	struct ExecBase *SysBase = (struct ExecBase *)REG_A6;
#else
void RecordInterruptClarity(REG(a0, volatile struct Custom *custom), REG(a1, struct Record *record), REG(a6, struct ExecBase *SysBase))
{
#endif
	UBYTE buf[4];

	custom->intreq = INTF_AUD2 | INTF_AUD3;

	buf[1] = CIAA->ciaprb;
	CIAB->ciatahi;
	CIAB->ciatahi;
	CIAB->ciatahi;

	buf[0] = CIAA->ciaprb;
	CIAB->ciatahi;
	CIAB->ciatahi;
	CIAB->ciatahi;

	buf[3] = CIAA->ciaprb;
	CIAB->ciatahi;
	CIAB->ciatahi;
	CIAB->ciatahi;

	buf[2] = CIAA->ciaprb;

	*record->rc_RecFillPtr++ = *((ULONG *)buf);

	buf[0] = buf[2];
	buf[1] = buf[2];
	custom->aud[2].ac_dat = *((UWORD *)buf);
	custom->aud[3].ac_dat = *((UWORD *)buf);

	if (!(--record->rc_RecFillCount)) ri_Filled(record, SysBase);
}

#ifdef __MORPHOS__
static const struct EmulLibEntry RecordInterruptClarity_GATE = { TRAP_LIBNR, 0, (void (*)(void))RecordInterruptClarity_Entry };
#define RecordInterruptClarity ((void(*)(void))&RecordInterruptClarity_GATE)
#endif

#ifdef __MORPHOS__
void RecordInterruptAura_Entry(void)
{
	volatile struct Custom *custom = (volatile struct Custom *)REG_A0;
	struct Record *record = (struct Record *)REG_A1;
	struct ExecBase *SysBase = (struct ExecBase *)REG_A6;
#else
void RecordInterruptAura(REG(a0, volatile struct Custom *custom), REG(a1, struct Record *record), REG(a6, struct ExecBase *SysBase))
{
#endif
	UBYTE buf[4];

	custom->intreq = INTF_AUD2 | INTF_AUD3;

	*((ULONG *)buf) = *((ULONG *)record->rc_AuraAddress);
	*((ULONG *)buf) ^= 0x80008000;

	*record->rc_RecFillPtr++ = *((ULONG *)buf);

	buf[0] = buf[2];
	buf[1] = buf[2];
	custom->aud[2].ac_dat = *((UWORD *)buf);
	custom->aud[3].ac_dat = *((UWORD *)buf);

	if (!(--record->rc_RecFillCount)) ri_Filled(record, SysBase);
}

#ifdef __MORPHOS__
static const struct EmulLibEntry RecordInterruptAura_GATE = { TRAP_LIBNR, 0, (void (*)(void))RecordInterruptAura_Entry };
#define RecordInterruptAura ((void(*)(void))&RecordInterruptAura_GATE)
#endif

#ifdef __MORPHOS__
void RecordSoftInt_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void RecordSoftInt(REG(a1, struct Paula *paula))
{
#endif
	struct AHIAudioCtrlDrv *audioctrl = paula->p_AudioCtrl;

	CUSTOM->aud[2].ac_vol = paula->p_MonitorVolume;
	CUSTOM->aud[3].ac_vol = paula->p_MonitorVolume;

	paula->p_rmBuffer = paula->p_RecBuffer2;

	REG_A0 = (ULONG)audioctrl->ahiac_SamplerFunc;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_RecordMessage;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_SamplerFunc->h_Entry);
}

#ifdef __MORPHOS__
static const struct EmulLibEntry RecordSoftInt_GATE = { TRAP_LIBNR, 0, (void (*)(void))RecordSoftInt_Entry };
#define RecordSoftInt ((void(*)(void))&RecordSoftInt_GATE)
#endif

#ifdef __MORPHOS__
void AudioInterrupt2_Entry(void)
{
	volatile struct Custom *custom = (volatile struct Custom *)REG_A0;
	struct Paula *paula = (struct Paula *)REG_A1;
	struct ExecBase *SysBase = (struct ExecBase *)REG_A6;
#else
void AudioInterrupt2(REG(a0, volatile struct Custom *custom), REG(a1, struct Paula *paula), REG(a6, struct ExecBase *SysBase))
{
#endif
	APTR *audptr;

	custom->aud[0].ac_per = paula->p_AudPer;
	custom->aud[1].ac_per = paula->p_AudPer;
	custom->aud[0].ac_vol = paula->p_OutputVolume;
	custom->aud[1].ac_vol = paula->p_OutputVolume;

	paula->p_DoubleBufferOffset ^= 4;
	audptr = &paula->p_AudPtrs[paula->p_DoubleBufferOffset];

	if (paula->p_SwapChannels)
	{
		custom->aud[1].ac_ptr = *audptr++;
		custom->aud[0].ac_ptr = *audptr++;
	}
	else
	{
		custom->aud[0].ac_ptr = *audptr++;
		custom->aud[1].ac_ptr = *audptr++;
	}

	custom->intreq = INTF_AUD0;

	if (!paula->p_MixTask)
		Cause(&paula->p_PlaySoftInt);
	else
		Signal(&paula->p_MixTask->pr_Task, SIGBREAKF_CTRL_D);
}

#ifdef __MORPHOS__
static const struct EmulLibEntry AudioInterrupt2_GATE = { TRAP_LIBNR, 0, (void (*)(void))AudioInterrupt2_Entry };
#define AudioInterrupt2 ((void(*)(void))&AudioInterrupt2_GATE)
#endif

#ifdef __MORPHOS__
void AudioInterrupt4_Entry(void)
{
	volatile struct Custom *custom = (volatile struct Custom *)REG_A0;
	struct Paula *paula = (struct Paula *)REG_A1;
	struct ExecBase *SysBase = (struct ExecBase *)REG_A6;
#else
void AudioInterrupt4(REG(a0, volatile struct Custom *custom), REG(a1, struct Paula *paula), REG(a6, struct ExecBase *SysBase))
{
#endif
	APTR *audptr;

	custom->aud[0].ac_per = paula->p_AudPer;
	custom->aud[1].ac_per = paula->p_AudPer;
	custom->aud[2].ac_per = paula->p_AudPer;
	custom->aud[3].ac_per = paula->p_AudPer;
	custom->aud[0].ac_vol = 64;
	custom->aud[1].ac_vol = 64;
	custom->aud[2].ac_vol = 1;
	custom->aud[3].ac_vol = 1;

	paula->p_DoubleBufferOffset ^= 4;
	audptr = &paula->p_AudPtrs[paula->p_DoubleBufferOffset];

	if (paula->p_SwapChannels)
	{
		custom->aud[1].ac_ptr = *audptr++;
		custom->aud[0].ac_ptr = *audptr++;
		custom->aud[3].ac_ptr = *audptr++;
		custom->aud[2].ac_ptr = *audptr++;
	}
	else
	{
		custom->aud[0].ac_ptr = *audptr++;
		custom->aud[1].ac_ptr = *audptr++;
		custom->aud[2].ac_ptr = *audptr++;
		custom->aud[3].ac_ptr = *audptr++;
	}

	custom->intreq = INTF_AUD0;

	if (!paula->p_MixTask)
		Cause(&paula->p_PlaySoftInt);
	else
		Signal(&paula->p_MixTask->pr_Task, SIGBREAKF_CTRL_D);
}

#ifdef __MORPHOS__
static const struct EmulLibEntry AudioInterrupt4_GATE = { TRAP_LIBNR, 0, (void (*)(void))AudioInterrupt4_Entry };
#define AudioInterrupt4 ((void(*)(void))&AudioInterrupt4_GATE)
#endif

void DMA_HandleInt(struct AHIAudioCtrlDrv *audioctrl, struct Channel *chan, APTR *audptr)
{
	APTR src, dst;
	LONG samples;
	ULONG scale, offset, type;

	DEBUG_DMA(dprintf("DMA_HandleInt\n"));

	if ((chan->ch_Type != AHIST_NOTYPE) && (chan->ch_EndOfSample == 0) && (chan->ch_Count != 0) && ((chan->ch_Length & ~1) <= chan->ch_Count))
	{
		chan->ch_Address = chan->ch_NextAddress;
		chan->ch_Length = chan->ch_NextLength;
		chan->ch_Type = chan->ch_NextType;
		*((ULONG *)chan->ch_PerVol) = *((ULONG *)chan->ch_NextPerVol);
		chan->ch_Scale = chan->ch_NextScale;
		chan->ch_Offset = chan->ch_NextOffset;
		chan->ch_Count = 0;
		chan->ch_EndOfSample = -1;
	}

	if (chan->ch_EndOfSample)
	{
		struct Hook *sndhook;

		chan->ch_EndOfSample = 0;

		if ((sndhook = audioctrl->ahiac_SoundFunc))
		{
			REG_A0 = (ULONG)sndhook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)&chan->ch_SndMsg;
			REG_D0 = (ULONG)chan->ch_SndMsg.ahism_Channel;	/* Is this really needed? */
			(*MyEmulHandle->EmulCallDirect68k)(sndhook->h_Entry);
		}
	}

	/* Swap chipmem buffers */
	dst = audptr[1];
	audptr[1] = audptr[0];
	audptr[0] = dst;

	/* Swap cleared indicators */
	samples = chan->ch_Cleared2;
	chan->ch_Cleared2 = chan->ch_Cleared;
	chan->ch_Cleared = samples;

	src = chan->ch_Address;
	scale = chan->ch_Scale;
	offset = chan->ch_Count;
	samples = chan->ch_Length - offset;
	type = chan->ch_Type;

	if ((samples <= 0) || (chan->ch_Period == 0))
	{
		samples = DMABUFFSAMPLES;
		scale = 0;
	}
	else
	{
		LONG tmp = DMABUFFSAMPLES << scale;

		if (samples > tmp) samples = tmp;

		chan->ch_Count += samples;
		offset = chan->ch_Offset;

		if (type & AHIST_BW)
			chan->ch_Offset -= samples;
		else
			chan->ch_Offset += samples;
	}

	samples >>= scale;
	chan->ch_DMALength = samples >> 1;
	scale = (1 << scale);

	if ((chan->ch_Period == 0) || (type == AHIST_NOTYPE))
	{
		if (samples <= chan->ch_Cleared) return;

		chan->ch_Cleared = samples;
		ClearSample(samples, dst);
	}
	else
	{
		chan->ch_Cleared = 0;

		if (type & AHIST_BW) scale = -scale;

		type &= ~AHIST_BW;

		switch (type)
		{
			case AHIST_M8S:
				CopySampleM8S(samples, offset, scale, dst, src);
				break;

			case AHIST_S8S:
				CopySampleS8S(samples, offset, scale, dst, src, chan);
				break;

			case AHIST_M16S:
				CopySampleM16S(samples, offset, scale, dst, src);
				break;

			case AHIST_S16S:
				CopySampleS16S(samples, offset, scale, dst, src, chan);
				break;

			default:
				/* This should never happen... */
				break;
		}
	}

	DEBUG_DMA(dprintf("DMA_HandleInt: done\n"));
}

#ifdef __MORPHOS__
void AudioInterruptDMA_Entry(void)
{
	UWORD interrupts = (UWORD)REG_D1;
	volatile struct Custom *custom = (volatile struct Custom *)REG_A0;
	struct Paula *paula = (struct Paula *)REG_A1;
	/*struct ExecBase *SysBase = (struct ExecBase *)REG_A6;*/
#else
void AudioInterruptDMA(REG(d1, UWORD interrupts), REG(a0, volatile struct Custom *custom), REG(a1, struct Paula *paula), REG(a6, struct ExecBase *SysBase))
{
#endif
	struct AHIAudioCtrlDrv *audioctrl = paula->p_AudioCtrl;
	struct Channel *chan = paula->p_Channels;
	APTR *audptr = paula->p_AudPtrs;
	int i;

	DEBUG_DMA(dprintf("AudioInterruptDMA: interrupts 0x%04lx custom 0x%06lx\n", interrupts, custom));

	for (i = 0; i < 4; i++)
	{
		if (chan[i].ch_IntMask & interrupts)
		{
			DEBUG_DMA(dprintf("AudioInterruptDMA: pervol 0x%08lx -> 0x%06lx\n", *((ULONG *)chan[i].ch_PerVol), &chan[i].ch_RegBase->ac_per));
			*((ULONG *)&chan[i].ch_RegBase->ac_per) = *((ULONG *)chan[i].ch_PerVol);

			DMA_HandleInt(audioctrl, &chan[i], audptr);

			custom->intreq = chan[i].ch_IntMask;
			DEBUG_DMA(dprintf("AudioInterruptDMA: ptr 0x%06lx -> 0x%06lx\n", *audptr, &chan[i].ch_RegBase->ac_ptr));
			chan[i].ch_RegBase->ac_ptr = *audptr;
			DEBUG_DMA(dprintf("AudioInterruptDMA: len 0x%04lx -> 0x%06lx\n", chan[i].ch_DMALength, &chan[i].ch_RegBase->ac_len));
			chan[i].ch_RegBase->ac_len = chan[i].ch_DMALength;
			chan[i].ch_NoInt = 0;
		}

		audptr += 2;
	}

	custom->dmacon = DMAF_SETCLR | DMAF_AUDIO;

	DEBUG_DMA(dprintf("AudioInterruptDMA: done\n"));
}

#ifdef __MORPHOS__
static const struct EmulLibEntry AudioInterruptDMA_GATE = { TRAP_LIBNR, 0, (void (*)(void))AudioInterruptDMA_Entry };
#define AudioInterruptDMA ((void(*)(void))&AudioInterruptDMA_GATE)
#endif

#define SysBase paulaBase->pb_SysBase

static void DMA_Update(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	DEBUG_DMA(dprintf("DMA_Update\n"));

	if (TimerBase)
	{
		ULONG freq;
		ULONG tics;

		paula->p_EClock = ReadEClock(&paula->p_EAlarm);
		freq = (ULONG)audioctrl->ahiac_PlayerFreq >> 8;
		tics = paula->p_EClock << 8;

		if (freq)
		{
			paula->p_EPeriod = tics / freq;
			DEBUG_DMA(dprintf("DMA_Update: done, paula->p_EPeriod %ld\n", paula->p_EPeriod));
			return;
		}
	}

	DEBUG_DMA(dprintf("DMA_Update: done, paula->p_EPeriod %ld\n", paula->p_EPeriod));
	paula->p_EPeriod = 709379 / 50;    /* Approx 50 Hz */
}

static ULONG DMA_Start(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	UBYTE *buf;

	DEBUG_DMA(dprintf("DMA_Start\n"));

	if (!(paula->p_DMAbuffer = AllocVec(DMABUFFSAMPLES * 8, MEMF_CHIP | MEMF_PUBLIC | MEMF_CLEAR))) return AHIE_NOMEM;

	buf = paula->p_DMAbuffer;
	paula->p_AudPtrs[0] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[4] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[1] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[5] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[2] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[6] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[3] = buf;
	buf += DMABUFFSAMPLES;
	paula->p_AudPtrs[7] = buf;

	paula->p_PlayInt.is_Code = AudioInterruptDMA;
	paula->p_PlayInt.is_Data = paula;

	SetIntVector(INTB_AUD0, &paula->p_PlayInt);
	SetIntVector(INTB_AUD1, &paula->p_PlayInt);
	SetIntVector(INTB_AUD2, &paula->p_PlayInt);
	SetIntVector(INTB_AUD3, &paula->p_PlayInt);

	paula->p_TimerPort.mp_Node.ln_Type = NT_MSGPORT;
	paula->p_TimerPort.mp_Flags = PA_SOFTINT;
	paula->p_TimerPort.mp_SigTask = &paula->p_TimerInt;
	NEWLIST(&paula->p_TimerPort.mp_MsgList);

	paula->p_TimerInt.is_Node.ln_Pri = 32;
	paula->p_TimerInt.is_Code = PlayerFunc;
	paula->p_TimerInt.is_Data = paula;

	if (!(paula->p_TimerReq = CreateIORequest(&paula->p_TimerPort, sizeof(struct timerequest)))) return AHIE_UNKNOWN;
	if ((paula->p_TimerDev = OpenDevice("timer.device", UNIT_ECLOCK, (struct IORequest *)paula->p_TimerReq, 0)) != 0) return AHIE_UNKNOWN;
	TimerBase = (struct Library *)paula->p_TimerReq->tr_node.io_Device;

	DMA_Update(audioctrl, paula, paulaBase);

	*((unsigned long long *)(&paula->p_EAlarm)) += paula->p_EPeriod;

	paula->p_TimerCommFlag = 0;

	paula->p_TimerReq->tr_node.io_Command = TR_ADDREQUEST;
	paula->p_TimerReq->tr_time.tv_secs = 0;
	paula->p_TimerReq->tr_time.tv_micro = paula->p_EPeriod;
	BeginIO(paula->p_TimerReq);

	Disable();
	paula->p_IRQMask |= (INTF_SETCLR | INTF_AUDIO);
	if (paula->p_DisableCount == 0) CUSTOM->intena = INTF_SETCLR | INTF_AUDIO;
	CUSTOM->intreq = INTF_SETCLR | INTF_AUDIO;
	Enable();

	DEBUG_DMA(dprintf("DMA_Start, done return AHIE_OK\n"));
	return AHIE_OK;
}

static void DMA_Stop(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	DEBUG_DMA(dprintf("DMA_Stop\n"));

	paula->p_IRQMask &= INTF_AUDIO;
	CUSTOM->intena = INTF_AUDIO;
	CUSTOM->dmacon = DMAF_AUDIO;
	CUSTOM->intreq = INTF_AUDIO;

	if (paula->p_TimerDev == 0)
	{
		paula->p_TimerCommFlag++;

		while (paula->p_TimerCommFlag) Delay(1);

		paula->p_TimerDev = -1;
		TimerBase = NULL;

		CloseDevice((struct IORequest *)paula->p_TimerReq);
	}

	if (paula->p_TimerReq)
	{
		DeleteIORequest((struct IORequest *)paula->p_TimerReq);
		paula->p_TimerReq = NULL;
	}

	paula->p_PlayInt.is_Code = Interrupt_Dummy;
	SetIntVector(INTB_AUD0, &paula->p_PlayInt);
	SetIntVector(INTB_AUD1, &paula->p_PlayInt);
	SetIntVector(INTB_AUD2, &paula->p_PlayInt);
	SetIntVector(INTB_AUD3, &paula->p_PlayInt);

	if (paula->p_DMAbuffer)
	{
		FreeVec(paula->p_DMAbuffer);
		paula->p_DMAbuffer = NULL;
	}

	DEBUG_DMA(dprintf("DMA_Stop, done\n"));
}

#ifdef __MORPHOS__
void SoftInt_8bitM_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_8bitM(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr = paula->p_AudPtrs[paula->p_DoubleBufferOffset];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr++ = (source[0]<<24 | source[2]<<16 | source[4]<<8 | source[6]);
				source += 8;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_8bitM_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_8bitM_Entry };
#define SoftInt_8bitM ((void(*)(void))&SoftInt_8bitM_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_8bitMH_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_8bitMH(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr = paula->p_AudPtrs[paula->p_DoubleBufferOffset];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr++ = (source[0]<<24 | source[4]<<16 | source[8]<<8 | source[12]);
				source += 16;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_8bitMH_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_8bitMH_Entry };
#define SoftInt_8bitMH ((void(*)(void))&SoftInt_8bitMH_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_8bitS_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_8bitS(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr1;
	ULONG *audptr2;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr2 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+1];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr2++ = (source[0]<<24 | source[4]<<16 | source[8]<<8 | source[12]);
				*audptr1++ = (source[2]<<24 | source[6]<<16 | source[10]<<8 | source[14]);
				source += 16;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_8bitS_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_8bitS_Entry };
#define SoftInt_8bitS ((void(*)(void))&SoftInt_8bitS_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_8bitSH_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_8bitSH(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr1;
	ULONG *audptr2;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr2 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+1];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr2++ = (source[0]<<24 | source[8]<<16 | source[16]<<8 | source[24]);
				*audptr1++ = (source[4]<<24 | source[12]<<16 | source[20]<<8 | source[28]);
				source += 32;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_8bitSH_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_8bitSH_Entry };
#define SoftInt_8bitSH ((void(*)(void))&SoftInt_8bitSH_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14bitM_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14bitM(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr1;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr1++ = (source[0]<<24 | source[2]<<16 | source[4]<<8 | source[6]);
				*audptr4++ = ((source[1]>>2)<<24 | (source[3]>>2)<<16 | (source[5]>>2)<<8 | (source[7]>>2));
				source += 8;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14bitM_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14bitM_Entry };
#define SoftInt_14bitM ((void(*)(void))&SoftInt_14bitM_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14bitMH_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14bitMH(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr1;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr1++ = (source[0]<<24 | source[4]<<16 | source[8]<<8 | source[12]);
				*audptr4++ = ((source[1]>>2)<<24 | (source[5]>>2)<<16 | (source[9]>>2)<<8 | (source[13]>>2));
				source += 16;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14bitMH_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14bitMH_Entry };
#define SoftInt_14bitMH ((void(*)(void))&SoftInt_14bitMH_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14CbitM_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14CbitM(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UWORD *source, *calib;
	ULONG *audptr1;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];
	calib = paula->p_CalibrationTable;

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				UWORD s1, s2, s3, s4;

				s1 = calib[*source++];
				s2 = calib[*source++];
				s3 = calib[*source++];
				s4 = calib[*source++];
				*audptr4++ = ((s1&0x00FF)<<24 | (s2&0x00FF)<<16 | (s3&0x00FF)<<8 | (s4&0x00FF));
				*audptr1++ = ((s1&0xFF00)<<16 | (s2&0xFF00)<<8 | (s3&0xFF00) | (s4&0xFF00)>>8);
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14CbitM_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14CbitM_Entry };
#define SoftInt_14CbitM ((void(*)(void))&SoftInt_14CbitM_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14CbitMH_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14CbitMH(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UWORD *source, *calib;
	ULONG *audptr1;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];
	calib = paula->p_CalibrationTable;

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				UWORD s1, s2, s3, s4;

				s1 = calib[source[0]];
				s2 = calib[source[2]];
				s3 = calib[source[4]];
				s4 = calib[source[6]];
				*audptr4++ = ((s1&0x00FF)<<24 | (s2&0x00FF)<<16 | (s3&0x00FF)<<8 | (s4&0x00FF));
				*audptr1++ = ((s1&0xFF00)<<16 | (s2&0xFF00)<<8 | (s3&0xFF00) | (s4&0xFF00)>>8);

				source += 8;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14CbitMH_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14CbitMH_Entry };
#define SoftInt_14CbitMH ((void(*)(void))&SoftInt_14CbitMH_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14bitS_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14bitS(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr1;
	ULONG *audptr2;
	ULONG *audptr3;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr2 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+1];
	audptr3 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+2];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr2++ = (source[0]<<24 | source[4]<<16 | source[8]<<8 | source[12]);
				*audptr3++ = ((source[1]>>2)<<24 | (source[5]>>2)<<16 | (source[9]>>2)<<8 | (source[13]>>2));
				*audptr1++ = (source[2]<<24 | source[6]<<16 | source[10]<<8 | source[14]);
				*audptr4++ = ((source[3]>>2)<<24 | (source[7]>>2)<<16 | (source[11]>>2)<<8 | (source[15]>>2));
				source += 16;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14bitS_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14bitS_Entry };
#define SoftInt_14bitS ((void(*)(void))&SoftInt_14bitS_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14bitSH_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14bitSH(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UBYTE *source;
	ULONG *audptr1;
	ULONG *audptr2;
	ULONG *audptr3;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr2 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+1];
	audptr3 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+2];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				*audptr2++ = (source[0]<<24 | source[8]<<16 | source[16]<<8 | source[24]);
				*audptr3++ = ((source[1]>>2)<<24 | (source[9]>>2)<<16 | (source[17]>>2)<<8 | (source[25]>>2));
				*audptr1++ = (source[4]<<24 | source[12]<<16 | source[20]<<8 | source[28]);
				*audptr4++ = ((source[5]>>2)<<24 | (source[13]>>2)<<16 | (source[21]>>2)<<8 | (source[29]>>2));
				source += 32;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14bitSH_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14bitSH_Entry };
#define SoftInt_14bitSH ((void(*)(void))&SoftInt_14bitSH_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14CbitS_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14CbitS(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UWORD *source, *calib;
	ULONG *audptr1;
	ULONG *audptr2;
	ULONG *audptr3;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr2 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+1];
	audptr3 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+2];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];
	calib = paula->p_CalibrationTable;

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				UWORD s1, s2, s3, s4;

				s1 = calib[source[0]];
				s2 = calib[source[2]];
				s3 = calib[source[4]];
				s4 = calib[source[6]];
				*audptr3++ = ((s1&0x00FF)<<24 | (s2&0x00FF)<<16 | (s3&0x00FF)<<8 | (s4&0x00FF));
				*audptr2++ = ((s1&0xFF00)<<16 | (s2&0xFF00)<<8 | (s3&0xFF00) | (s4&0xFF00)>>8);

				s1 = calib[source[1]];
				s2 = calib[source[3]];
				s3 = calib[source[5]];
				s4 = calib[source[7]];
				*audptr4++ = ((s1&0x00FF)<<24 | (s2&0x00FF)<<16 | (s3&0x00FF)<<8 | (s4&0x00FF));
				*audptr1++ = ((s1&0xFF00)<<16 | (s2&0xFF00)<<8 | (s3&0xFF00) | (s4&0xFF00)>>8);

				source += 8;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14CbitS_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14CbitS_Entry };
#define SoftInt_14CbitS ((void(*)(void))&SoftInt_14CbitS_GATE)
#endif

#ifdef __MORPHOS__
void SoftInt_14CbitSH_Entry(void)
{
	struct Paula *paula = (struct Paula *)REG_A1;
#else
void SoftInt_14CbitSH(REG(a1, struct Paula *paula), REG(a6, struct ExecBase *BackupSysBase))
{
#endif
	REG(a2, struct AHIAudioCtrlDrv *audioctrl) = paula->p_AudioCtrl;
	ULONG loops, samples = 0;
	UWORD *source, *calib;
	ULONG *audptr1;
	ULONG *audptr2;
	ULONG *audptr3;
	ULONG *audptr4;
	BOOL noconvert;

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	noconvert = (*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PreTimer);
#else
	noconvert = audioctrl->ahiac_PreTimer();
#endif

	audptr1 = paula->p_AudPtrs[paula->p_DoubleBufferOffset];
	audptr2 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+1];
	audptr3 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+2];
	audptr4 = paula->p_AudPtrs[paula->p_DoubleBufferOffset+3];
	calib = paula->p_CalibrationTable;

	REG_A0 = (ULONG)paula->p_PlayerHook;
	REG_A2 = (ULONG)audioctrl;
	REG_A1 = (ULONG)paula->p_Reserved;
	(*MyEmulHandle->EmulCallDirect68k)(paula->p_PlayerEntry);

	do
	{
		if (!noconvert)
		{
			ULONG left;

			REG_A0 = (ULONG)paula->p_MixHook;
			REG_A2 = (ULONG)audioctrl;
			REG_A1 = (ULONG)paula->p_Mixbuffer;
#ifdef BETTERTIMING
			REG_A1 += paula->p_LoopLeftovers << paula->p_SampleFrameShift;
#endif
			(*MyEmulHandle->EmulCallDirect68k)(paula->p_MixEntry);

#ifdef BETTERTIMING
			left = loops = audioctrl->ahiac_BuffSamples + paula->p_LoopLeftovers;
			left -= (loops &= ~3);
			paula->p_LoopLeftovers = left;
			samples += loops;
			loops >>= 2;
#else
			loops = paula->p_LoopTimes;
#endif
			source = paula->p_Mixbuffer;

			while (loops--)
			{
				UWORD s1, s2, s3, s4;

				s1 = calib[source[0]];
				s2 = calib[source[4]];
				s3 = calib[source[8]];
				s4 = calib[source[12]];
				*audptr3++ = ((s1&0x00FF)<<24 | (s2&0x00FF)<<16 | (s3&0x00FF)<<8 | (s4&0x00FF));
				*audptr2++ = ((s1&0xFF00)<<16 | (s2&0xFF00)<<8 | (s3&0xFF00) | (s4&0xFF00)>>8);

				s1 = calib[source[2]];
				s2 = calib[source[6]];
				s3 = calib[source[10]];
				s4 = calib[source[14]];
				*audptr4++ = ((s1&0x00FF)<<24 | (s2&0x00FF)<<16 | (s3&0x00FF)<<8 | (s4&0x00FF));
				*audptr1++ = ((s1&0xFF00)<<16 | (s2&0xFF00)<<8 | (s3&0xFF00) | (s4&0xFF00)>>8);

				source += 16;
			}

#ifdef BETTERTIMING
			loops = ((paula->p_LoopLeftovers << paula->p_SampleFrameShift) + 3) >> 2;

			if (loops)
			{
				ULONG *dst = paula->p_Mixbuffer;
				ULONG *src = (ULONG *)source;

				while (loops--)
				{
					*dst++ = *src++;
				}
			}
#endif
		}
		else
			samples += audioctrl->ahiac_BuffSamples;

#ifndef BETTERTIMING
		samples += audioctrl->ahiac_BuffSamples;
#endif
	} while (samples < paula->p_MinBufferLength);

#ifdef __MORPHOS__
	REG_A2 = (ULONG)audioctrl;
	(*MyEmulHandle->EmulCallDirect68k)(audioctrl->ahiac_PostTimer);
#else
	audioctrl->ahiac_PostTimer();
#endif

	samples >>= 1;
	CUSTOM->aud[0].ac_len = samples;
	CUSTOM->aud[1].ac_len = samples;
	CUSTOM->aud[2].ac_len = samples;
	CUSTOM->aud[3].ac_len = samples;
	CUSTOM->dmacon = DMAF_SETCLR | DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;

#ifndef __MORPHOS__
	#error The registers a0 and a6 must be restored to Custom and SysBase respectively!
#endif
}

#ifdef __MORPHOS__
static const struct EmulLibEntry SoftInt_14CbitSH_GATE = { TRAP_LIBNR, 0, (void (*)(void))SoftInt_14CbitSH_Entry };
#define SoftInt_14CbitSH ((void(*)(void))&SoftInt_14CbitSH_GATE)
#endif

static ULONG init8bitM(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	ULONG size;
	UBYTE *buf;

	paula->p_PlayInt.is_Code = AudioInterrupt2;

	if (paula->p_Flags & PF_HIFI)
	{
		paula->p_PlaySoftInt.is_Code = SoftInt_8bitMH;

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 2;
#endif
	}
	else
	{
		paula->p_PlaySoftInt.is_Code = SoftInt_8bitM;

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 1;
#endif
	}

	size = (paula->p_MinBufferLength + audioctrl->ahiac_MaxBuffSamples + EXTRASAMPLES + 3) & ~3;

	if (!(paula->p_DMAbuffer = AllocVec(size << 1, MEMF_CHIP | MEMF_PUBLIC | MEMF_CLEAR))) return AHIE_NOMEM;

	buf = paula->p_DMAbuffer;
	paula->p_AudPtrs[0] = paula->p_AudPtrs[1] = buf;
	paula->p_AudPtrs[4] = paula->p_AudPtrs[5] = buf + size;

	return 0;
}

static ULONG init8bitS(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	ULONG size;
	UBYTE *buf;

	paula->p_PlayInt.is_Code = AudioInterrupt2;

	if (paula->p_Flags & PF_HIFI)
	{
		paula->p_PlaySoftInt.is_Code = SoftInt_8bitSH;

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 3;
#endif
	}
	else
	{
		paula->p_PlaySoftInt.is_Code = SoftInt_8bitS;

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 2;
#endif
	}

	size = (paula->p_MinBufferLength + audioctrl->ahiac_MaxBuffSamples + EXTRASAMPLES + 3) & ~3;

	if (!(paula->p_DMAbuffer = AllocVec(size << 2, MEMF_CHIP | MEMF_PUBLIC | MEMF_CLEAR))) return AHIE_NOMEM;

	buf = paula->p_DMAbuffer;
	paula->p_AudPtrs[0] = buf;
	buf += size;
	paula->p_AudPtrs[1] = buf;
	buf += size;
	paula->p_AudPtrs[4] = buf;
	buf += size;
	paula->p_AudPtrs[5] = buf;

	return 0;
}

static ULONG init14bitM(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	ULONG size;
	UBYTE *buf;

	paula->p_PlayInt.is_Code = AudioInterrupt4;

	if (paula->p_Flags & PF_HIFI)
	{
		paula->p_PlaySoftInt.is_Code = ((paula->p_CalibrationTable) ? SoftInt_14CbitMH : SoftInt_14bitMH);

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 2;
#endif
	}
	else
	{
		paula->p_PlaySoftInt.is_Code = ((paula->p_CalibrationTable) ? SoftInt_14CbitM : SoftInt_14bitM);

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 1;
#endif
	}

	size = (paula->p_MinBufferLength + audioctrl->ahiac_MaxBuffSamples + EXTRASAMPLES + 3) & ~3;

	if (!(paula->p_DMAbuffer = AllocVec(size << 2, MEMF_CHIP | MEMF_PUBLIC | MEMF_CLEAR))) return AHIE_NOMEM;

	buf = paula->p_DMAbuffer;
	paula->p_AudPtrs[0] = paula->p_AudPtrs[1] = buf;
	buf += size;
	paula->p_AudPtrs[2] = paula->p_AudPtrs[3] = buf;
	buf += size;
	paula->p_AudPtrs[4] = paula->p_AudPtrs[5] = buf;
	buf += size;
	paula->p_AudPtrs[6] = paula->p_AudPtrs[7] = buf;

	return 0;
}

static ULONG init14bitS(struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	ULONG size;
	UBYTE *buf;

	paula->p_PlayInt.is_Code = AudioInterrupt4;

	if (paula->p_Flags & PF_HIFI)
	{
		paula->p_PlaySoftInt.is_Code = ((paula->p_CalibrationTable) ? SoftInt_14CbitSH : SoftInt_14bitSH);

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 3;
#endif
	}
	else
	{
		paula->p_PlaySoftInt.is_Code = ((paula->p_CalibrationTable) ? SoftInt_14CbitS : SoftInt_14bitS);

#ifdef BETTERTIMING
		paula->p_SampleFrameShift = 2;
#endif
	}

	size = (paula->p_MinBufferLength + audioctrl->ahiac_MaxBuffSamples + EXTRASAMPLES + 3) & ~3;

	if (!(paula->p_DMAbuffer = AllocVec(size << 3, MEMF_CHIP | MEMF_PUBLIC | MEMF_CLEAR))) return AHIE_NOMEM;

	buf = paula->p_DMAbuffer;
	paula->p_AudPtrs[0] = buf;
	buf += size;
	paula->p_AudPtrs[1] = buf;
	buf += size;
	paula->p_AudPtrs[2] = buf;
	buf += size;
	paula->p_AudPtrs[3] = buf;
	buf += size;
	paula->p_AudPtrs[4] = buf;
	buf += size;
	paula->p_AudPtrs[5] = buf;
	buf += size;
	paula->p_AudPtrs[6] = buf;
	buf += size;
	paula->p_AudPtrs[7] = buf;

	return 0;
}


static const UBYTE audiochannelarray[] = { 1+2+4+8 };

#ifdef __MORPHOS__
ULONG AHIsub_AllocAudio(void)
{
	struct TagItem *tags = (struct TagItem *)REG_A1;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_AllocAudio(REG(a1, struct TagItem *tags), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula;
	UBYTE flags;
	int i;

	if (!(paula = audioctrl->ahiac_DriverData = AllocVec(sizeof(struct Paula), MEMF_PUBLIC | MEMF_CLEAR))) return AHISF_ERROR;

	paula->p_TimerDev = -1;
	paula->p_audiodev = -1;

	paula->p_ParBitsUser = (APTR)-1;
	paula->p_ParPortUser = (APTR)-1;
	paula->p_SerBitsUser = (APTR)-1;

	paula->p_PaulaBase = paulaBase;
	paula->p_AudioCtrl = audioctrl;

	paula->p_RecSoftIntPtr = &paula->p_RecSoftInt;

	paula->p_rmType = AHIST_S16S;
	paula->p_rmLength = RECORDSAMPLES;

	paula->p_OutputVolume = 64;
	paula->p_MasterVolume = 65536;

	flags = audioctrl->ahiac_Flags & PF_STEREO;
	if (GetTagData(AHIDB_Paula14Bit, FALSE, tags)) flags |= PF_14BIT;
	if (GetTagData(AHIDB_HiFi, FALSE, tags)) flags |= PF_HIFI;
	if (GetTagData(AHIDB_PaulaDMA, FALSE, tags)) flags |= PF_DMA;
	paula->p_Flags = flags;

	paula->p_ScreenIsDouble = checkvideo(paulaBase);

	if (GetTagData(AHIDB_PaulaTable, FALSE, tags))
	{
		BPTR fh;

		if ((fh = Open("ENV:CyberSound/SoundDrivers/14Bit_Calibration", MODE_OLDFILE)))
		{
			if (Read(fh, paula->p_CalibrationArray, sizeof(paula->p_CalibrationArray)) == sizeof(paula->p_CalibrationArray))
			{
				Close(fh);
			}
			else
			{
				Close(fh);
				fh = NULL;
			}
		}

		if (fh == NULL)
		{
			/* Fill in defaults */
			for (i = 0; i < 255; i++) paula->p_CalibrationArray[i] = 0x55;
			paula->p_CalibrationArray[255] = 0x7F;
		}

		if ((paula->p_CalibrationTable = AllocVec(65536 * 2, MEMF_PUBLIC))) CreateTable(paula->p_CalibrationTable, paula->p_CalibrationArray);
	}

	paula->p_MinBufferLength = GetVarInt("AHIpaulaBufferLength", 0, paulaBase);
	paula->p_SwapChannels = GetVarInt("AHIpaulaSwapChannels", 0, paulaBase);
	paula->p_MixTaskPri = GetVarInt("AHIpaulaMixTaskPri", 128, paulaBase);

#if USE_HWPOKEMODE

	/* First, figure out if there is a audio.device to use, or if there is
	 * an AHI audio.device emulation instead. - Piru
	 */
	{
		struct Device *auddev;

		Forbid();
		auddev = (struct Device *) FindName(&SysBase->DeviceList, AUDIONAME);
		i = auddev && auddev->dd_Library.lib_Version < 50;
		Permit();

		if (!i)
		{
			struct Resident *audres;

			audres = FindResident(AUDIONAME);
			i = audres && audres->rt_Version < 50;
		}
	}

	if (i)
	{
#endif /* USE_HWPOKEMODE */

		if (!(paula->p_audioport = CreateMsgPort())) return AHISF_ERROR;
		if (!(paula->p_audioreq = AllocVec(sizeof(struct IOAudio), MEMF_PUBLIC | MEMF_CLEAR))) return AHISF_ERROR;

		paula->p_audioreq->ioa_Request.io_Message.mn_ReplyPort = paula->p_audioport;
		paula->p_audioreq->ioa_AllocKey = 0;
		paula->p_audioreq->ioa_Request.io_Message.mn_Node.ln_Pri = 127;	/* steal it! */
		paula->p_audioreq->ioa_Data = (UBYTE *) audiochannelarray;
		paula->p_audioreq->ioa_Length = sizeof(audiochannelarray);

		if ((paula->p_audiodev = OpenDevice(AUDIONAME, 0, (struct IORequest *)paula->p_audioreq, 0)) != 0) return AHISF_ERROR;

		paula->p_audioreq->ioa_Request.io_Command = CMD_RESET;
		BeginIO(&paula->p_audioreq->ioa_Request);
		WaitPort(paula->p_audioport);
		GetMsg(paula->p_audioport);
		Delay(1);

		paula->p_PlayInt.is_Code = Interrupt_Dummy;
		SetIntVector(INTB_AUD0, &paula->p_PlayInt);
		SetIntVector(INTB_AUD1, &paula->p_PlayInt);
		SetIntVector(INTB_AUD2, &paula->p_PlayInt);
		SetIntVector(INTB_AUD3, &paula->p_PlayInt);

#if USE_HWPOKEMODE
	}
	else
	{
		/* Ok, we have no audio.device, or the audio.device is using AHI.
		 * So we have to poke hw directly here... - Piru
		 *
		 * Use some channel arbitration though.
		 */

		Forbid();
		paula->p_paulasema = FindSemaphore(PAULACHANNELSSEMA);
		if (!paula->p_paulasema)
		{
			struct paulasemaphore *paulasema;

			paulasema = AllocMem(sizeof(struct paulasemaphore), MEMF_PUBLIC);
			if (!paulasema) return AHISF_ERROR;

			strcpy(paulasema->ps_name, PAULACHANNELSSEMA);
			paulasema->ps_sema.ss_Link.ln_Type = NT_SIGNALSEM;
			paulasema->ps_sema.ss_Link.ln_Pri  = 0;
			paulasema->ps_sema.ss_Link.ln_Name = paulasema->ps_name;
			AddSemaphore(&paulasema->ps_sema);

			paula->p_paulasema = &paulasema->ps_sema;
		}
		Permit();

		/* Try to obtain the semaphore, if it fails channels are already in use */
		if (!AttemptSemaphore(paula->p_paulasema)) return AHISF_ERROR;

		/* Turn off any pending audio DMA & ints */
		CUSTOM->intena = INTF_AUDIO;
		CUSTOM->dmacon = DMAF_AUDIO;
		CUSTOM->intreq = INTF_AUDIO;

		/* Turn off possible audio modulation */
		CUSTOM->adkcon = 0x00ff;

		paula->p_PlayInt.is_Code = Interrupt_Dummy;
		paula->p_oldaudint[0] = SetIntVector(INTB_AUD0, &paula->p_PlayInt);
		paula->p_oldaudint[1] = SetIntVector(INTB_AUD1, &paula->p_PlayInt);
		paula->p_oldaudint[2] = SetIntVector(INTB_AUD2, &paula->p_PlayInt);
		paula->p_oldaudint[3] = SetIntVector(INTB_AUD3, &paula->p_PlayInt);
	}
#endif /* USE_HWPOKEMODE */

	if (!(paula->p_Flags & (PF_14BIT | PF_DMA)))
	{
		paula->p_Parallel = 0;
		paula->p_ParBitsUser = AllocMiscResource(MR_PARALLELBITS, LIB_NAME);
		paula->p_ParPortUser = AllocMiscResource(MR_PARALLELPORT, LIB_NAME);

		if ((paula->p_ParBitsUser == 0) && (paula->p_ParPortUser == 0))
		{
			paula->p_Parallel = TRUE;
			CIAA->ciaddrb = 0;	/* make PB0-PB7 inputs */
		}

		paula->p_AuraAddress = 0;

		if (CardResource)
		{
			struct CardMemoryMap *cardmap;

			if ((cardmap = GetCardMap()))
			{
				if ((cardmap->cmm_IOMemory) && (paula->p_CardHandle = AllocVec(sizeof(struct CardHandle), MEMF_PUBLIC | MEMF_CLEAR)))
				{
					paula->p_CardHandle->cah_CardNode.ln_Name = LIB_NAME;
					paula->p_CardHandle->cah_CardFlags = CARDF_RESETREMOVE | CARDF_IFAVAILABLE;

					if (OwnCard(paula->p_CardHandle) == 0)
					{
						BeginCardAccess(paula->p_CardHandle);
						paula->p_AuraAddress = cardmap->cmm_IOMemory;
					}
				}
			}
		}
	}

	paula->p_PlayInt.is_Node.ln_Type = NT_INTERRUPT;
	paula->p_PlayInt.is_Node.ln_Name = LIB_NAME;
	paula->p_PlayInt.is_Code = Interrupt_Dummy;
	paula->p_PlayInt.is_Data = paula;

	paula->p_PlaySoftInt.is_Node.ln_Type = NT_INTERRUPT;
	paula->p_PlaySoftInt.is_Node.ln_Name = LIB_NAME;
	paula->p_PlaySoftInt.is_Code = SoftInt_Dummy;
	paula->p_PlaySoftInt.is_Data = paula;

	paula->p_RecInt.is_Node.ln_Type = NT_INTERRUPT;
	paula->p_RecInt.is_Node.ln_Name = LIB_NAME;
	paula->p_RecInt.is_Code = Interrupt_Dummy;
	paula->p_RecInt.is_Data = 0;

	paula->p_RecSoftInt.is_Node.ln_Pri = 32;
	paula->p_RecSoftInt.is_Node.ln_Type = NT_INTERRUPT;
	paula->p_RecSoftInt.is_Node.ln_Name = LIB_NAME;
	paula->p_RecSoftInt.is_Code = RecordSoftInt;
	paula->p_RecSoftInt.is_Data = paula;

	CUSTOM->intena = INTF_AUDIO;
	paula->p_IRQMask = INTF_SETCLR;

	if (GetVarInt("AHIpaulaFakeMixFreq", 0, paulaBase) == 0) calcperiod(&audioctrl->ahiac_MixFreq, paulaBase);

	paula->p_Filter = ((CIAA->ciapra & 2) ? (0) : (-1));	/* Save the filter state */

	if (GetVarInt("AHIpaulaFilterFreq", 0, paulaBase) > audioctrl->ahiac_MixFreq)
		CIAA->ciapra &= ~2;	/* turn audio filter on */
	else
		CIAA->ciapra |= 2;	/* turn audio filter off */

	if (!(paula->p_Flags & PF_DMA)) return AHISF_KNOWSTEREO | AHISF_KNOWHIFI | AHISF_CANRECORD | AHISF_MIXING | AHISF_TIMING;

	if (audioctrl->ahiac_Channels > 4) return AHISF_ERROR;

	audioctrl->ahiac_MixFreq = paulaBase->pb_AudioFreq;

	paula->p_Channels[0].ch_Type = AHIST_NOTYPE;
	paula->p_Channels[1].ch_Type = AHIST_NOTYPE;
	paula->p_Channels[2].ch_Type = AHIST_NOTYPE;
	paula->p_Channels[3].ch_Type = AHIST_NOTYPE;
	paula->p_Channels[0].ch_NextType = AHIST_NOTYPE;
	paula->p_Channels[1].ch_NextType = AHIST_NOTYPE;
	paula->p_Channels[2].ch_NextType = AHIST_NOTYPE;
	paula->p_Channels[3].ch_NextType = AHIST_NOTYPE;
	paula->p_Channels[0].ch_SndMsg.ahism_Channel = 0;
	paula->p_Channels[1].ch_SndMsg.ahism_Channel = 1;
	paula->p_Channels[2].ch_SndMsg.ahism_Channel = 2;
	paula->p_Channels[3].ch_SndMsg.ahism_Channel = 3;

	if (!(paula->p_Sounds = AllocVec(sizeof(struct Sound), MEMF_PUBLIC | MEMF_CLEAR))) return AHISF_ERROR;

	for (i=0; i<audioctrl->ahiac_Sounds; i++) paula->p_Sounds[i].so_Type = AHIST_NOTYPE;

	if (paula->p_SwapChannels)
	{
		paula->p_Channels[0].ch_RegBase = &CUSTOM->aud[0];
		paula->p_Channels[1].ch_RegBase = &CUSTOM->aud[1];
		paula->p_Channels[2].ch_RegBase = &CUSTOM->aud[2];
		paula->p_Channels[3].ch_RegBase = &CUSTOM->aud[3];

		paula->p_Channels[0].ch_DMAMask = DMAF_AUD0;
		paula->p_Channels[1].ch_DMAMask = DMAF_AUD1;
		paula->p_Channels[2].ch_DMAMask = DMAF_AUD2;
		paula->p_Channels[3].ch_DMAMask = DMAF_AUD3;

		paula->p_Channels[0].ch_IntMask = INTF_AUD0;
		paula->p_Channels[1].ch_IntMask = INTF_AUD1;
		paula->p_Channels[2].ch_IntMask = INTF_AUD2;
		paula->p_Channels[3].ch_IntMask = INTF_AUD3;

		paula->p_Channels[0].ch_Stereo = 1;
		paula->p_Channels[1].ch_Stereo = 0;
		paula->p_Channels[2].ch_Stereo = 0;
		paula->p_Channels[3].ch_Stereo = 1;
	}
	else
	{
		paula->p_Channels[0].ch_RegBase = &CUSTOM->aud[1];
		paula->p_Channels[1].ch_RegBase = &CUSTOM->aud[0];
		paula->p_Channels[2].ch_RegBase = &CUSTOM->aud[2];
		paula->p_Channels[3].ch_RegBase = &CUSTOM->aud[3];

		paula->p_Channels[0].ch_DMAMask = DMAF_AUD1;
		paula->p_Channels[1].ch_DMAMask = DMAF_AUD0;
		paula->p_Channels[2].ch_DMAMask = DMAF_AUD2;
		paula->p_Channels[3].ch_DMAMask = DMAF_AUD3;

		paula->p_Channels[0].ch_IntMask = INTF_AUD1;
		paula->p_Channels[1].ch_IntMask = INTF_AUD0;
		paula->p_Channels[2].ch_IntMask = INTF_AUD2;
		paula->p_Channels[3].ch_IntMask = INTF_AUD3;

		paula->p_Channels[0].ch_Stereo = 0;
		paula->p_Channels[1].ch_Stereo = 1;
		paula->p_Channels[2].ch_Stereo = 1;
		paula->p_Channels[3].ch_Stereo = 0;
	}

	return 0;
}

#ifdef __MORPHOS__
void AHIsub_FreeAudio(void)
{
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
void AHIsub_FreeAudio(REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;

	if (paula)
	{
		if (paula->p_Sounds) FreeVec(paula->p_Sounds);
		if (paula->p_CalibrationTable) FreeVec(paula->p_CalibrationTable);

		if (paula->p_Filter)
			CIAA->ciapra &= ~2;	/* turn audio filter on */
		else
			CIAA->ciapra |= 2;	/* turn audio filter off */

		if (paula->p_audiodev == 0)
		{
			paula->p_audioreq->ioa_Request.io_Command = CMD_RESET;
			BeginIO(&paula->p_audioreq->ioa_Request);
			WaitPort(paula->p_audioport);
			GetMsg(paula->p_audioport);
			CloseDevice(&paula->p_audioreq->ioa_Request);
			paula->p_audiodev = -1;
		}

		if (paula->p_audioreq) FreeVec(paula->p_audioreq);
		if (paula->p_audioport) DeleteMsgPort(paula->p_audioport);

#if USE_HWPOKEMODE

		if (paula->p_paulasema)
		{
			/* Turn off any pending audio DMA & ints */
			CUSTOM->intena = INTF_AUDIO;
			CUSTOM->dmacon = DMAF_AUDIO;
			CUSTOM->intreq = INTF_AUDIO;

			/* Turn off possible audio modulation */
			CUSTOM->adkcon = 0x00ff;

			/* Restore old intvectors */
			SetIntVector(INTB_AUD0, paula->p_oldaudint[0]);
			SetIntVector(INTB_AUD1, paula->p_oldaudint[1]);
			SetIntVector(INTB_AUD2, paula->p_oldaudint[2]);
			SetIntVector(INTB_AUD3, paula->p_oldaudint[3]);

			ReleaseSemaphore(paula->p_paulasema);
			paula->p_paulasema = NULL;
		}

#endif /* USE_HWPOKEMODE */

		if (paula->p_AuraAddress && CardResource && paula->p_CardHandle)
		{
			EndCardAccess(paula->p_CardHandle);
			ReleaseCard(paula->p_CardHandle, CARDF_REMOVEHANDLE);
		}

		if (paula->p_CardHandle) FreeVec(paula->p_CardHandle);

		if (paula->p_ParPortUser == 0) FreeMiscResource(MR_PARALLELPORT);
		if (paula->p_ParBitsUser == 0) FreeMiscResource(MR_PARALLELBITS);
		if (paula->p_SerBitsUser == 0) FreeMiscResource(MR_SERIALBITS);

		audioctrl->ahiac_DriverData = NULL;
		FreeVec(paula);
	}
}

#ifdef __MORPHOS__
void AHIsub_Disable(void)
{
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
void AHIsub_Disable(REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;

	Paula_Disable(paula, paulaBase);
}

#ifdef __MORPHOS__
void AHIsub_Enable(void)
{
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
void AHIsub_Enable(REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;

	Paula_Enable(paula, paulaBase);
}

static void Paula_Stop(ULONG flags, struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	if (flags & AHISF_PLAY)
	{
		if (paula->p_Flags & PF_DMA)
		{
			DMA_Stop(audioctrl, paula, paulaBase);
		}
		else
		{
			CUSTOM->dmacon = DMAF_AUDIO;

			paula->p_IRQMask &= ~INTF_AUD0;
			CUSTOM->intena = INTF_AUD0;
			CUSTOM->intreq = INTF_AUD0;

			paula->p_PlayInt.is_Code = Interrupt_Dummy;
			SetIntVector(INTB_AUD0, &paula->p_PlayInt);

			CUSTOM->aud[0].ac_vol = 0;
			CUSTOM->aud[1].ac_vol = 0;
			CUSTOM->aud[2].ac_vol = 0;
			CUSTOM->aud[3].ac_vol = 0;

			if (paula->p_MixTask)
			{
				paula->p_ReplyTask = FindTask(NULL);
				SetSignal(0, SIGF_SINGLE);
				Signal(&paula->p_MixTask->pr_Task, SIGBREAKF_CTRL_C);
				Wait(SIGF_SINGLE);
			}

			if (paula->p_DMAbuffer)
			{
				FreeVec(paula->p_DMAbuffer);
				paula->p_DMAbuffer = NULL;
			}

			if (paula->p_Mixbuffer)
			{
				FreeVec(paula->p_Mixbuffer);
				paula->p_Mixbuffer = NULL;
			}
		}
	}

	if ((flags & AHISF_RECORD) && !(paula->p_Flags & PF_14BIT))
	{
		paula->p_IRQMask &= ~INTF_AUD3;
		CUSTOM->intena = INTF_AUD3;
		CUSTOM->intreq = INTF_AUD3;

		paula->p_RecInt.is_Code = Interrupt_Dummy;
		SetIntVector(INTB_AUD3, &paula->p_RecInt);

		CUSTOM->aud[2].ac_vol = 0;
		CUSTOM->aud[3].ac_vol = 0;

		if (paula->p_RecBuffer1)
		{
			FreeVec(paula->p_RecBuffer1);
			paula->p_RecBuffer1 = NULL;
		}

		if (paula->p_RecBuffer2)
		{
			FreeVec(paula->p_RecBuffer2);
			paula->p_RecBuffer2 = NULL;
		}
	}
}

static void Paula_Update(ULONG flags, struct AHIAudioCtrlDrv *audioctrl, struct Paula *paula, struct paulaBase *paulaBase)
{
	Paula_Disable(paula, paulaBase);

	paula->p_PlayerHook = audioctrl->ahiac_PlayerFunc;
	paula->p_PlayerEntry = audioctrl->ahiac_PlayerFunc->h_Entry;

	if (paula->p_Flags & PF_DMA)
	{
		DMA_Update(audioctrl, paula, paulaBase);
	}
	else
	{

#ifndef BETTERTIMING
		audioctrl->ahiac_BuffSamples &= ~3;
		paula->p_LoopTimes = (audioctrl->ahiac_BuffSamples >> 2);
#endif

		paula->p_MixHook = audioctrl->ahiac_MixerFunc;
		paula->p_MixEntry = audioctrl->ahiac_MixerFunc->h_Entry;
	}

	Paula_Enable(paula, paulaBase);
}

#ifdef __MORPHOS__
ULONG AHIsub_Start(void)
{
	ULONG flags = (ULONG)REG_D0;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_Start(REG(d0, ULONG flags), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	ULONG temp;

	if (flags & AHISF_PLAY)
	{
		Paula_Stop(AHISF_PLAY, audioctrl, paula, paulaBase);
		Paula_Update(AHISF_PLAY, audioctrl, paula, paulaBase);

		if (paula->p_Flags & PF_DMA) return DMA_Start(audioctrl, paula, paulaBase);

		if (!(paula->p_Mixbuffer = AllocVec(audioctrl->ahiac_BuffSize + EXTRABUFFSIZE, MEMF_PUBLIC | MEMF_CLEAR))) return AHIE_NOMEM;

		temp = audioctrl->ahiac_MixFreq;
		paula->p_AudPer = calcperiod(&temp, paulaBase);

		switch ((paula->p_Flags & (PF_STEREO | PF_14BIT)))
		{
			case 0:
				temp = init8bitM(audioctrl, paula, paulaBase);
				break;

			case PF_STEREO:
				temp = init8bitS(audioctrl, paula, paulaBase);
				break;

			case PF_14BIT:
				temp = init14bitM(audioctrl, paula, paulaBase);
				break;

			default:
				temp = init14bitS(audioctrl, paula, paulaBase);
				break;
		}

		if (temp != 0) return temp;

		if (paula->p_MixTaskPri != 128)
		{

#ifdef __MORPHOS__
			paula->p_MixTask = CreateNewProcTags(NP_Priority, paula->p_MixTaskPri,
			                                     NP_Name,     (ULONG)((APTR)LIB_NAME),
			                                     NP_Entry,    (ULONG)((APTR)MixTask),
			                                     NP_CodeType, CODETYPE_PPC,
			                                     NP_UserData, (ULONG) paula,
			                                     TAG_DONE);
#else
			Forbid();

			if ((paula->p_MixTask = CreateNewProcTags(NP_Priority, paula->p_MixTaskPri,
			                                          NP_Name,     (ULONG)((APTR)LIB_NAME),
			                                          NP_Entry,    (ULONG)((APTR)MixTask),
			                                          TAG_DONE)))
			{
				paula->p_MixTask->pr_Task.tc_UserData = paula;
			}

			Permit();
#endif
		}

		SetIntVector(INTB_AUD0, &paula->p_PlayInt);
		paula->p_IRQMask |= (INTF_SETCLR | INTF_AUD0);

		Disable();
		if (paula->p_DisableCount == 0) CUSTOM->intena = INTF_SETCLR | INTF_AUD0;
		CUSTOM->intreq = INTF_SETCLR | INTF_AUD0;
		Enable();
	}

	if (flags & AHISF_RECORD)
	{
		UWORD pervol;

		if ((paula->p_Flags & (PF_14BIT | PF_DMA))) return AHIE_UNKNOWN;

		Paula_Stop(AHISF_RECORD, audioctrl, paula, paulaBase);

		if (!(paula->p_RecFillPtr = paula->p_RecBuffer1 = AllocVec(RECORDSAMPLES * 4, MEMF_PUBLIC))) return AHIE_NOMEM;
		paula->p_RecFillCount = RECORDSAMPLES;
		if (!(paula->p_RecBuffer2 = AllocVec(RECORDSAMPLES * 4, MEMF_PUBLIC))) return AHIE_NOMEM;

		temp = audioctrl->ahiac_MixFreq;
		pervol = calcperiod(&temp, paulaBase);

		CUSTOM->aud[2].ac_per = pervol;
		CUSTOM->aud[3].ac_per = pervol;
		pervol = paula->p_MonitorVolume;
		CUSTOM->aud[2].ac_vol = pervol;
		CUSTOM->aud[3].ac_vol = pervol;

		switch (paula->p_Input)
		{
			case 0:	/* Parallel sampler */
				if (!paula->p_Parallel) return AHIE_UNKNOWN;

				paula->p_RecInt.is_Data = &paula->p_RecIntData;
				paula->p_RecInt.is_Code = RecordInterrupt;

				CIAB->ciaddrb = 0xFF;	/* Set parallel port to output */
				break;

			case 1:	/* Aura sampler */
				if (!paula->p_AuraAddress) return AHIE_UNKNOWN;

				paula->p_RecInt.is_Data = &paula->p_RecIntDataAura;
				paula->p_RecInt.is_Code = RecordInterruptAura;
				break;

			case 2:	/* Clarity sampler */
				if (!paula->p_Parallel) return AHIE_UNKNOWN;

				if ((paula->p_SerBitsUser = AllocMiscResource(MR_SERIALBITS, LIB_NAME)) != 0) return AHIE_UNKNOWN;

				paula->p_RecInt.is_Data = &paula->p_RecIntData;
				paula->p_RecInt.is_Code = RecordInterruptClarity;

				CIAB->ciaddra |= (CIAF_COMDTR | CIAF_PRTRBUSY | CIAF_PRTRPOUT);	/* Set DTR, PRTBUSY and PRTRPOUT to outputs */
				CIAB->ciaddrb = 0xFF;	/* Set parallel port to output */

				/* Reset Clarity */
				CIAB->ciapra = (CIAF_PRTRBUSY | CIAF_PRTRPOUT);
				CIAB->ciapra = CIAF_PRTRPOUT;
				CIAB->ciapra = (CIAF_PRTRBUSY | CIAF_PRTRPOUT);
				/* Clarity is now in stereo record mode */
				break;

			default:
				return AHIE_UNKNOWN;
				break;
		}

		SetIntVector(INTB_AUD3, &paula->p_RecInt);

		CUSTOM->dmacon = DMAF_AUD2 | DMAF_AUD3;	/* Disable DMA */
		paula->p_IRQMask |= (INTF_SETCLR | INTF_AUD3);
		CUSTOM->intena = INTF_SETCLR | INTF_AUD3;	/* Enable */
		CUSTOM->intreq = INTF_SETCLR | INTF_AUD3;	/* Start */
	}

	return AHIE_OK;
}

#ifdef __MORPHOS__
ULONG AHIsub_Update(void)
{
	ULONG flags = (ULONG)REG_D0;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_Update(REG(d0, ULONG flags), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;

	Paula_Update(flags, audioctrl, paula, paulaBase);

	return 0;
}

#ifdef __MORPHOS__
ULONG AHIsub_Stop(void)
{
	ULONG flags = (ULONG)REG_D0;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_Stop(REG(d0, ULONG flags), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;

	Paula_Stop(flags, audioctrl, paula, paulaBase);

	return 0;
}

#ifdef __MORPHOS__
ULONG AHIsub_SetVol(void)
{
	UWORD channel = (UWORD)REG_D0;
	Fixed volume = (Fixed)REG_D1;
	/*sposition pan = (sposition)REG_D2;*/
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	ULONG flags = (ULONG)REG_D3;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_SetVol(REG(d0, UWORD channel), REG(d1, Fixed volume), REG(d2, sposition pan), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(d3, ULONG flags), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	struct Channel *chan = &paula->p_Channels[channel];

	if (!(paula->p_Flags & PF_DMA)) return AHIS_UNKNOWN;

	if ((volume /= 1024) < 0) volume = -volume;

	Paula_Disable(paula, paulaBase);

	chan->ch_NextVolumeNorm = volume;

	chan->ch_NextVolume = (paula->p_MasterVolume < 65536) ? ((paula->p_MasterVolume * volume) >> 16)
	                                                        : volume;

	if (flags & AHISF_IMM)
	{
		chan->ch_VolumeNorm = volume;

		chan->ch_Volume = (paula->p_MasterVolume < 65536) ? ((paula->p_MasterVolume * volume) >> 16)
		                                                    : volume;

		chan->ch_RegBase->ac_vol = chan->ch_Volume;
	}

	Paula_Enable(paula, paulaBase);

	return 0;
}

#ifdef __MORPHOS__
ULONG AHIsub_SetFreq(void)
{
	UWORD channel = (UWORD)REG_D0;
	ULONG freq = (ULONG)REG_D1;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	ULONG flags = (ULONG)REG_D2;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_SetFreq(REG(d0, UWORD channel), REG(d1, ULONG freq), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(d2, ULONG flags), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	struct Channel *chan = &paula->p_Channels[channel];
	ULONG scale = 0;
	ULONG maxfreq;
	ULONG period;

	if (!(paula->p_Flags & PF_DMA)) return AHIS_UNKNOWN;

	if (freq == AHI_MIXFREQ) freq = audioctrl->ahiac_MixFreq;

	maxfreq = paula->p_ScreenIsDouble ? 48000 : 28800;

	while (freq > maxfreq)
	{
		freq >>= 1;
		scale++;
	}

	if (freq == 0)
	{
		period = 0;
		scale = 0;
	}
	else
	{
		period = paulaBase->pb_AudioFreq / freq;
	}

	Paula_Disable(paula, paulaBase);

	chan->ch_NextPeriod = period;
	chan->ch_NextScale = scale;

	if (flags & AHISF_IMM)
	{
		if ((scale == 0) || (chan->ch_Scale == scale)) chan->ch_RegBase->ac_per = period;
		if ((chan->ch_Period == 0) && (chan->ch_NoInt == 0)) CUSTOM->intreq = chan->ch_IntMask | INTF_SETCLR;

		chan->ch_Period = period;
		chan->ch_Scale = scale;
	}

	Paula_Enable(paula, paulaBase);

	return 0;
}

#ifdef __MORPHOS__
ULONG AHIsub_SetSound(void)
{
	UWORD channel = (UWORD)REG_D0;
	UWORD sound = (UWORD)REG_D1;
	ULONG offset = (ULONG)REG_D2;
	LONG length = (LONG)REG_D3;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	ULONG flags = (ULONG)REG_D4;
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
ULONG AHIsub_SetSound(REG(d0, UWORD channel), REG(d1, UWORD sound), REG(d2, ULONG offset), REG(d3, LONG length), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(d4, ULONG flags), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	struct Channel *chan = &paula->p_Channels[channel];
	struct Sound *snd = &paula->p_Sounds[sound];
	ULONG type;

	if (!(paula->p_Flags & PF_DMA)) return AHIS_UNKNOWN;

	if (sound == AHI_NOSOUND)
	{
		offset = 0;
		length = 0;
		type = AHIST_NOTYPE;
	}
	else
	{
		if (!length) length = snd->so_Length;

		type = snd->so_Type;
	}

	if (length < 0)
	{
		length = -length;
		type = AHIST_BW;
	}

	Paula_Disable(paula, paulaBase);

	chan->ch_NextAddress = snd->so_Address;
	chan->ch_NextOffset = offset;
	chan->ch_NextLength = length;
	chan->ch_NextType = type;

	if (flags & AHISF_IMM)
	{
		UBYTE vbpos;

		chan->ch_Address = snd->so_Address;
		chan->ch_Offset = offset;
		chan->ch_Length = length;
		chan->ch_Type = type;
		chan->ch_Count = 0;
		chan->ch_EndOfSample = -1;

		/* Clear pending interrupt (if there was one) */
		chan->ch_NoInt = -1;
		CUSTOM->intreq = chan->ch_IntMask;

		/* Stop this channel */
		CUSTOM->dmacon = chan->ch_DMAMask;

		/* Wait for Agnus/Alice to understand */
		Disable();
		vbpos = CUSTOM->vhposr >> 8;
		while ((CUSTOM->vhposr >> 8) == vbpos);
		while (((BYTE)(CUSTOM->vhposr)) < 20);
		Enable();

		/* When the period reaches 0, Paula will invoke our interrupt routine! */
		/* Now just make sure that we receive no more than 1 interrupt. */
		chan->ch_RegBase->ac_per = 1;
	}

	Paula_Enable(paula, paulaBase);

	return 0;
}

#ifdef __MORPHOS__
ULONG AHIsub_SetEffect(void)
{
	APTR effect = (APTR)REG_A0;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	/*struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;*/
#else
ULONG AHIsub_SetEffect(REG(a0, APTR effect), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	struct Channel *chan = paula->p_Channels;
	struct AHIEffMasterVolume *mvol = effect;
	Fixed volume = 65536;
	int i = 3;

	if (!(paula->p_Flags & PF_DMA)) return AHIS_UNKNOWN;

	switch (mvol->ahie_Effect)
	{
		case AHIET_MASTERVOLUME:
			volume = mvol->ahiemv_Volume;

			/* Fall through */

		case AHIET_CANCEL | AHIET_MASTERVOLUME:
			paula->p_MasterVolume = volume;

			do
			{
				if (paula->p_MasterVolume < 65536)
				{
					chan->ch_NextVolume = ((paula->p_MasterVolume * chan->ch_NextVolumeNorm) >> 16);
					chan->ch_Volume = ((paula->p_MasterVolume * chan->ch_VolumeNorm) >> 16);
				}
				else
				{
					chan->ch_NextVolume = chan->ch_NextVolumeNorm;
					chan->ch_Volume = chan->ch_VolumeNorm;
				}

				chan->ch_RegBase->ac_vol = chan->ch_Volume;
				chan++;
			} while (i--);
			break;

		case AHIET_CHANNELINFO:
			paula->p_ChannelInfo = effect;
			break;

		case AHIET_CANCEL | AHIET_CHANNELINFO:
			paula->p_ChannelInfo = 0;
			break;

		default:
			return AHIE_UNKNOWN;
			break;
	}

	return AHIE_OK;
}

#ifdef __MORPHOS__
ULONG AHIsub_LoadSound(void)
{
	UWORD sound = (UWORD)REG_D0;
	ULONG type = (ULONG)REG_D1;
	struct AHISampleInfo *info = (APTR)REG_A0;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	/*struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;*/
#else
ULONG AHIsub_LoadSound(REG(d0, UWORD sound), REG(d1, ULONG type), REG(a0, struct AHISampleInfo *info), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	struct Sound *snd = &paula->p_Sounds[sound];

	if (!(paula->p_Flags & PF_DMA)) return AHIS_UNKNOWN;

	if ((type != AHIST_SAMPLE) && (type != AHIST_DYNAMICSAMPLE)) return AHIE_BADSOUNDTYPE;

	switch (info->ahisi_Type)
	{
		case AHIST_M8S:
		case AHIST_S8S:
		case AHIST_M16S:
		case AHIST_S16S:
			snd->so_Type = info->ahisi_Type;
			snd->so_Address = info->ahisi_Address;
			snd->so_Length = info->ahisi_Length;
			break;

		default:
			return AHIE_BADSAMPLETYPE;
			break;
	}

	return AHIE_OK;
}

#ifdef __MORPHOS__
ULONG AHIsub_UnloadSound(void)
{
	UWORD sound = (UWORD)REG_D0;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	/*struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;*/
#else
ULONG AHIsub_UnloadSound(REG(d0, UWORD sound), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	struct Sound *snd = &paula->p_Sounds[sound];

	if (!(paula->p_Flags & PF_DMA)) return AHIS_UNKNOWN;

	snd->so_Type = AHIST_NOTYPE;
	snd->so_Address = 0;
	snd->so_Length = 0;

	return AHIE_OK;
}

CONST_STRPTR inputs[] =
{
	"Parallel port sampler",
	"Aura sampler",
	"Clarity sampler"
};

#ifdef __MORPHOS__
LONG AHIsub_GetAttr(void)
{
	ULONG attribute = (ULONG)REG_D0;
	LONG argument = (LONG)REG_D1;
	LONG def = (LONG)REG_D2;
	struct TagItem *taglist = (struct TagItem *)REG_A1;
	/*struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;*/
	struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;
#else
LONG AHIsub_GetAttr(REG(d0, ULONG attribute), REG(d1, LONG argument), REG(d2, LONG def), REG(a1, struct TagItem *taglist), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	ULONG b14 = FALSE;
	ULONG dma = FALSE;

	if (taglist)
	{
		b14 = GetTagData(AHIDB_Paula14Bit, b14, taglist);
		dma = GetTagData(AHIDB_PaulaDMA, dma, taglist);
	}

	if ((attribute & ~AHI_TagBaseR) > (AHIDB_Data & ~AHI_TagBaseR)) return def;

	switch (attribute)
	{
		case AHIDB_Volume:
			return (dma ? TRUE : def);
			break;

		case AHIDB_Panning:
			return (dma ? FALSE : def);
			break;

		case AHIDB_Stereo:
			return (dma ? TRUE : def);
			break;

		case AHIDB_HiFi:
			return (dma ? TRUE : def);
			break;

		case AHIDB_PingPong:
			return (dma ? TRUE : def);
			break;

		case AHIDB_Bits:
			return (b14 ? 14 : 8);
			break;

		case AHIDB_MaxChannels:
			return (dma ? 4 : def);
			break;

		case AHIDB_Record:
			return (b14 ? FALSE : (dma ? FALSE : TRUE));
			break;

		case AHIDB_Frequencies:
			return (dma ? 1 : (checkvideo(paulaBase) ? 23 : 17));
			break;

		case AHIDB_Frequency:
			return (dma ? ((GfxBase->DisplayFlags & REALLY_PAL) ? PALFREQ : NTSCFREQ) : freqlist[argument]);
			break;

		case AHIDB_Author:
			return (LONG)((APTR)"Sigbjørn 'CISC' Skjæret and Harry 'Piru' Sintonen");
			break;

		case AHIDB_Copyright:
			return (LONG)((APTR)"Sigbjørn Skjæret and Harry Sintonen");
			break;

		case AHIDB_Version:
			return (LONG)&LibVersion[6];
			break;

		case AHIDB_Annotation:
			return (LONG)((APTR)"Based on 68k paula.audio by Martin Blom and 14 bit routines by Christian Buchner.");
			break;

		case AHIDB_Index:
			return findfreq(argument);
			break;

		case AHIDB_Realtime:
			return TRUE;
			break;

		case AHIDB_MaxRecordSamples:
			return RECORDSAMPLES;
			break;

		case AHIDB_FullDuplex:
			return (b14 ? FALSE : (dma ? FALSE : TRUE));
			break;

		case AHIDB_MinMonitorVolume:
			return 0;
			break;

		case AHIDB_MaxMonitorVolume:
			return (b14 ? 0 : (dma ? 0 : 65536));
			break;

		case AHIDB_MinInputGain:
			return 65536;
			break;

		case AHIDB_MaxInputGain:
			return 65536;
			break;

		case AHIDB_MinOutputVolume:
			return (b14 ? 65536 : (dma ? 65536 : 0));
			break;

		case AHIDB_MaxOutputVolume:
			return 65536;
			break;

		case AHIDB_Inputs:
			return (b14 ? 0 : (dma ? 0 : 3));
			break;

		case AHIDB_Input:
			return (LONG)inputs[argument];
			break;

		case AHIDB_Outputs:
			return 1;
			break;

		case AHIDB_Output:
			return (LONG)((APTR)"Line");
			break;

		default:
			return def;
			break;
	}
}

#ifdef __MORPHOS__
LONG AHIsub_HardwareControl(void)
{
	ULONG attribute = (ULONG)REG_D0;
	LONG argument = (LONG)REG_D1;
	struct AHIAudioCtrlDrv *audioctrl = (struct AHIAudioCtrlDrv *)REG_A2;
	/*struct paulaBase *paulaBase = (struct paulaBase *)REG_A6;*/
#else
LONG AHIsub_HardwareControl(REG(d0, ULONG attribute), REG(d1, LONG argument), REG(a2, struct AHIAudioCtrlDrv *audioctrl), REG(a6, struct paulaBase *paulaBase))
{
#endif
	struct Paula *paula = (struct Paula *)audioctrl->ahiac_DriverData;
	LONG ret = TRUE;

	switch (attribute)
	{
		case AHIC_MonitorVolume:
			paula->p_MonitorVolume = argument >> 10;
			break;

		case AHIC_MonitorVolume_Query:
			ret = paula->p_MonitorVolume << 10;
			break;

		case AHIC_OutputVolume:
			paula->p_OutputVolume = argument >> 10;
			break;

		case AHIC_OutputVolume_Query:
			ret = paula->p_OutputVolume << 10;
			break;

		case AHIC_Input:
			paula->p_Input = argument;
			break;

		case AHIC_Input_Query:
			ret = paula->p_Input;
			break;

		default:
			ret = FALSE;
			break;
	}

	return ret;
}
