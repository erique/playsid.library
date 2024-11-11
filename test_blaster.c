#include <stdio.h>
#include <stdlib.h>
#include <proto/exec.h>
#include <proto/poseidon.h>
#include <string.h>

#include "sidblast.h"

static int delay(int x)
{
    int a = 0;
    while(x--)
    {
        volatile uint8_t* p = (volatile uint8_t*)0xbfe001;
        a += *p;
    }
    return a;
}

int main()
{
    if (!sid_init())
    {
        printf("sid init failed\n");
        return -1;
    }
/*
    struct Library* PsdBase;
    if(!(PsdBase = OpenLibrary("poseidon.library", 1)))
    {
        printf("OpenLibrary(\"poseidon.library\") failed\n");
        return FALSE;
    }
*/
//
///    sid_write_reg(0x18, 0x0f);

    Disable();
    for (int a = 0; a < 20; ++a)
    {
    delay(100000);

    for (int i = 0; i < 16*256; ++i)
    {
        sid_write_reg(i & 0x1f, i);
    }
    }
    Enable();
/*
    for (int i = 0; i < 32; ++i)
    {
        sid_read_reg(i & 0x1f);
    }
*/

    return 0;


    sid_read_reg(0x18);

    {
        sid_write_reg(0x00, 0x00);
        sid_write_reg(0x01, 0x00);
        sid_write_reg(0x07, 0x00);
        sid_write_reg(0x08, 0x00);
        sid_write_reg(0x0e, 0x00);
        sid_write_reg(0x0f, 0x00);

        uint8_t readbuf[3];
        for (int i = 0; i < 50; ++i)
        {
//            psdDelayMS(20);

            sid_write_reg(0x18, 0x0f);
            uint8_t v = sid_read_reg(0x18);
            printf("$18 = %02lx\n", v);

//            psdDelayMS(1);

            sid_write_reg(0x18, 0x00);
            v = sid_read_reg(0x18);
            printf("$18 = %02lx\n", v);

        }
    }
//    CloseLibrary(PsdBase);

    sid_exit();
    return 0;
}
