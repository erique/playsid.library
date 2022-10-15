
*=======================================================================*
*                                                                       *
*       C64 MUSIC EMULATOR FOR AMIGA                                    *
*       (C) 1990-1994 HÅKAN SUNDELL & RON BIRK                          *
*                                                                       *
*=======================================================================*

This version of playsid.library provides three different sound
output methods:

- The original SID emulation by Per Sundell & Ron Birk
- The reSID emulation engine by Dag Lem, ported to assembler
- SIDBlaster-USB, a device that uses an actual SID chip for sound

To use, copy "playsid.library" to LIBS:, replacing the original
version. By default it will use the original SID emulation mode.

To select the output mode, set the environment variable "PlaySIDMode":
0 = Original
1 = reSID 6581
2 = reSID 8580
3 = SIDBlaster USB

Applications using "playsid.library" will automatically be enhanced.
These are at least HippoPlayer and DeliTracker. HippoPlayer
also provides additional integration: output mode selection, 
volume setting, scope display.

reSID
-----

reSID provides accurate, cycle exact emulation of both the 6581 
and the 8580 SID chips, with filter support. It is the
ultimate SID emulator.

Note 1: reSID is very heavy on the CPU. I measured
CPU usage of 50-80% on my A1200/060, depending on the tune.
Your system may become unresponsive if it's not powerful enough.
An FPU is not required. A 68040 will probably not be fast enough.

Note 2: Samples will not be heard. This is because the
samples have typically had some special handling in
SID players and emulators. The playsid.library sample handling 
is not used with reSID.

Note 3: Sometimes the sound output may be noisy. This is
sampling noise, result of the reSID "fast sampling" method.
Unfortunately the better quality sampling options available 
in reSID are too slow for a 50 MHz 68060.

reSID assembler port and integration: K-P Koljonen


SIDBlaster
----------

SIDBlaster integration uses the Poseidon USB stack. 
poseidon.library is needed.

TODO

SIDBlaster integration: Eriq
