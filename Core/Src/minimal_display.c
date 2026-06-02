#include "minimal_display.h"
#include "DEV_Config.h"
#include "GUI_Paint.h"
#include "EPD_2in9_V2.h"
#include <stdlib.h>
#include <stdio.h>

void Display_SimpleText(void)
{
    if (DEV_Module_Init() != 0) {
        printf("DEV_Module_Init failed\r\n");
        return;
    }

    // Initialize display
    EPD_2IN9_V2_Init();

    // Allocate a simple frame buffer
    UWORD Imagesize = ((EPD_2IN9_V2_WIDTH % 8 == 0)? (EPD_2IN9_V2_WIDTH / 8 ): (EPD_2IN9_V2_WIDTH / 8 + 1)) * EPD_2IN9_V2_HEIGHT;
    UBYTE *BlackImage = (UBYTE *)malloc(Imagesize);
    if (BlackImage == NULL) {
        printf("malloc failed\r\n");
        EPD_2IN9_V2_Sleep();
        DEV_Module_Exit();
        return;
    }

    // Prepare image
    Paint_NewImage(BlackImage, EPD_2IN9_V2_WIDTH, EPD_2IN9_V2_HEIGHT, 90, WHITE);
    Paint_SelectImage(BlackImage);
    Paint_Clear(WHITE);

    // Draw multiple lines of text
    Paint_DrawString_EN(10, 10, "Line 1: Hello", &Font16, BLACK, WHITE);
    Paint_DrawString_EN(10, 30, "Line 2: STM32 EPD", &Font12, BLACK, WHITE);
    Paint_DrawString_EN(10, 50, "Line 3: Minimal demo", &Font12, BLACK, WHITE);
    Paint_DrawString_EN(10, 70, "Line 4: Bye!", &Font12, BLACK, WHITE);

    // Send to display
    EPD_2IN9_V2_Display(BlackImage);

    // Keep image for a short while
    DEV_Delay_ms(2000);

    // Cleanup
    free(BlackImage);
    EPD_2IN9_V2_Sleep();
    DEV_Module_Exit();
}
