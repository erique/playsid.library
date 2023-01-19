
*=======================================================================*
*                                                                       *
*       C64 MUSIC EMULATOR FOR AMIGA                                    *
*       (C) 1990-1994 HÅKAN SUNDELL & RON BIRK                          *
*                                                                       *
*=======================================================================*

This version of playsid.library provides three different sound
output methods:

- The original SID emulation by Per Sundell & Ron Birk
- The reSID emulation engine by Dag Lem
- SIDBlaster-USB, a device that uses a SID chip for sound

To use, copy "playsid.library" into LIBS:, replacing the original
version. By default it will use the original SID emulation mode.

To select the output mode, set the environment variable "PlaySIDMode"
to a number, eg. 'setenv PlaySIDMode 1', where the numbers are:
0 = Original
1 = reSID 6581
2 = reSID 8580
3 = SIDBlaster USB

Applications using "playsid.library" will automatically be enhanced.
These are at least: HippoPlayer, DeliTracker, Magic64, Frodo. 

HippoPlayer also provides additional integration in the user interface: output
mode selection, sampling mode, filter and volume setting, scope display. With
Hippo the environment variable setting is not used.

If you're running kickstart 1.3 or 68000 you should use the original 
library version.


reSID
-----

reSID provides an accurate, cycle exact emulation of both the 6581 
and the 8580 SID chips, with filter support. 

The emulated SID chip is updated at 200 Hz. This should allow double 
speed SID tunes to work acceptably, possibly also quad speed ones.
A normal SID tune is usually updated at 50 Hz, a double speed 
tune once at 100 Hz ms, and so forth.

Samples will not be heard. This is because the samples have typically 
had some special handling in SID players and emulators. The 
playsid.library sample handling is not usable with reSID.

reSID is very heavy on the CPU. I measured CPU usage of 50-80% on 
an A1200 with a 50MHz 68060, depending on the tune. An FPU is 
not required.

Sometimes the sound output may be noisy. This is sampling noise, 
result of the reSID "fast sampling" method. A few other sampling
modes are also available to reduce the noise. These are heavier and 
may not run on a 50 MHz 68060.

If the tune being played and/or the chosen sampling mode is too 
heavy, data will be skipped to avoid slowing down the system too much.
This will cause the sound to be distorted.

The filters can be enabled or disabled. The main filter is responsible
for the distinctive SID sound. The external filter does not have
much of an audible effect, it may reduce the sampling noise somewhat.

The sound is output using the Paula 14-bit mode.

reSID v0.16 Amiga port and integration by K-P


reSID related environment variables
-----------------------------------
'setenv PlaySIDDebug 1' will enable reSID raster bar CPU measurement visual, 0
will disable it.

'setenv PlaySIDRate <num>' will configure the reSID update rate. These
correspond to the "tune speeds": a SID tune has been composed using a certain
rate which it updates the SID registers. Faster rates allow for more complex
sounds.

Higher speed tunes need to be played with the same rate or higher to sound
correct. Most SID tunes are "single speed". There's also a 12-speed tune by
Jeff, called "12-speed_tune.sid". Using a higher rate will use more CPU than a
lower rate due to the increased amount of interrupts and other overhead.

1 = 100 Hz "double speed"
2 = 200 Hz "4-speed", this is the default setting
4 = 400 Hz "8-speed"
6 = 600 Hz "12-speed"


SIDBlaster
----------

SIDBlaster is a USB device that can utilize an actual SID chip
and allow playback using it, providing a truly authentic sound. 

In addition to some extra hardware and USB connectivity, 
the Poseidon USB stack needs to be installed. 

Samples will not be heard. The playsid.library sample handling 
is not usable with SIDBlaster.

SIDBlaster driver and integration by Erique


Changelog
---------
- 2022-10: Initial version, reSID v0.16
- 2022-11: SIDBlaster support, new reSID sampling modes, 
           reSID speed optimizations, some fixes
- 2022-11-19: Fix bug where playback would get stuck for a while, 
              example tune: JCH/Hawaii
- 2023-01: Added support for 2SIDs, stereo SIDs with 6 audio
           channels. This works only in reSID mode, and takes about
           double the amount of CPU compared to ordinary SIDs.
           Some reSID speed optimizations as well.
           Configurable update rate.
