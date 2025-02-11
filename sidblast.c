#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include <proto/exec.h>
#include <exec/alerts.h>
#include <exec/execbase.h>
#include <utility/hooks.h>
#include <inline/poseidon.h>
#include <libraries/poseidon.h>

#include "sidblast.h"

#if 1 // NDEBUG
#define kprintf(...) do {} while(0)
#else
static int kprintf(const char* format, ...);
#endif

#define SysBase (*(struct ExecBase **) (4L))

struct Buffer
{
    uint16_t    pending;
    uint8_t     data[8192];
};

struct SIDBlasterUSB
{
    struct PsdDevice*   device;

    struct Task*        ctrlTask;
    struct Task*        mainTask;

    struct Library*     psdLibrary;
    struct MsgPort*     msgPort;
    struct PsdPipe*     inPipe;
    struct PsdPipe*     outPipe;

    uint16_t            inBufferNum;
    uint16_t            outBufferNum;

    struct Buffer       inBuffers[2];
    struct Buffer       outBuffers[2];

    uint32_t            deviceLost;

    uint16_t            pendingRecorded;
    uint8_t             dataRecorded[256];

    uint8_t             latency;
    int8_t              taskpri;
};

static uint32_t num_blasters = 0;
static struct SIDBlasterUSB* blasters[8];

static void SIDTask();
static bool writePacket(struct SIDBlasterUSB* usb, const uint8_t* packet, uint16_t length);
static uint8_t readResult(struct SIDBlasterUSB* usb);
static uint32_t deviceUnplugged(register struct Hook *hook __asm("a0"), register APTR object __asm("a2"), register APTR message __asm("a1"));
typedef ULONG (*HOOKFUNC_ULONG)();  // NDK typedef HOOKFUNC with 'unsigned long'
static const struct Hook hook = { .h_Entry = (HOOKFUNC_ULONG)deviceUnplugged };


static struct SIDBlasterUSB* claim_sidblaster(uint8_t latency, uint8_t taskpri);
static void release_sidblaster(struct SIDBlasterUSB* usb);

uint8_t sidblaster_init(register uint8_t latency __asm("d0"), register int8_t taskpri __asm("d1"))
{
    kprintf("sidblaster_init\n");
    if (num_blasters) {
        kprintf("usb != NULL\n");
        return num_blasters != 0;
    }

    memset(blasters, 0x00, sizeof(blasters));

    while(num_blasters < 8)
    {
        blasters[num_blasters] = claim_sidblaster(latency, taskpri);
        if (!blasters[num_blasters])
        {
            kprintf("no more blasters\n");
            break;
        }
        num_blasters++;
    }

    kprintf("return %ld blasters\n", (int)(num_blasters)); 
    return num_blasters != 0;
}

void sidblaster_exit()
{
    kprintf("sidblaster_exit\n");
    if (!num_blasters) {
       kprintf("!usb\n");
       return;
    }

    while(num_blasters != 0)
    {
        num_blasters--;
        release_sidblaster(blasters[num_blasters]);
    }    

    memset(blasters, 0x00, sizeof(blasters));
}

static struct SIDBlasterUSB* claim_sidblaster(uint8_t latency, uint8_t taskpri)
{
    kprintf("claim_sidblaster\n");
    struct Library* PsdBase;
    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {   
        kprintf("poseidon open fail\n");
        return NULL;
    }

    struct SIDBlasterUSB* usb = psdAllocVec(sizeof(struct SIDBlasterUSB));

    if (!usb)
    {
        kprintf("psdAllocVec fail\n");
        CloseLibrary(PsdBase);
        return NULL;
    }

    usb->psdLibrary = PsdBase;

    usb->latency = latency;
    usb->taskpri = taskpri;

    usb->ctrlTask = FindTask(NULL);
    SetSignal(0, SIGF_SINGLE);
    if (psdSpawnSubTask("SIDTask", SIDTask, usb))
    {
        Wait(SIGF_SINGLE);
    } else {
        kprintf("psdSpawnSubTask fail\n");
    }
    usb->ctrlTask = NULL;

    if (usb->mainTask)
    {
        psdAddErrorMsg(RETURN_OK, "SIDBlasterUSB", "Time to rock some 8-bit!");
    }
    else
    {
        kprintf("failed to acquire hw\n"); 
        psdAddErrorMsg(RETURN_ERROR, "SIDBlasterUSB", "Failed to acquire ancient hardware!");
        release_sidblaster(usb);
        return NULL;
    }
    return usb;
}

static void release_sidblaster(struct SIDBlasterUSB* usb)
{
    kprintf("release_sidblaster\n");
    if (!usb) {
       kprintf("!usb\n");
       return;
    }
        
    if(usb->mainTask)
    {
        kprintf("reset SID\n");
        sidblaster_reset();
    }

    struct Library* PsdBase = usb->psdLibrary;
    {
        kprintf("stop tasks\n");
        usb->ctrlTask = FindTask(NULL);

        Forbid();
        SetSignal(0, SIGF_SINGLE);
        if(usb->mainTask)
        {
            Signal(usb->mainTask, SIGBREAKF_CTRL_C);
            Permit();

            Wait(SIGF_SINGLE);
        }
        else
        {
            Permit();
        }

        usb->ctrlTask = NULL;

        psdFreeVec(usb);
        usb = NULL;

        CloseLibrary(PsdBase);
        PsdBase = NULL;
    }
}

static inline uint8_t sid_address(uint8_t reg)
{
    return (reg >> 5) & 0x7;
}

uint8_t sidblaster_read_reg(register uint8_t reg __asm("d0"))
{
    struct SIDBlasterUSB* usb = blasters[sid_address(reg)];
    reg &= 0x1f;

    if (!(usb && !usb->deviceLost))
        return 0x00;

    // flush all recorded writes
    // sidblaster_write_reg_playback();

    usb->ctrlTask = FindTask(NULL);

    uint8_t buf[] = { 0xa0 + reg };
    bool success = writePacket(usb, buf, sizeof(buf));
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);

    if (!success)
        return 0xff;

    Wait(SIGBREAKF_CTRL_D);
    usb->ctrlTask = NULL;

    return readResult(usb);
}

void sidblaster_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
    struct SIDBlasterUSB* usb = blasters[sid_address(reg)];
    reg &= 0x1f;

    if (!(usb && !usb->deviceLost))
        return;

    // flush all recorded writes
    // sidblaster_write_reg_playback();

    uint8_t buf[] = { 0xe0 + reg, value };
    writePacket(usb, buf, sizeof(buf));
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);
}

void sidblaster_write_reg_record(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
    struct SIDBlasterUSB* usb = blasters[sid_address(reg)];
    reg &= 0x1f;

    if (!usb)
        return;

    if (usb->pendingRecorded > sizeof(usb->dataRecorded) - 2)
        return;

    uint8_t* p = &usb->dataRecorded[usb->pendingRecorded];
    *p++ = 0xe0 + reg;
    *p++ = value;

    usb->pendingRecorded += 2;
}

void sidblaster_write_reg_playback()
{   
    for (int i = 0; i < num_blasters; ++i)
    {
        struct SIDBlasterUSB* usb = blasters[i];
        if (!(usb && !usb->deviceLost))
            continue;

        if (!usb->pendingRecorded)
            continue;

        writePacket(usb, usb->dataRecorded, usb->pendingRecorded);
        Signal(usb->mainTask, SIGBREAKF_CTRL_D);
        usb->pendingRecorded = 0;
    }
}

void sidblaster_reset()
{
    sidblaster_write_reg_playback();

    const uint8_t regs[] = 
    {
        0xe0 + 0x00, 0x00, 
        0xe0 + 0x01, 0x00, 
        0xe0 + 0x07, 0x00, 
        0xe0 + 0x08, 0x00, 
        0xe0 + 0x0e, 0x00, 
        0xe0 + 0x0f, 0x00
    };

    for (int i = 0; i < num_blasters; ++i)
    {
        struct SIDBlasterUSB* usb = blasters[i];
        if (!(usb && !usb->deviceLost))
            continue;

        writePacket(usb, regs, sizeof(regs));
        Signal(usb->mainTask, SIGBREAKF_CTRL_D);
        usb->pendingRecorded = 0;
    }
}

/*-------------------------------------------------------*/


#define PsdBase usb->psdLibrary

static uint8_t AllocSID(struct SIDBlasterUSB* usb);
static void FreeSID(struct SIDBlasterUSB* usb);

static void SIDTask()
{
    kprintf("SIDTask\n"); 

    struct Task* currentTask = FindTask(NULL);
    struct SIDBlasterUSB* usb = currentTask->tc_UserData;

    if (AllocSID(usb))
    {
        kprintf("AllocSID OK\n"); 

        usb->mainTask = currentTask;

        Forbid();
        if(usb->ctrlTask)
        {
            Signal(usb->ctrlTask, SIGF_SINGLE);
        }
        Permit();

        SetTaskPri(currentTask, usb->taskpri);

        uint32_t sigMask = SIGBREAKF_CTRL_C | SIGBREAKF_CTRL_D;

        uint32_t signals = 0;

        do
        {
            signals = Wait(sigMask);

            if (signals & SIGBREAKF_CTRL_D)
            {
                Disable();
                struct Buffer* buffer = &usb->outBuffers[usb->outBufferNum];
                usb->outBufferNum ^= 1;
                usb->outBuffers[usb->outBufferNum].pending = 0;
                Enable();

                if (buffer->pending)
                {
                    uint8_t* p = buffer->data;
                    kprintf("TX : ", buffer->pending);
                    for (int16_t i = buffer->pending-1; i >= 0; --i)
                        kprintf("%02lx, ", *p++);
                    kprintf("\n");

                    // odd number of bytes means there is read request (at the end).
                    const bool regRead = buffer->pending & 0x1;

                    int16_t ret = -1;

                    uint8_t result[3];
                    if (regRead)
                        psdSendPipe(usb->inPipe, result, sizeof(result));

                    psdDoPipe(usb->outPipe, buffer->data, buffer->pending);

                    if (regRead)
                    {
                        do
                        {
                            uint32_t ioerr = psdWaitPipe(usb->inPipe);
                            uint32_t actual = psdGetPipeActual(usb->inPipe);

                            if(ioerr)
                            {
                                kprintf("psdSendPipe(IN) failed! ioerr = %08lx ; actual = %ld\n", ioerr, actual);
                            }
                            else
                            {
                                if (actual > 2)
                                {
                                    ret = result[2];
                                    kprintf("RX : %02lx\n", ret);
                                    break;
                                }
                            }
                            // try again
                            psdSendPipe(usb->inPipe, result, sizeof(result));
                        }
                        while(ret < 0);

                        uint8_t res = (uint8_t)(ret & 0xff);

                        Disable();
                        struct Buffer* buffer = &usb->inBuffers[usb->inBufferNum];
                        if (sizeof(buffer->data) - 1 > buffer->pending)
                        {
                            buffer->data[buffer->pending] = res;
                            buffer->pending += 1;
                            if (usb->ctrlTask)
                            {
                                Signal(usb->ctrlTask, SIGBREAKF_CTRL_D);
                            }
                        }
                        Enable();
                    }
                }
            }
        } while(!(signals & SIGBREAKF_CTRL_C));
        kprintf("SIGBREAKF_CTRL_C received! We're done..\n");
    }
    else
    {
        kprintf("SID not found!\n");
    }

    FreeSID(usb);

    Forbid();
    usb->mainTask = NULL;
    if(usb->ctrlTask)
    {
        Signal(usb->ctrlTask, SIGF_SINGLE);
    }
}

static uint8_t AllocSID(struct SIDBlasterUSB* usb)
{
    kprintf("AllocSID\n"); 

    // Find SIDBlasterUSB
    {
        kprintf("psdLocReadPBase\n"); 
        psdLockReadPBase();

        APTR pab = NULL;

        APTR pd = NULL;
        while(pd = psdFindDevice(pd, 
                                DA_VendorID, 0x0403,
                                DA_ProductID, 0x6001,
                                DA_Manufacturer, (ULONG)"Devsound",
                                DA_Binding, (ULONG)NULL,
                                TAG_END))
        {
            kprintf("psdFindDevice pd=%lx\n", (int)pd); 
            psdLockReadDevice(pd);

            const char* product;
            psdGetAttrs(PGA_DEVICE, pd,
                        DA_ProductName, (ULONG)&product,
                        TAG_END);

            if (product) {
                kprintf("product=%s\n", product);
            } else {
                kprintf("product=NULL\n"); 
            }
                
            pab = psdClaimAppBinding(ABA_Device, (ULONG)pd,
                                ABA_ReleaseHook, (ULONG)&hook,
                                ABA_UserData, (ULONG)usb);

            kprintf("psdClaimAppBinding pab=%lx\n", (int)pab); 

            psdUnlockDevice(pd);

            if (pab) 
                break;
        }

        psdUnlockPBase();

        if (!pd) {
            kprintf("!pd, return FALSE\n"); 
            return FALSE;
        }

        usb->device = pd;
    }

    if (!(usb->msgPort = CreateMsgPort()))
        return FALSE;

    // Init SIDBlasterUSB (based on wireshark'd USB sniffing)
    {
        enum FTDI_Request
        {
            FTDI_Reset          = 0x00,
            FTDI_ModemCtrl      = 0x01,
            FTDI_SetFlowCtrl    = 0x02,
            FTDI_SetBaudRate    = 0x03,
            FTDI_SetData        = 0x04,
            FTDI_GetModemStat   = 0x05,
            FTDI_SetLatTimer    = 0x09,
            FTDI_GetLatTimer    = 0x0A,
            FTDI_ReadEEPROM     = 0x90,
        };

        enum FTDI_ResetType
        {
            FTDI_Reset_PurgeRXTX = 0,
            FTDI_Reset_PurgeRX,
            FTDI_Reset_PurgeTX
        };

        uint8_t recvBuffer[64];
        struct PsdPipe* ep0pipe = psdAllocPipe(usb->device, usb->msgPort, NULL);
        if (!ep0pipe)
            return FALSE;

        psdPipeSetup(ep0pipe, URTF_IN|URTF_VENDOR, FTDI_GetLatTimer, 0x00, 0x00);
        psdDoPipe(ep0pipe, recvBuffer, 1);

        psdPipeSetup(ep0pipe, URTF_VENDOR, FTDI_SetLatTimer, usb->latency, 0x00);
        psdDoPipe(ep0pipe, NULL, 0);

        psdPipeSetup(ep0pipe, URTF_IN|URTF_VENDOR, FTDI_GetLatTimer, 0x00, 0x00);
        psdDoPipe(ep0pipe, recvBuffer, 1);

        psdPipeSetup(ep0pipe, URTF_IN|URTF_VENDOR, FTDI_ReadEEPROM, 0x00, 0x0a);
        psdDoPipe(ep0pipe, recvBuffer, 2);

        psdPipeSetup(ep0pipe, URTF_VENDOR, FTDI_Reset, FTDI_Reset_PurgeRXTX, 0x00);
        psdDoPipe(ep0pipe, NULL, 0);
        for (int i = 0; i < 6; ++i) {
            psdPipeSetup(ep0pipe, URTF_VENDOR, FTDI_Reset, FTDI_Reset_PurgeRX, 0x00);
            psdDoPipe(ep0pipe, NULL, 0);
        }
        psdPipeSetup(ep0pipe, URTF_VENDOR, FTDI_Reset, FTDI_Reset_PurgeTX, 0x00);
        psdDoPipe(ep0pipe, NULL, 0);

        psdPipeSetup(ep0pipe, URTF_IN|URTF_VENDOR, FTDI_GetModemStat, 0x00, 0x00);
        psdDoPipe(ep0pipe, recvBuffer, 2);

        psdPipeSetup(ep0pipe, URTF_IN|URTF_VENDOR, FTDI_GetLatTimer, 0x00, 0x00);
        psdDoPipe(ep0pipe, recvBuffer, 1);

        psdPipeSetup(ep0pipe, URTF_VENDOR, FTDI_SetBaudRate, 0x06, 0x00);
        psdDoPipe(ep0pipe, NULL, 0);

        psdPipeSetup(ep0pipe, URTF_VENDOR, FTDI_SetData, 0x08, 0x00);
        psdDoPipe(ep0pipe, NULL, 0);

        psdFreePipe(ep0pipe);
    }

    // Allocate in/out pipes
    {
        struct PsdInterface* interface = psdFindInterface(usb->device, NULL, TAG_END);
        if (!interface)
            return FALSE;

        struct PsdEndpoint* epIn = psdFindEndpoint(interface, NULL,
                                                   EA_IsIn, TRUE,
                                                   EA_TransferType, USEAF_BULK,
                                                   TAG_END);
        if (!epIn)
            return FALSE;

        struct PsdEndpoint* epOut = psdFindEndpoint(interface, NULL,
                                                   EA_IsIn, FALSE,
                                                   EA_TransferType, USEAF_BULK,
                                                   TAG_END);
        if (!epOut)
            return FALSE;

        if (!(usb->inPipe = psdAllocPipe(usb->device, usb->msgPort, epIn)))
            return FALSE;
        if (!(usb->outPipe = psdAllocPipe(usb->device, usb->msgPort, epOut)))
            return FALSE;
    }

    return TRUE;
}

static void FreeSID(struct SIDBlasterUSB* usb)
{
    if (usb->inPipe)
    {
        psdAbortPipe(usb->inPipe);
        psdWaitPipe(usb->inPipe);
        psdFreePipe(usb->inPipe);
        usb->inPipe = NULL;
    }

    if (usb->outPipe)
    {
        psdAbortPipe(usb->outPipe);
        psdWaitPipe(usb->outPipe);
        psdFreePipe(usb->outPipe);
        usb->outPipe = NULL;
    }

    if (usb->msgPort)
    {
        DeleteMsgPort(usb->msgPort);
        usb->msgPort = NULL;
    }

    if (usb->device)
    {
        struct PsdAppBinding* appBinding = NULL;
        psdGetAttrs(PGA_DEVICE, usb->device,
                    DA_Binding, (ULONG)&appBinding,
                    TAG_END);
        psdReleaseAppBinding(appBinding);
        usb->device = NULL;
    }
}

static uint32_t deviceUnplugged(register struct Hook *hook __asm("a0"), register APTR object __asm("a2"), register APTR message __asm("a1"))
{
    struct SIDBlasterUSB* usb = (struct SIDBlasterUSB*)message;

    usb->deviceLost = TRUE;

    if (usb->outPipe)
        psdAbortPipe(usb->outPipe);

    Forbid();
    if(usb->mainTask)
    {
        Signal(usb->mainTask, SIGBREAKF_CTRL_C);

        psdAddErrorMsg(RETURN_OK, "SIDBlasterUSB", "End of an era");
    }
    Permit();

    return 0;
}

#define DISABLE(execbase)                           \
    do {                                            \
        __asm volatile(                             \
            "MOVE.W  #0x4000,0xdff09a   \n"         \
            "ADDQ.B  #1,0x126(%0)       \n"         \
            : : "a"(execbase) : "cc", "memory");    \
    } while(0)

#define ENABLE(execbase)                            \
    do {                                            \
        __asm volatile(                             \
            "SUBQ.B  #1,0x126(%0)       \n"         \
            "BGE.S   ENABLE%=           \n"         \
            "MOVE.W  #0xc000,0xdff09a   \n"         \
            "ENABLE%=:                  \n"         \
            : : "a"(execbase) : "cc", "memory");    \
    } while(0)


static bool writePacket(struct SIDBlasterUSB* usb, const uint8_t* packet, uint16_t length)
{
    while(TRUE)
    {
        uint16_t bufNum = usb->outBufferNum;

        struct Buffer* buffer = &usb->outBuffers[bufNum];
        if ((sizeof(buffer->data) - length) < buffer->pending)
        {
            // not enough space, abort
            SysBase->SysFlags |= 0x8000; // trigger reschedule
            return false;
        }

        DISABLE(SysBase);

        if (bufNum != usb->outBufferNum)
        {
            // the buffer changed - retry
            ENABLE(SysBase);
            continue;
        }

        uint8_t* dest = &buffer->data[buffer->pending];
        for (int16_t i = length-1; i >= 0; --i)
            *dest++ =  *packet++;
        buffer->pending += length;

        ENABLE(SysBase);
        break;
    }
    return true;
}

static uint8_t readResult(struct SIDBlasterUSB* usb)
{
    while(TRUE)
    {
        Disable();

        struct Buffer* buffer = &usb->inBuffers[usb->inBufferNum];
        if (buffer->pending < 1)
        {
            // not enough data, retry
            Enable();
            continue;
        }

        uint8_t result = buffer->data[0];
        buffer->pending = 0;
        usb->inBufferNum ^= 1;
        usb->inBuffers[usb->inBufferNum].pending = 0;

        Enable();

        return result;
    }
}


/*-------------------------------------------------------*/

#ifndef kprintf

#define RawPutChar(___ch) \
    LP1NR(516, RawPutChar , BYTE, ___ch, d0,\
          , EXEC_BASE_NAME)

static void raw_put_char(uint32_t c __asm("d0"))
{
    RawPutChar(c);
}

static int kvprintf(const char* format, va_list ap)
{
//    __asm volatile("move.w #3546895/115200,0xdff032": : : "cc", "memory");

    RawDoFmt((STRPTR)format, ap, (__fpt)raw_put_char, NULL);
    return 0;
}

static int kprintf(const char* format, ...)
{
    if (format == NULL)
        return 0;

    va_list arg;
    va_start(arg, format);
    int ret = kvprintf(format, arg);
    va_end(arg);
    return ret;
}

#endif
