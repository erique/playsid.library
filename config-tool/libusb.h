#pragma once

#include <stdint.h>


struct libusb_context;
struct libusb_device;
struct libusb_device_handle;

typedef struct libusb_context libusb_context;
typedef struct libusb_device libusb_device;
typedef struct libusb_device_handle libusb_device_handle;

// typedef struct libusb_context
// {

// } libusb_context ;

// #define LIBUSB_OPTION_LOG_LEVEL 10
// #define LIBUSB_ERROR_TIMEOUT 5

enum libusb_option {
	/** Set the log message verbosity.
	 *
	 * The default level is LIBUSB_LOG_LEVEL_NONE, which means no messages are ever
	 * printed. If you choose to increase the message verbosity level, ensure
	 * that your application does not close the stderr file descriptor.
	 *
	 * You are advised to use level LIBUSB_LOG_LEVEL_WARNING. libusb is conservative
	 * with its message logging and most of the time, will only log messages that
	 * explain error conditions and other oddities. This will help you debug
	 * your software.
	 *
	 * If the LIBUSB_DEBUG environment variable was set when libusb was
	 * initialized, this function does nothing: the message verbosity is fixed
	 * to the value in the environment variable.
	 *
	 * If libusb was compiled without any message logging, this function does
	 * nothing: you'll never get any messages.
	 *
	 * If libusb was compiled with verbose debug message logging, this function
	 * does nothing: you'll always get messages from all levels.
	 */
	LIBUSB_OPTION_LOG_LEVEL = 0,

	/** Use the UsbDk backend for a specific context, if available.
	 *
	 * This option should be set immediately after calling libusb_init(), otherwise
	 * unspecified behavior may occur.
	 *
	 * Only valid on Windows.
	 */
	LIBUSB_OPTION_USE_USBDK = 1,

	/** Do not scan for devices
	 *
	 * With this option set, libusb will skip scanning devices in
	 * libusb_init(). Must be set before calling libusb_init().
	 *
	 * Hotplug functionality will also be deactivated.
	 *
	 * The option is useful in combination with libusb_wrap_sys_device(),
	 * which can access a device directly without prior device scanning.
	 *
	 * This is typically needed on Android, where access to USB devices
	 * is limited.
	 *
	 * For LIBUSB_API_VERSION 0x01000108 it was called LIBUSB_OPTION_WEAK_AUTHORITY
	 *
	 * Only valid on Linux.
	 */
	LIBUSB_OPTION_NO_DEVICE_DISCOVERY = 2,

#define LIBUSB_OPTION_WEAK_AUTHORITY LIBUSB_OPTION_NO_DEVICE_DISCOVERY

	LIBUSB_OPTION_MAX = 3
};

enum libusb_log_level {
	/** (0) : No messages ever emitted by the library (default) */
	LIBUSB_LOG_LEVEL_NONE = 0,

	/** (1) : Error messages are emitted */
	LIBUSB_LOG_LEVEL_ERROR = 1,

	/** (2) : Warning and error messages are emitted */
	LIBUSB_LOG_LEVEL_WARNING = 2,

	/** (3) : Informational, warning and error messages are emitted */
	LIBUSB_LOG_LEVEL_INFO = 3,

	/** (4) : All messages are emitted */
	LIBUSB_LOG_LEVEL_DEBUG = 4
};


enum libusb_error {
	/** Success (no error) */
	LIBUSB_SUCCESS = 0,

	/** Input/output error */
	LIBUSB_ERROR_IO = -1,

	/** Invalid parameter */
	LIBUSB_ERROR_INVALID_PARAM = -2,

	/** Access denied (insufficient permissions) */
	LIBUSB_ERROR_ACCESS = -3,

	/** No such device (it may have been disconnected) */
	LIBUSB_ERROR_NO_DEVICE = -4,

	/** Entity not found */
	LIBUSB_ERROR_NOT_FOUND = -5,

	/** Resource busy */
	LIBUSB_ERROR_BUSY = -6,

	/** Operation timed out */
	LIBUSB_ERROR_TIMEOUT = -7,

	/** Overflow */
	LIBUSB_ERROR_OVERFLOW = -8,

	/** Pipe error */
	LIBUSB_ERROR_PIPE = -9,

	/** System call interrupted (perhaps due to signal) */
	LIBUSB_ERROR_INTERRUPTED = -10,

	/** Insufficient memory */
	LIBUSB_ERROR_NO_MEM = -11,

	/** Operation not supported or unimplemented on this platform */
	LIBUSB_ERROR_NOT_SUPPORTED = -12,

	/* NB: Remember to update LIBUSB_ERROR_COUNT below as well as the
	   message strings in strerror.c when adding new error codes here. */

	/** Other error */
	LIBUSB_ERROR_OTHER = -99
};

#define LIBUSB_CALL

int LIBUSB_CALL libusb_init(libusb_context **ctx);
void LIBUSB_CALL libusb_exit(libusb_context *ctx);

libusb_device_handle * LIBUSB_CALL libusb_open_device_with_vid_pid(libusb_context *ctx, uint16_t vendor_id, uint16_t product_id);
void LIBUSB_CALL libusb_close(libusb_device_handle *dev_handle);

int LIBUSB_CALL libusb_kernel_driver_active(libusb_device_handle *dev_handle, int interface_number);
int LIBUSB_CALL libusb_detach_kernel_driver(libusb_device_handle *dev_handle, int interface_number);

int LIBUSB_CALL libusb_control_transfer(libusb_device_handle *dev_handle, uint8_t request_type, uint8_t bRequest, uint16_t wValue, uint16_t wIndex, unsigned char *data, uint16_t wLength, unsigned int timeout);
int LIBUSB_CALL libusb_bulk_transfer(libusb_device_handle *dev_handle, unsigned char endpoint, unsigned char *data, int length, int *actual_length, unsigned int timeout);

int LIBUSB_CALL libusb_claim_interface(libusb_device_handle *dev_handle, int interface_number);
int LIBUSB_CALL libusb_release_interface(libusb_device_handle *dev_handle, int interface_number);

const char * LIBUSB_CALL libusb_error_name(int errcode);
const char * LIBUSB_CALL libusb_strerror(int errcode);

int LIBUSB_CALL libusb_set_option(libusb_context *ctx, enum libusb_option option, ...);
