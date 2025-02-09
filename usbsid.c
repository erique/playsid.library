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

#include "usbsid.h"

#define SID_WRITE           (0 << 6)                /*        0b0 ~ 0x00 */
#define SID_READ            (1 << 6)                /*        0b1 ~ 0x40 */
#define SID_CYCLED_WRITE    (2 << 6)                /*       0b10 ~ 0x80 */
#define SID_COMMAND         (3 << 6)                /*       0b11 ~ 0xC0 */
#define SID_RESET_SID       (14)                    /*     0b1110 ~ 0x0E */
#define SID_CONFIG          (18)
#define SID_RELOAD_CONFIG   (0x38)  /* Reload and apply stored config from flash */
#define SID_MIRRORED_SID    (0x45)

#define EP_SIZE             (0x40)                  /* endpoint size     */
#define MAX_PACKET_SIZE     (EP_SIZE - 1)           /* max command size  */

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

struct USBSID_Pico
{
    struct PsdDevice*   device;

    struct Task*        ctrlTask;
    struct Task*        mainTask;
    struct Task*        flushTask;

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

static struct USBSID_Pico* usb = NULL;

static void SIDTask();
static bool writePacket(uint8_t command, const uint8_t* packet, uint16_t length);
static void writePacketAndFlush(uint8_t command, const uint8_t* packet, uint16_t length);
static uint8_t readResult();
static uint32_t deviceUnplugged(register struct Hook *hook __asm("a0"), register APTR object __asm("a2"), register APTR message __asm("a1"));
typedef ULONG (*HOOKFUNC_ULONG)();  // NDK typedef HOOKFUNC with 'unsigned long'
static const struct Hook hook = { .h_Entry = (HOOKFUNC_ULONG)deviceUnplugged };

uint8_t usbsid_init(register uint8_t latency __asm("d0"), register int8_t taskpri __asm("d1"))
{
    kprintf("usbsid_init\n");
    if (usb) {
        kprintf("usb != NULL\n");
        return usb != NULL;
    }

    struct Library* PsdBase;
    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {   
        kprintf("poseidon open fail\n");
        return FALSE;
    }

    usb = psdAllocVec(sizeof(struct USBSID_Pico));

    if (!usb)
    {
        kprintf("psdAllocVec fail\n");
        CloseLibrary(PsdBase);
        return FALSE;
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
        psdAddErrorMsg(RETURN_OK, "USBSID-Pico", "Time to rock some 8-bit!");
    }
    else
    {
        kprintf("failed to acquire hw\n"); 
        psdAddErrorMsg(RETURN_ERROR, "USBSID-Pico", "Failed to acquire ancient hardware!");
        usbsid_exit();
    }

    kprintf("return %ld\n", (int)(usb != NULL)); 
    return usb != NULL;
}

void usbsid_exit()
{
    kprintf("usbsid_exit\n");
    if (!usb) {
       kprintf("!usb\n");
       return;
    }
        
    if(usb->mainTask)
    {
        kprintf("reset SID\n");
        usbsid_reset();
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

uint8_t usbsid_read_reg(register uint8_t reg __asm("d0"))
{
    if (!(usb && !usb->deviceLost))
        return 0x00;

    // flush all recorded writes
    if (usb->pendingRecorded)
        usbsid_write_reg_playback();

    usb->ctrlTask = FindTask(NULL);

    uint8_t buf[] = { reg, 0x00 };
    writePacketAndFlush(SID_READ, buf, sizeof(buf));

    Signal(usb->mainTask, SIGBREAKF_CTRL_D);
    Wait(SIGBREAKF_CTRL_D);
    usb->ctrlTask = NULL;

    return readResult();
}

void usbsid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
    if (!(usb && !usb->deviceLost))
        return;

    // flush all recorded writes
    if (usb->pendingRecorded)
        usbsid_write_reg_playback();

    uint8_t buf[] = { reg, value };
    writePacket(SID_WRITE, buf, sizeof(buf));
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);
}

void usbsid_write_reg_record(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
    if (!usb)
        return;

    if (usb->pendingRecorded > sizeof(usb->dataRecorded) - 2)
        return;

    uint8_t* p = &usb->dataRecorded[usb->pendingRecorded];

    *p++ = reg;
    *p++ = value;

    usb->pendingRecorded += 2;
}

void usbsid_write_reg_playback()
{
    if (!(usb && !usb->deviceLost))
        return;

    if (!usb->pendingRecorded)
        return;

    writePacket(SID_WRITE, usb->dataRecorded, usb->pendingRecorded);
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);
    usb->pendingRecorded = 0;
}

void usbsid_reset()
{
    if (!(usb && !usb->deviceLost))
        return;

    // flush all recorded writes
    if (usb->pendingRecorded)
        usbsid_write_reg_playback();

    if (1)
    {
        uint8_t buf[] = { 1 /* reset_sid_registers */, 0, 0, 0, 0 };
        writePacketAndFlush(SID_COMMAND | SID_RESET_SID, buf, sizeof(buf));
    }

    for (uint16_t sid = 0xd400; sid <= 0xd420; sid += 0x20)
    {
        uint8_t offset = (uint8_t)(sid & 0xff);

        for (uint8_t reg = 0x00; reg < 0x1d; reg += 0x01)
            usbsid_write_reg_record(offset + reg, 0x00);

        usbsid_write_reg_playback();
    }
}

void usbsid_set_num_sids(register uint8_t num_sids __asm("d0"))
{
    if (!(usb && !usb->deviceLost))
        return;

    if (num_sids == 1)
    {
        kprintf("** 1SID\n");
        uint8_t buf[] = { SID_MIRRORED_SID, 1 /* override temporarily */, 0, 0, 0 };
        writePacketAndFlush(SID_COMMAND | SID_CONFIG, buf, sizeof(buf));
    }
    else
    {
        kprintf("** 2/3SID\n");
        uint8_t buf[] = { SID_RELOAD_CONFIG, 0, 0, 0, 0 };
        writePacketAndFlush(SID_COMMAND | SID_CONFIG, buf, sizeof(buf));
    }
}

/*-------------------------------------------------------*/


#define PsdBase usb->psdLibrary

static uint8_t AllocSID(struct USBSID_Pico* usb);
static void FreeSID(struct USBSID_Pico* usb);

static void SIDTask()
{
    kprintf("SIDTask\n"); 

    struct Task* currentTask = FindTask(NULL);
    struct USBSID_Pico* usb = currentTask->tc_UserData;

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
                struct Task* flushTask = usb->flushTask;
                usb->flushTask = NULL;
                Enable();

                if (flushTask)
                {
                    kprintf("Signal flush (this = %08lx ; flush task = %08lx\n", FindTask(NULL), flushTask);
                    Signal(flushTask, SIGBREAKF_CTRL_F);
                }

                if (buffer->pending)
                {
                    uint8_t* p = buffer->data;
                    // kprintf("TX : ", buffer->pending);
                    // for (int16_t i = buffer->pending-1; i >= 0; --i)
                    //     kprintf("%02lx, ", *p++);
                    // kprintf("\n");

                    p = buffer->data;
                    while(buffer->pending)
                    {
                        const bool regRead = (*p == SID_READ);

                        // kprintf("%s(%02lx) : ", regRead ? "R" : "W", *p);

                        int16_t ret = -1;

                        uint8_t result[1];
                        if (regRead)
                            psdSendPipe(usb->inPipe, result, sizeof(result));

                        uint16_t length = buffer->pending;
                        if (length > MAX_PACKET_SIZE)
                            length = MAX_PACKET_SIZE;

                        if (*p == SID_WRITE)
                            *p = (*p & 0xc0) | ((length-1) & 0x3f);

                        kprintf("TX (%ld bytes) : ", length);
                        for (int16_t i = 0; i < length; i++)
                            kprintf("%02lx, ", p[i]);

                        // const uint16_t length = 3;
                        // kprintf("  | [%02lx] = %02lx\n", p[1], p[2]);

                        psdDoPipe(usb->outPipe, p, length);
                        p += length;
                        buffer->pending -= length;

                        if(buffer->pending)
                        {
                            kprintf(" + ");
                            p = &p[-1];         // move pointer back one byte ...
                            *p = SID_WRITE;     // so that we can insert the command again
                            buffer->pending++;  // ... and adjust the size
                        }
                        kprintf("\n");

                        if (regRead)
                        {
                            do
                            {
                                kprintf("psdWaitPipe .. ");
                                uint32_t ioerr = psdWaitPipe(usb->inPipe);
                                uint32_t actual = psdGetPipeActual(usb->inPipe);
                                kprintf("ioerr = %08lx ; actual = %08lx\n", ioerr, actual);

                                if(ioerr)
                                {
                                    kprintf("psdSendPipe(IN) failed! ioerr = %08lx ; actual = %ld\n", ioerr, actual);
                                    break;
                                }
                                else
                                {
                                    if (actual > 0)
                                    {
                                        ret = result[0];
                                        kprintf("RX : %02lx\n", ret);
                                        break;
                                    }
                                    kprintf("zero bytes; timed out?\n");
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

static uint8_t AllocSID(struct USBSID_Pico* usb)
{
    kprintf("AllocSID\n"); 

    // Find USBSID-Pico
    {
        kprintf("psdLocReadPBase\n"); 
        psdLockReadPBase();

        APTR pab = NULL;

        APTR pd = NULL;
        while(pd = psdFindDevice(pd, 
                                DA_VendorID, 0xcafe,
                                DA_ProductID, 0x4011,
                                DA_ProductName, (ULONG)"USBSID-Pico",
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

            struct PsdInterface* interface = NULL;
            while(interface = psdFindInterface(pd, interface, TAG_END))
            {
                psdGetAttrs(PGA_INTERFACE, interface,
                            IFA_Binding, (ULONG)&pab,
                            TAG_END);

                if (pab)
                {
                    kprintf("found interface binding. releasing..\n");
                    psdReleaseIfBinding(interface);
                }
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

    {
        kprintf("CDCCTRL_CLASSCODE / CDC_ACM_SUBCLASS\n");      
        struct PsdPipe* ep0pipe = psdAllocPipe(usb->device, usb->msgPort, NULL);
        if (!ep0pipe)
        {
            kprintf("!ep0pipe, return FALSE\n");
            return FALSE;
        }

#define ACM_CTRL_DTR   0x01
#define ACM_CTRL_RTS   0x02

        psdPipeSetup(ep0pipe, URTF_CLASS|URTF_INTERFACE, UCDCR_SET_CONTROL_LINE_STATE, ACM_CTRL_DTR | ACM_CTRL_RTS, 0x00);
        if (psdDoPipe(ep0pipe, NULL, 0))
        {
            kprintf("UCDCR_SET_CONTROL_LINE_STATE error\n");
        }

        // unsigned char encoding[] = { 0x40, 0x54, 0x89, 0x00, 0x00, 0x00, 0x08 };
        struct UsbCDCLineCoding lineCoding = { .dwDTERate = 0x40548900 /*little endian*/, .bCharFormat = 0, .bParityType = 0, .bDataBits = 8 };

        psdPipeSetup(ep0pipe, URTF_CLASS|URTF_INTERFACE, UCDCR_SET_LINE_CODING, 0, 0x00);
        if (psdDoPipe(ep0pipe, &lineCoding, sizeof(struct UsbCDCLineCoding)))
        {
            kprintf("UCDCR_SET_CONTROL_LINE_STATE error\n");
        }

        psdFreePipe(ep0pipe);
    }

    // Allocate in/out pipes
    {
        kprintf("CDCDATA_CLASSCODE\n");      
        struct PsdInterface* interface = psdFindInterface(usb->device, NULL, 
                                                IFA_Class, CDCDATA_CLASSCODE,
                                                TAG_END);
        if (!interface)
        {
            kprintf("!interface, return FALSE\n");             
            return FALSE;
        }

        struct PsdEndpoint* epIn = psdFindEndpoint(interface, NULL,
                                                   EA_IsIn, TRUE,
                                                   EA_TransferType, USEAF_BULK,
                                                   TAG_END);
        if (!epIn)
        {
            kprintf("!epIn, return FALSE\n");             
            return FALSE;
        }

        struct PsdEndpoint* epOut = psdFindEndpoint(interface, NULL,
                                                   EA_IsIn, FALSE,
                                                   EA_TransferType, USEAF_BULK,
                                                   TAG_END);
        if (!epOut)
        {
            kprintf("!epOut, return FALSE\n");             
            return FALSE;
        }

        if (!(usb->inPipe = psdAllocPipe(usb->device, usb->msgPort, epIn)))
        {
            kprintf("!inPipe, return FALSE\n");             
            return FALSE;
        }
        if (!(usb->outPipe = psdAllocPipe(usb->device, usb->msgPort, epOut)))
        {
            kprintf("!outPipe, return FALSE\n");             
            return FALSE;
        }

        psdSetAttrs(PGA_PIPE, usb->outPipe,
                    PPA_NakTimeout, TRUE,
                    PPA_NakTimeoutTime, 100,
                    TAG_END);

        psdSetAttrs(PGA_PIPE, usb->inPipe,
                    PPA_NakTimeout, TRUE,
                    PPA_NakTimeoutTime, 100,
                    TAG_END);

        // uint8_t dummy;
        // psdDoPipe(usb->inPipe, &dummy, 1);

    }

    return TRUE;
}

static void FreeSID(struct USBSID_Pico* usb)
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
    struct USBSID_Pico* usb = (struct USBSID_Pico*)message;

    usb->deviceLost = TRUE;

    if (usb->outPipe)
        psdAbortPipe(usb->outPipe);
    if (usb->inPipe)
        psdAbortPipe(usb->inPipe);

    Forbid();
    if(usb->mainTask)
    {
        Signal(usb->mainTask, SIGBREAKF_CTRL_C);

        psdAddErrorMsg(RETURN_OK, "USBSID-Pico", "End of an era");
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


static bool writePacket(uint8_t command, const uint8_t* packet, uint16_t length)
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

        uint16_t pending = buffer->pending;

        if (pending && *buffer->data != command)
        {
            // the command changed; wait until previous data is flushed
            ENABLE(SysBase);
            kprintf("Command mismatch!\n");
            SysBase->SysFlags |= 0x8000; // trigger reschedule
            return false;
        }

        uint8_t* dest = &buffer->data[pending];

        if (pending == 0)
        {
            *dest++ = command;
            pending++;
        }

        for (int16_t i = length-1; i >= 0; --i)
            *dest++ =  *packet++;
        buffer->pending = pending + length;

        ENABLE(SysBase);
        break;
    }
    return true;
}

static void flushStream()
{
#ifndef kprintf
    { struct Task* this = FindTask(NULL); kprintf("flushStream   (this = %08lx, '%s')\n", this, this->tc_Node.ln_Name ? this->tc_Node.ln_Name : "<noname>"); }
#endif
    usb->flushTask = FindTask(NULL);
    SetSignal(0, SIGBREAKF_CTRL_F);
    Signal(usb->mainTask, SIGBREAKF_CTRL_D);
    Wait(SIGBREAKF_CTRL_F);
    usb->flushTask = NULL;
}

static void writePacketAndFlush(uint8_t command, const uint8_t* packet, uint16_t length)
{
    // keep retrying to write packet
    while(!writePacket(command, packet, length))
        flushStream();

    // make sure it's been picked up
    flushStream();
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
   __asm volatile("move.w #3546895/115200,0xdff032": : : "cc", "memory");

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
