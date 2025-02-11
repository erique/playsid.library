#pragma once

#define OM_SIDBLASTER_USB (4)
#define OM_USBSID_PICO    (6)

#define SID_NOSIDBLASTER (-12)
#define SID_NOUSBSIDPICO (-14)

uint8_t sid_init(register uint8_t operating_mode __asm("d0"), register uint8_t latency __asm("d1"), register int8_t taskpri __asm("d2"));
void    sid_exit();
uint8_t sid_read_reg(register uint8_t reg __asm("d0"));
void    sid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
void    sid_write_reg_record(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
void    sid_write_reg_playback();
void    sid_reset();
void	sid_set_num_sids(register uint8_t num_sids __asm("d0"));
