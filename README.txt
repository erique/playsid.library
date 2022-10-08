
*=======================================================================*
*                                                                       *
*       C64 MUSIC EMULATOR FOR AMIGA                                    *
*       (C) 1990-1994 HÅKAN SUNDELL & RON BIRK                          *
*                                                                       *
*=======================================================================*

SIDs have never sounded so good on the Amiga!

This version of the library has been modified to use the 680x0 
port of the reSID SID-emulation engine instead of the original 
SID-emulation. It is a cycle exact emulation with filter
support.

This is a drop-in replacement. To install, copy "playsid.library" 
to LIBS: over the original. You may also choose a version which 
uses the Paula 14-bit output mode: "playsid.library-14bit". 
Remove the "-14bit" part from the name in this case.

Applications using "playsid.library" will automatically be enhanced.
These are at least HippoPlayer and DeliTracker.

Please note that reSID is very heavy on the CPU. I measured
CPU usage of 60-90% on my A1200/060, depending on the tune.
Your system may become unresponsive if it's not powerful enough.

Also note samples will not be heard. This is because the
samples have typically had some special handling in
SID players and emulators. The playsid.library sample handling 
is not used with reSID.

/K-P


