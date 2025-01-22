#include "libusb.h"

#if 0 // NDEBUG
#define kprintf(...) do {} while(0)
#else
int kprintf(const char* format, ...);
#endif

// #include <stdio.h>
// #include <stdlib.h>
// #include <stdint.h>
#include <stdarg.h>
// #include <stdbool.h>
#include <proto/exec.h>
#include <exec/types.h>
// #include <exec/execbase.h>
// #include <utility/hooks.h>
#include <inline/poseidon.h>
#include <libraries/poseidon.h>

struct libusb_context
{
    struct Library* psdLibrary;
};

struct libusb_device_handle
{
    libusb_context*     context;
    struct PsdDevice*   device;
    struct MsgPort*     msgPort;
};

int LIBUSB_CALL libusb_init(libusb_context **ctx)
{
    struct Library* PsdBase = NULL;
    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {   
        kprintf("poseidon open fail\n");
        return LIBUSB_ERROR_OTHER;
    }

    libusb_context* context = psdAllocVec(sizeof(struct libusb_context));

    if (!context)
    {
        kprintf("psdAllocVec fail\n");
        CloseLibrary(PsdBase);
        return LIBUSB_ERROR_NO_MEM;
    }

    context->psdLibrary = PsdBase;
    *ctx = context;
    return LIBUSB_SUCCESS;
}
void LIBUSB_CALL libusb_exit(libusb_context *ctx)
{
    struct Library* PsdBase = ctx->psdLibrary;
    psdFreeVec(ctx);
    CloseLibrary(PsdBase);
    PsdBase = NULL;
}


libusb_device_handle * LIBUSB_CALL libusb_open_device_with_vid_pid(libusb_context *ctx, uint16_t vendor_id, uint16_t product_id)
{
    struct Library* PsdBase = ctx->psdLibrary;

    kprintf("psdLocReadPBase\n");
    psdLockReadPBase();

    APTR pab = NULL;

    APTR pd = NULL;
    while(pd = psdFindDevice(pd, 
                            DA_VendorID, vendor_id,
                            DA_ProductID, product_id,
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
            
        // pab = psdClaimAppBinding(ABA_Device, (ULONG)pd,
        //                     ABA_ReleaseHook, (ULONG)&hook,
        //                     ABA_UserData, (ULONG)usb);

        // kprintf("psdClaimAppBinding pab=%lx\n", (int)pab); 

        psdUnlockDevice(pd);

        if (pd) 
            break;
    }

    psdUnlockPBase();

    if (!pd) {
        kprintf("!pd, return FALSE\n"); 
        return NULL;
    }

    libusb_device_handle* dev_handle = psdAllocVec(sizeof(struct libusb_device_handle));

    if (!dev_handle)
    {
        kprintf("psdAllocVec fail\n");
        return 0;
    }

    struct MsgPort* msgPort = CreateMsgPort();
    if (!msgPort)
    {
        kprintf("CreateMsgPort fail\n");
        return NULL;
    }

    dev_handle->context = ctx;
    dev_handle->device = pd;
    dev_handle->msgPort = msgPort;

    return dev_handle;
}

void LIBUSB_CALL libusb_close(libusb_device_handle *dev_handle)
{
    struct Library* PsdBase = dev_handle->context->psdLibrary;
    DeleteMsgPort(dev_handle->msgPort);
    psdFreeVec(dev_handle);
}


int LIBUSB_CALL libusb_kernel_driver_active(libusb_device_handle *dev_handle, int interface_number)
{
    kprintf("libusb_kernel_driver_active\n");
    return 0;
}

int LIBUSB_CALL libusb_detach_kernel_driver(libusb_device_handle *dev_handle, int interface_number)
{
    kprintf("libusb_detach_kernel_driver\n");
    return 0;
}


int LIBUSB_CALL libusb_control_transfer(libusb_device_handle *dev_handle, uint8_t request_type, uint8_t bRequest, uint16_t wValue, uint16_t wIndex, unsigned char *data, uint16_t wLength, unsigned int timeout)
{
    kprintf("libusb_control_transfer\n");

    struct Library* PsdBase = dev_handle->context->psdLibrary;

    struct PsdPipe* ep0pipe = psdAllocPipe(dev_handle->device, dev_handle->msgPort, NULL);
    if (!ep0pipe)
    {
        kprintf("!ep0pipe, return FALSE\n");
        return LIBUSB_ERROR_IO;
    }

    if (timeout)
    {
        psdSetAttrs(PGA_PIPE, ep0pipe,
                    PPA_NakTimeout, TRUE,
                    PPA_NakTimeoutTime, timeout,
                    TAG_END);
    }

    psdPipeSetup(ep0pipe, request_type, bRequest, wValue, wIndex);
    if (psdDoPipe(ep0pipe, data, wLength))
    {
        kprintf("psdDoPipe FAILED\n");
    }

    int actual = psdGetPipeActual(ep0pipe);
    kprintf("actual = 0x%08lx\n", actual);

    psdFreePipe(ep0pipe);
    return actual;
}

int LIBUSB_CALL libusb_bulk_transfer(libusb_device_handle *dev_handle, unsigned char endpoint, unsigned char *data, int length, int *actual_length, unsigned int timeout)
{
//    kprintf("libusb_bulk_transfer\n");

    struct Library* PsdBase = dev_handle->context->psdLibrary;

    ULONG dirIn = (URTF_IN & endpoint) ? TRUE : FALSE;
    endpoint &= ~URTF_IN;

    struct PsdInterface* interface = NULL;
    struct PsdPipe* pipe = NULL;
    while(interface = psdFindInterface(dev_handle->device, interface, TAG_END))
    {
        // kprintf("interface = %08lx\n", interface);

        // ULONG interfaceNum, numEps;
        // char* interfaceName;
        // struct List *eps;
        // psdGetAttrs(PGA_INTERFACE, interface,
        //     IFA_InterfaceNum, (ULONG)&interfaceNum,
        //     IFA_InterfaceName, (ULONG)&interfaceName,
        //     IFA_NumEndpoints, (ULONG)&numEps,
        //     IFA_EndpointList, (ULONG)&eps,
        //     TAG_END);

        // kprintf("%ld : %s (%ld endpoints)\n", interfaceNum, interfaceName, numEps);
        // for (struct Node* ep = eps->lh_Head; ep->ln_Succ; ep = ep->ln_Succ)
        // {
        //     ULONG episin;
        //     ULONG epnum;
        //     ULONG eptranstype;
        //     ULONG epmaxpktsize;
        //     ULONG epinterval;
        //     ULONG epsynctype;
        //     ULONG epusagetype;

        //     psdGetAttrs(PGA_ENDPOINT, ep,
        //                 EA_IsIn, (ULONG)&episin,
        //                 EA_EndpointNum, (ULONG)&epnum,
        //                 EA_TransferType, (ULONG)&eptranstype,
        //                 EA_MaxPktSize, (ULONG)&epmaxpktsize,
        //                 TAG_END);

        //     kprintf("      · Endpoint %ld (%s %s)\n"
        //             "        MaxPktSize: %ld\n",
        //             epnum, psdNumToStr(NTS_TRANSTYPE, eptranstype, "?"),
        //             episin ? "<-[ IN" : "OUT ]->",
        //             epmaxpktsize);

        // }

        struct PsdEndpoint* ep = psdFindEndpoint(interface, NULL,
                                                   EA_EndpointNum, endpoint,
                                                   EA_IsIn, dirIn,
                                                   EA_TransferType, USEAF_BULK,
                                                   TAG_END);
        
        if (!ep)
        {
            // kprintf("no ep here\n");
            continue;
        }

        if (pipe = psdAllocPipe(dev_handle->device, dev_handle->msgPort, ep))
        {
            // kprintf("pipe alloc'd\n");            
            break;
        }

        kprintf("pipe failed?\n");
    }

    if (!pipe)
    {
        kprintf("endpoint not found\n");
        return LIBUSB_ERROR_NOT_FOUND;
    }

    if (timeout)
    {
        psdSetAttrs(PGA_PIPE, pipe,
                    PPA_NakTimeout, TRUE,
                    PPA_NakTimeoutTime, timeout,
                    TAG_END);
    }

    if (psdDoPipe(pipe, data, length))
    {
        kprintf("bulk dopipe erroor\n");
    }

    if (actual_length)
    {
        *actual_length = psdGetPipeActual(pipe);
        // ULONG actual = 0;
        // if (1 != psdGetAttrs(PGA_PIPE, pipe, PPA_Actual, &actual))
        // {
        //     kprintf("PPA_Actual FAILED\n");
        // }
        // *actual_length = actual;
    }

    psdFreePipe(pipe);

    return LIBUSB_SUCCESS;
}

int LIBUSB_CALL libusb_claim_interface(libusb_device_handle *dev_handle, int interface_number)
{
    kprintf("libusb_claim_interface\n");
    return LIBUSB_SUCCESS;  
}
int LIBUSB_CALL libusb_release_interface(libusb_device_handle *dev_handle, int interface_number)
{
    kprintf("libusb_release_interface\n");
    return LIBUSB_SUCCESS;  
}

const char * LIBUSB_CALL libusb_error_name(int errcode)
{
    return "LIBUSB_SUCCESS";
}
const char * LIBUSB_CALL libusb_strerror(int errcode)
{
    return "No error";
}

int LIBUSB_CALL libusb_set_option(libusb_context *ctx, enum libusb_option option, ...)
{
    kprintf("libusb_set_option\n");
    return 0;
}

// %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#ifndef kprintf

#define RawPutChar(___ch) \
    LP1NR(516, RawPutChar , BYTE, ___ch, d0,\
          , EXEC_BASE_NAME)

static void raw_put_char(uint32_t c __asm("d0"))
{
    RawPutChar(c);
}

int kvprintf(const char* format, va_list ap)
{
//    __asm volatile("move.w #3546895/115200,0xdff032": : : "cc", "memory");

    RawDoFmt((STRPTR)format, ap, (__fpt)raw_put_char, NULL);
    return 0;
}

int kprintf(const char* format, ...)
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
