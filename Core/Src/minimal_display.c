#include "minimal_display.h"
#include "DEV_Config.h"
#include "GUI_Paint.h"
#include "EPD_2in9_V2.h"
#include <stdio.h>

/* Full refresh every N updates to clear partial-refresh ghosting.
 * 1 = full refresh only, until partial refresh is verified on this panel. */
#define FULL_REFRESH_EVERY 1

#define IMAGE_SIZE (((EPD_2IN9_V2_WIDTH + 7) / 8) * EPD_2IN9_V2_HEIGHT)

static UBYTE Image[IMAGE_SIZE];

void Display_Init(void)
{
    DEV_Module_Init();
    EPD_2IN9_V2_Init();

    // Landscape: 296 x 128
    Paint_NewImage(Image, EPD_2IN9_V2_WIDTH, EPD_2IN9_V2_HEIGHT, 90, WHITE);
    Paint_SelectImage(Image);
    Paint_Clear(WHITE);

    Paint_DrawString_EN(10, 10, "Line 1: Hello", &Font16, BLACK, WHITE);
    Paint_DrawString_EN(10, 30, "Line 2: STM32 EPD", &Font12, BLACK, WHITE);
    Paint_DrawString_EN(10, 50, "Line 3: Minimal demo", &Font12, BLACK, WHITE);
    Paint_DrawLine(10, 72, 286, 72, BLACK, DOT_PIXEL_1X1, LINE_STYLE_SOLID);

    // Base image is written to both RAMs; partial refreshes diff against it.
    EPD_2IN9_V2_Display_Base(Image);
}

void Display_Update(uint32_t count)
{
    char line[32];
    uint32_t s = HAL_GetTick() / 1000;

    Paint_ClearWindows(10, 80, 290, 125, WHITE);

    snprintf(line, sizeof(line), "Update #%lu", (unsigned long)count);
    Paint_DrawString_EN(10, 80, line, &Font20, BLACK, WHITE);

    snprintf(line, sizeof(line), "Uptime %02lu:%02lu:%02lu",
             (unsigned long)(s / 3600), (unsigned long)(s / 60 % 60), (unsigned long)(s % 60));
    Paint_DrawString_EN(10, 106, line, &Font16, BLACK, WHITE);

    if (count % FULL_REFRESH_EVERY == 0) {
        EPD_2IN9_V2_Init();
        EPD_2IN9_V2_Display_Base(Image);
    } else {
        EPD_2IN9_V2_Display_Partial(Image);
    }
}
