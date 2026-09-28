/* Minimal display helper - static text plus a periodically updated counter */
#ifndef __MINIMAL_DISPLAY_H
#define __MINIMAL_DISPLAY_H

#include <stdint.h>

void Display_Init(void);
void Display_Update(uint32_t count);

#endif
