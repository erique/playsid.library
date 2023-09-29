#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include <proto/exec.h>
#include <proto/poseidon.h>
#include <exec/alerts.h>
#include <utility/hooks.h>

#include "sidblast.h"

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

    uint8_t             latency;
    int8_t              taskpri;
};

static struct SIDBlasterUSB* usb = NULL;

static void SIDTask();
static bool writePacket(uint8_t* packet, uint16_t length);
static uint8_t readResult();
static uint32_t deviceUnplugged(register struct Hook *hook __asm("a0"), register APTR object __asm("a2"), register APTR message __asm("a1"));
typedef ULONG (*HOOKFUNC_ULONG)();  // NDK typedef HOOKFUNC with 'unsigned long'
static const struct Hook hook = { .h_Entry = (HOOKFUNC_ULONG)deviceUnplugged };

#ifdef DEBUG

  #define DPRINT kprintf
void kprintf(const char *format, ...)
{
    va_list args;
    static const uint16_t raw_put_char[5] = {0xcd4b, 0x4eae, 0xfdfc, 0xcd4b, 0x4e75};
    va_start(args, format);

    RawDoFmt((STRPTR) format, (APTR) args,
             (void (*)()) raw_put_char, (APTR) SysBase);

    va_end(args);
}
#else
  #define DPRINT
#endif

uint8_t sid_init(register uint8_t latency __asm("d0"), register int8_t taskpri __asm("d1"))
{
    DPRINT("sid_init\n");
    if (usb) {
        DPRINT("usb != NULL\n");
        return usb != NULL;
    }

    struct Library* PsdBase;
    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {   
        DPRINT("poseidon open fail\n");
        return FALSE;
    }

    usb = psdAllocVec(sizeof(struct SIDBlasterUSB));

    if (!usb)
    {
        DPRINT("psdAllocVec fail\n");
        CloseLibrary(PsdBase);
        return FALSE;
    }

    usb->latency = latency;
    usb->taskpri = taskpri;

    usb->ctrlTask = FindTask(NULL);
    SetSignal(0, SIGF_SINGLE);
    if (psdSpawnSubTask("SIDTask", SIDTask, usb))
    {
        Wait(SIGF_SINGLE);
    } else {
        DPRINT("psdSpawnSubTask fail\n");
    }
    usb->ctrlTask = NULL;

    if (usb->mainTask)
    {
        psdAddErrorMsg(RETURN_OK, "SIDBlasterUSB", "Time to rock some 8-bit!");
    }
    else
    {
        DPRINT("failed to acquire hw\n"); 
        psdAddErrorMsg(RETURN_ERROR, "SIDBlasterUSB", "Failed to acquire ancient hardware!");
        sid_exit();
    }

    CloseLibrary(PsdBase);
    PsdBase = NULL;
        
    DPRINT("return %ld\n", (int)(usb != NULL)); 
    return usb != NULL;
}

void sid_exit()
{
    DPRINT("sid_exit\n");
    if (!usb) {
       DPRINT("!usb\n");
       return;
    }
        
    if(usb->mainTask)
    {
        DPRINT("reset SID\n");
        // reset SID output
        sid_write_reg(0x00, 0x00);  // freq voice 1
        sid_write_reg(0x01, 0x00);
        sid_write_reg(0x07, 0x00);  // freq voice 2
        sid_write_reg(0x08, 0x00);
        sid_write_reg(0x0e, 0x00);  // freq voice 3
        sid_write_reg(0x0f, 0x00);
    }

    struct Library* PsdBase;
    if((PsdBase = OpenLibrary("poseidon.library", 1)))
    {
        DPRINT("stop tasks\n");
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

uint8_t sid_read_reg(register uint8_t reg __asm("d0"))
{
    if (!(usb && !usb->deviceLost))
        return 0x00;

    usb->ctrlTask = FindTask(NULL);

    uint8_t buf[] = { 0xa0 + reg };
    bool success = writePacket(buf, sizeof(buf));
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);

    if (!success)
        return 0xff;

    Wait(SIGBREAKF_CTRL_D);
    usb->ctrlTask = NULL;

    return readResult();
}

void sid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
    if (!(usb && !usb->deviceLost))
        return;

    uint8_t buf[] = { 0xe0 + reg, value };
    writePacket(buf, sizeof(buf));
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);
}


/*-------------------------------------------------------*/


#define PsdBase usb->psdLibrary

static uint8_t AllocSID(struct SIDBlasterUSB* usb);
static void FreeSID(struct SIDBlasterUSB* usb);

static void SIDTask()
{
    DPRINT("SIDTask\n"); 

    struct Task* currentTask = FindTask(NULL);
    struct SIDBlasterUSB* usb = currentTask->tc_UserData;

    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {
        DPRINT("OpenLibrary fail\n"); 
        Alert(AG_OpenLib);
    }
    else if (AllocSID(usb))
    {
        DPRINT("AllocSID OK\n"); 

        usb->mainTask = currentTask;

        Forbid();
        if(usb->ctrlTask)
        {
            Signal(usb->ctrlTask, SIGF_SINGLE);
        }
        Permit();

        SetTaskPri(currentTask, usb->taskpri);

        uint32_t signals;
        uint32_t sigMask = (1L << usb->msgPort->mp_SigBit) | SIGBREAKF_CTRL_C | SIGBREAKF_CTRL_D;

        uint8_t result[3];
        psdSendPipe(usb->inPipe, result, sizeof(result));
        do
        {
            signals = Wait(sigMask);

            struct PsdPipe* pipe;
            while((pipe = (struct PsdPipe *) GetMsg(usb->msgPort)))
            {  
                if (pipe != usb->inPipe)
                    continue;

                uint32_t ioerr;
                if((ioerr = psdGetPipeError(pipe)))
                {
                    if (usb->deviceLost)
                        break;
                    psdDelayMS(20);
                }
                else
                {
                    uint32_t actual = psdGetPipeActual(pipe);
                    if (actual > 2)
                    {
                        uint8_t res = result[2];

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

                psdSendPipe(usb->inPipe, result, sizeof(result));
            }

            if (signals & SIGBREAKF_CTRL_D)
            {
                Disable();
                struct Buffer* buffer = &usb->outBuffers[usb->outBufferNum];
                usb->outBufferNum ^= 1;
                usb->outBuffers[usb->outBufferNum].pending = 0;
                Enable();

                if (buffer->pending)
                    psdDoPipe(usb->outPipe, buffer->data, buffer->pending);
            }

        } while(!(signals & SIGBREAKF_CTRL_C));
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
    DPRINT("AllocSID\n"); 

    // Find SIDBlasterUSB
    {
        DPRINT("psdLocReadPBase\n"); 
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
            DPRINT("psdFindDevice pd=%lx\n", (int)pd); 
            psdLockReadDevice(pd);

            const char* product;
            psdGetAttrs(PGA_DEVICE, pd,
                        DA_ProductName, (ULONG)&product,
                        TAG_END);

            if (product) {
                DPRINT("product=%s\n", product);
            } else {
                DPRINT("product=NULL\n"); 
            }
                
            pab = psdClaimAppBinding(ABA_Device, (ULONG)pd,
                                ABA_ReleaseHook, (ULONG)&hook,
                                ABA_UserData, (ULONG)usb);

            DPRINT("psdClaimAppBinding pab=%lx\n", (int)pab); 

            psdUnlockDevice(pd);

            if (pab) 
                break;
        }

        psdUnlockPBase();

        if (!pd) {
            DPRINT("!pd, return FALSE\n"); 
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

    if (usb->psdLibrary)
    {
        CloseLibrary(usb->psdLibrary);
        usb->psdLibrary = NULL;
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

static bool writePacket(uint8_t* packet, uint16_t length)
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

        Disable();
        if (bufNum != usb->outBufferNum)
        {
            // the buffer changed - retry
            Enable();
            continue;
        }

        uint8_t* dest = &buffer->data[buffer->pending];
        CopyMem(packet, dest, length);
        buffer->pending += length;

        Enable();
        break;
    }
    return true;
}

static uint8_t readResult()
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
