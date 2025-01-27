#include <stdio.h>
#include <stdlib.h>
#include <proto/exec.h>
#include <proto/timer.h>
#include <proto/poseidon.h>
#include <string.h>

#include "sid.h"
#include "git.gen.h"

uint32_t timeout = 10;  // seconds
uint32_t latency = 16;  // milliseconds
int32_t  taskpri = 20;  // exec task priority (-128 .. 127)

struct Device* TimerBase;

int main(int argc, const char** argv)
{
    if (argc > 1)
        timeout = strtol(argv[1], 0, 10);
    if (argc > 2)
        latency = strtol(argv[2], 0, 10);
    if (argc > 3)
        taskpri = strtol(argv[3], 0, 10);

    printf("%s (git:%s) <timeout:%d> <latency:%d> <taskpri:%d>\n", argv[0], GIT, timeout, latency, taskpri);

    if (timeout > 1000)
    {
        printf("timeout > 1000 doesn't make much sense\n");
        return FALSE;
    }
    else if (latency > 255)
    {
        printf("latency > 255 is not possible\n");
        return FALSE;
    }
    else if (taskpri > 127 || taskpri <-128)
    {
        printf("taskpri is [-128,127]\n");
        return FALSE;
    }

    if (sid_init(OM_USBSID_PICO, latency, taskpri))
    {
        printf("sid init failed\n");
        return -1;
    }

    struct Library* PsdBase;
    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {
        printf("OpenLibrary(\"poseidon.library\") failed\n");
        return FALSE;
    }

    struct MsgPort timerPort = { 0 };
    struct timerequest timerRequest = { 0 };
    timerRequest.tr_node.io_Message.mn_ReplyPort = &timerPort;
    if (OpenDevice(TIMERNAME, UNIT_VBLANK, &timerRequest.tr_node, 0))
    {
        printf("OpenDevice(\"%s\") failed\n", TIMERNAME);
        CloseLibrary(PsdBase);
        return FALSE;
    }

    TimerBase = (struct Device*)timerRequest.tr_node.io_Device;

    struct timeval startTime, currentTime;

    GetSysTime(&startTime);

    for (int i = 0x00; i <= 0x1c; ++i)
        sid_write_reg_record(i, 0x00);
    sid_write_reg_playback();

    // voice 1
    sid_write_reg(0x00, 0x04);      // freq lo
    sid_write_reg(0x01, 0x04);      // freq hi
    sid_write_reg(0x02, 0xff);      // pulse width lo
    sid_write_reg(0x03, 0x07);      // pulse width hi
    sid_write_reg(0x05, 0x00);      // attack  | decay
    sid_write_reg(0x06, 0xf0);      // sustain | release

    // voice 2
    sid_write_reg(0x00+7, 0x10);    // freq lo
    sid_write_reg(0x01+7, 0x04);    // freq hi
    sid_write_reg(0x02+7, 0xff);    // pulse width lo
    sid_write_reg(0x03+7, 0x07);    // pulse width hi
    sid_write_reg(0x05+7, 0x00);    // attack  | decay
    sid_write_reg(0x06+7, 0xf0);    // sustain | release

    // voice 3
    sid_write_reg(0x00+7*2, 0x0a);  // freq lo
    sid_write_reg(0x01+7*2, 0x00);  // freq hi
    sid_write_reg(0x02+7*2, 0xff);  // pulse width lo
    sid_write_reg(0x03+7*2, 0x07);  // pulse width hi
    sid_write_reg(0x05+7*2, 0x00);  // attack  | decay
    sid_write_reg(0x06+7*2, 0xf0);  // sustain | release

    sid_write_reg(0x15, 0x00);      // filter cut-off lo
    sid_write_reg(0x16, 0x00);      // filter cut-off hi

    sid_write_reg(0x17, 0x83);      // resonance   | filter control
    sid_write_reg(0x18, 0x1f);      // filter mode | volume 

    printf("sweeping...\n"); fflush(stdout);

    // gate 1+2+3
    sid_write_reg_record(0x04, 0x41);      // square | gate
    sid_write_reg_record(0x04+7, 0x41);    // square | gate
    sid_write_reg_record(0x04+7*2, 0x11);  // triang | gate
    sid_write_reg_playback();

    while(1)
    {
        GetSysTime(&currentTime);
        SubTime(&currentTime, &startTime);

        if (currentTime.tv_secs >= timeout)
            break;

        printf("time = %d.%d ; ", currentTime.tv_secs, currentTime.tv_micro);

        psdDelayMS(20);

        // read voice 3 oscillator and use it to sweep the filter cut-off
        uint8_t voice3osc = sid_read_reg(0x1b);

        printf("voice3osc %2x", voice3osc);

        uint8_t cutoff_lo = voice3osc & 0xf;
        uint8_t cutoff_hi = voice3osc >> 3;

        sid_write_reg_record(0x15, cutoff_lo);
        sid_write_reg_record(0x16, cutoff_hi);

        // use time as input to the pulse width phasing
        uint16_t phase = (currentTime.tv_secs << 8) | (currentTime.tv_micro >> 12);

        uint8_t phase_lo = phase & 0xff;
        uint8_t phase_hi = phase >> 8;

        sid_write_reg_record(0x02, phase_lo);
        sid_write_reg_record(0x03, phase_hi);

        phase += 0xff;        // offset voice 1 phase slightly
        phase_lo = phase & 0xff;
        phase_hi = phase >> 8;

        sid_write_reg_record(0x02+7, phase_lo);
        sid_write_reg_record(0x03+7, phase_hi);

        sid_write_reg_playback();

        printf("\n"); fflush(stdout);
    }

    // reset all registers
    for (int i = 0x00; i <= 0x1c; ++i)
        sid_write_reg_record(i, 0x00);
    sid_write_reg_playback();

    CloseLibrary(PsdBase);

    sid_exit();
    return 0;
}
