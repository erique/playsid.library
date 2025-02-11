#include <stdint.h>

#include "sid.h"
#include "sidblast.h"
#include "usbsid.h"

static uint8_t backend = 0;

uint8_t sid_init(register uint8_t operating_mode __asm("d0"), register uint8_t latency __asm("d1"), register int8_t taskpri __asm("d2"))
{
	switch (operating_mode)
	{
		case OM_SIDBLASTER_USB:
			if (!sidblaster_init(latency, taskpri))
				return SID_NOSIDBLASTER;
			break;

		case OM_USBSID_PICO:
			if (!usbsid_init(latency, taskpri))
				return SID_NOUSBSIDPICO;
			break;
		
	}
	backend = operating_mode;
	return 0; // a-ok
}

void sid_exit()
{
	sidblaster_exit();
	usbsid_exit();
	backend = 0;
}

uint8_t sid_read_reg(register uint8_t reg __asm("d0"))
{
	if (backend == OM_SIDBLASTER_USB)
		return sidblaster_read_reg(reg);
	if (backend == OM_USBSID_PICO)
		return usbsid_read_reg(reg);
	return 0;
}

void sid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
	if (backend == OM_SIDBLASTER_USB)
		return sidblaster_write_reg(reg, value);
	if (backend == OM_USBSID_PICO)
		return usbsid_write_reg(reg, value);
}

void sid_write_reg_record(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"))
{
	if (backend == OM_SIDBLASTER_USB)
		return sidblaster_write_reg_record(reg, value);
	if (backend == OM_USBSID_PICO)
		return usbsid_write_reg_record(reg, value);
}

void sid_write_reg_playback()
{
	if (backend == OM_SIDBLASTER_USB)
		return sidblaster_write_reg_playback();
	if (backend == OM_USBSID_PICO)
		return usbsid_write_reg_playback();
}

void sid_reset()
{
	if (backend == OM_SIDBLASTER_USB)
		return sidblaster_reset();
	if (backend == OM_USBSID_PICO)
		return usbsid_reset();
}

void sid_set_num_sids(register uint8_t num_sids __asm("d0"))
{
	if (backend == OM_USBSID_PICO)
		return usbsid_set_num_sids(num_sids);
}
