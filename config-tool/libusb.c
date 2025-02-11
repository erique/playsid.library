#include "libusb.h"

#include <stdio.h>
#include <stdarg.h>
#include <proto/exec.h>
#include <exec/types.h>
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
        fprintf(stderr, "<libusb> Poseidon open failed\n");
        return LIBUSB_ERROR_OTHER;
    }

    libusb_context* context = psdAllocVec(sizeof(struct libusb_context));

    if (!context)
    {
        fprintf(stderr, "<libusb> psdAllocVec failed\n");
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

    psdLockReadPBase();

    APTR pd = NULL;

    while(pd = psdFindDevice(pd, 
                            DA_VendorID, vendor_id,
                            DA_ProductID, product_id,
                            TAG_END))
    {
        psdLockReadDevice(pd);

        const char* product;
        const char* manufacturer;
        psdGetAttrs(PGA_DEVICE, pd,
                    DA_ProductName, (ULONG)&product,
                    DA_Manufacturer, (ULONG)&manufacturer,
                    TAG_END);

        fprintf(stderr, "<libusb> Device = '%s / %s'\n", product ? product : "<?>", 
                                                manufacturer ? manufacturer : "<?>");

        psdUnlockDevice(pd);

        if (pd) 
            break;
    }

    psdUnlockPBase();

    if (!pd) {
        fprintf(stderr, "<libusb> Device %04x:%04x not found\n", vendor_id, product_id); 
        return NULL;
    }

    libusb_device_handle* dev_handle = psdAllocVec(sizeof(struct libusb_device_handle));

    if (!dev_handle)
    {
        fprintf(stderr, "<libusb> psdAllocVec failed\n");
        return 0;
    }

    struct MsgPort* msgPort = CreateMsgPort();
    if (!msgPort)
    {
        fprintf(stderr, "<libusb> CreateMsgPort failed\n");
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
    return 0;
}

int LIBUSB_CALL libusb_detach_kernel_driver(libusb_device_handle *dev_handle, int interface_number)
{
    return 0;
}


int LIBUSB_CALL libusb_control_transfer(libusb_device_handle *dev_handle, uint8_t request_type, uint8_t bRequest, uint16_t wValue, uint16_t wIndex, unsigned char *data, uint16_t wLength, unsigned int timeout)
{
    struct Library* PsdBase = dev_handle->context->psdLibrary;

    struct PsdPipe* ep0pipe = psdAllocPipe(dev_handle->device, dev_handle->msgPort, NULL);
    if (!ep0pipe)
    {
        fprintf(stderr, "<libusb> Unable to alloc control pipe.\n");
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
    psdDoPipe(ep0pipe, data, wLength);

    int actual = psdGetPipeActual(ep0pipe);

    psdFreePipe(ep0pipe);
    return actual;
}

int LIBUSB_CALL libusb_bulk_transfer(libusb_device_handle *dev_handle, unsigned char endpoint, unsigned char *data, int length, int *actual_length, unsigned int timeout)
{
    struct Library* PsdBase = dev_handle->context->psdLibrary;

    ULONG dirIn = (URTF_IN & endpoint) ? TRUE : FALSE;
    endpoint &= ~URTF_IN;

    struct PsdInterface* interface = NULL;
    struct PsdPipe* pipe = NULL;
    while(interface = psdFindInterface(dev_handle->device, interface, TAG_END))
    {
        struct PsdEndpoint* ep = psdFindEndpoint(interface, NULL,
                                                   EA_EndpointNum, endpoint,
                                                   EA_IsIn, dirIn,
                                                   EA_TransferType, USEAF_BULK,
                                                   TAG_END);
        
        if (!ep)
        {
            continue;
        }

        if (pipe = psdAllocPipe(dev_handle->device, dev_handle->msgPort, ep))
        {
            break;
        }

        fprintf(stderr, "<libusb> Failed to allocate bulk pipe\n");
    }

    if (!pipe)
    {
        fprintf(stderr, "<libusb> Endpoint not found\n");
        return LIBUSB_ERROR_NOT_FOUND;
    }

    if (timeout)
    {
        psdSetAttrs(PGA_PIPE, pipe,
                    PPA_NakTimeout, TRUE,
                    PPA_NakTimeoutTime, timeout,
                    TAG_END);
    }

    if (length && psdDoPipe(pipe, data, length))
    {
        fprintf(stderr, "<libusb> psdDoPipe bulk transfer failed length = 0x%08x (%s)\n", length, dirIn ? "IN" : "OUT");
    }

    int actual = psdGetPipeActual(pipe);

    if (actual_length)
        *actual_length = actual;

    psdFreePipe(pipe);

    return LIBUSB_SUCCESS;
}

int LIBUSB_CALL libusb_claim_interface(libusb_device_handle *dev_handle, int interface_number)
{
    return LIBUSB_SUCCESS;  
}
int LIBUSB_CALL libusb_release_interface(libusb_device_handle *dev_handle, int interface_number)
{
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
    return 0;
}
