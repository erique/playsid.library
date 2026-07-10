#pragma once

uint8_t usbsid_init(register uint8_t latency __asm("d0"), register int8_t taskpri __asm("d1"));
void    usbsid_exit();
uint8_t usbsid_read_reg(register uint8_t reg __asm("d0"));
void    usbsid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
void    usbsid_write_reg_record(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
void    usbsid_write_reg_playback();
void    usbsid_reset();
void	usbsid_set_num_sids(register uint8_t num_sids __asm("d0"));

// Onboard SID player (requires firmware built with ONBOARD_SIDPLAYER, "_sp" builds)
uint8_t usbsid_upload(register const uint8_t* header __asm("a0"), register uint16_t headerSize __asm("d0"), register const uint8_t* data __asm("a1"), register uint32_t dataSize __asm("d1"));
void    usbsid_player_tune(register uint8_t subtune __asm("d0"));
void    usbsid_player_stop();
void    usbsid_player_pause();
