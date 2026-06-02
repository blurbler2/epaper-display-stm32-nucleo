# STM32 Library for E-Paper Display

## Display
Model: Waveshare 2.9" V2
Display Controller: SSD1680 V2 
Resolution: 296x128

https://www.waveshare.com/wiki/2.9inch_e-Paper_Module_Manual#Working_With_STM32


## STM32 Nucleo-WB55RG Board
Der STM32WB55 hat:

SPI + DMA + NSS Hardware optional
aber viele Boards nutzen Software-CS

e-Paper braucht KEIN Highspeed SPI, aber:

stabile Flanken
keine Race Conditions

## Configuration
HSE Input frequency: 32 Mhz
---
SYSCLK: 64 Mhz

## Connection

                ┌──────────────────────────────────────────┐
                │   2.9" E-Paper Display                   │
                │                                          │
                │   VCC   -------------------- 3V3         │
                │   GND   -------------------- GND         │
                │                                          │
                │   DIN   -------------------- PA7 (D11)    │
                │   CLK   -------------------- PA5 (D13)    │
                │   CS    -------------------- PA4 (D10)    │
                │   DC    -------------------- PA2 (D1)     │
                │   RST   -------------------- PA1 (A2)     │
                │   BUSY  -------------------- PA3 (D0)     │
                └──────────────────────────────────────────┘
                               │
                               │
                               ▼
                ┌──────────────────────────────────────────┐
                │   STM32WB55RG (Nucleo Board)             │
                │                                          │
                │   3V3   <------------------- VCC         │
                │   GND   <------------------- GND         │
                │                                          │
                │   PA7   <------------------- DIN (MOSI)  │
                │   PA5   <------------------- CLK (SCK)   │
                │   PA4   <------------------- CS          │
                │   PA2   <------------------- DC          │
                │   PA1   <------------------- RST         │
                │   PA3   -------------------> BUSY        │
                └──────────────────────────────────────────┘
                
## Library
SSD1680 V2 (EPD_2in9_V2.c)
From Waveshare team: https://github.com/waveshareteam/e-Paper/blob/master/STM32/STM32-F103ZET6/User/e-Paper/EPD_2in9_V2.c

## Build and run with CMake

Prerequisites: `cmake`, `ninja` (optional), the ARM cross-toolchain (`arm-none-eabi-gcc`), and a flashing tool (`openocd`, `st-flash` or `stlink`).

From the project root you can configure and build with the provided toolchain file:

```bash
# Configure (uses cmake/gcc-arm-none-eabi.cmake)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TOOLCHAIN_FILE=cmake/gcc-arm-none-eabi.cmake

# Build
cmake --build build --config Debug
```

```bash

#FLASH
openocd -s /opt/homebrew/share/openocd/scripts -f interface/stlink.cfg -f target/stm32wbx.cfg -c "program build/EPD-example.elf verify reset exit"
```