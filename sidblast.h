#pragma once

uint8_t sid_init();
void    sid_exit();
uint8_t sid_read_reg(register uint8_t reg __asm("d0"));
void    sid_write_reg(register uint8_t reg __asm("d0"), register uint8_t value __asm("d1"));
