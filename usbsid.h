#pragma once

uint8_t usbsid_init(register uint8_t latency __asm("d0"), register int8_t taskpri __asm("d1"));
void    usbsid_exit();
uint8_t usbsid_read_reg(register uint8_t reg __asm("d0"));
void    usbsid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
void    usbsid_write_reg_record(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
void    usbsid_write_reg_playback();
void    usbsid_reset();
