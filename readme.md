# STM32 Library for E-Paper Display

Drives a Waveshare 2.9" e-paper display from an STM32 Nucleo-WB55RG over SPI.

## Hardware

| | |
|---|---|
| Display module | Waveshare Pico-ePaper-2.9 (B/W panel) |
| Panel | 2.9" V2, 296 x 128 pixels |
| Display controller | SSD1680 |
| MCU board | STM32 Nucleo-WB55RG (MB1355) |

Waveshare wiki: https://www.waveshare.com/wiki/2.9inch_e-Paper_Module_Manual#Working_With_STM32

Datasheets, schematics and the Nucleo user manual are in `docs/`.

## Configuration

- HSE: 32 MHz, SYSCLK: 64 MHz (PLL), see `docs/clock-config.png`
- SPI1 master, full duplex (MISO unused), mode 0, MSB first, 1 MHz (APB2 64 MHz / 64)
- CS is a software GPIO (PA4), not the SPI hardware NSS. The display does not
  need fast SPI, only clean edges and correct CS/DC timing.

## Connection

The Pico-ePaper-2.9 module can be wired in two ways. The Nucleo pins are the
same for both.

### Option A: 8-pin cable (P1)

| Display | Nucleo |
|---|---|
| VCC | 3V3 |
| GND | GND |
| DIN | PA7 (D11), SPI1_MOSI |
| CLK | PA5 (D13), SPI1_SCK |
| CS | PA4 (D10) |
| DC | PA2 (D1) |
| RST | PA1 (A2) |
| BUSY | PA3 (D0), input |

On P1, VCC also sets the logic level of the module's level shifter, so it must
be 3V3.

### Option B: Pico header rows (pins 1-20 / 21-40)

| Display | Pico header pin | Nucleo |
|---|---|---|
| VCC | 39 (VSYS) | 3V3 or 5V |
| GND | 38 (or 13 / 18) | GND |
| DC | 11 (GP8) | PA2 (D1) |
| CS | 12 (GP9) | PA4 (D10) |
| CLK | 14 (GP10) | PA5 (D13) |
| DIN | 15 (GP11) | PA7 (D11) |
| RST | 16 (GP12) | PA1 (A2) |
| BUSY | 17 (GP13) | PA3 (D0) |

On the header rows, VSYS (pin 39) is the module's only power input; pin 36
(3V3 OUT) is not connected on the module. If VCC goes anywhere else, the
controller runs on current leaking in through the signal pins: it accepts
commands and drives BUSY normally, but the boost converter has no power, so
the panel flickers weakly or not at all and keeps its old image, often with
stripes. The signals on these rows are on the module's 3.3 V side, so 5V on
VSYS is also safe.

## Library

`Core/Src/EPD_2in9_V2.c` is the Waveshare 2.9" V2 driver:
https://github.com/waveshareteam/e-Paper/blob/master/STM32/STM32-F103ZET6/User/e-Paper/EPD_2in9_V2.c

It loads its refresh waveform (`WS_20_30`) from the MCU. V2 panels need this;
the panel's built-in waveform (`0x22 0xF7`) does not refresh a V2 panel.

## Firmware behavior

After reset, the firmware initializes the STM32 peripherals and the display,
then draws three lines of text and a separator:

```text
Line 1: Hello
Line 2: STM32 EPD
Line 3: Minimal demo
```

Every 10 seconds it redraws the bottom area with an update counter and the
uptime (`Update #N`, `Uptime hh:mm:ss`) using a full refresh. The image is drawn
with a 90-degree rotation into a static frame buffer. Partial refresh is
available through `FULL_REFRESH_EVERY` in `Core/Src/minimal_display.c` but is
not yet verified on this panel.

The larger Waveshare graphics test `EPD_test()` is not part of the build. To
run it, add `Core/Src/EPD_2in9_V2_test.c` and `Core/Src/ImageData.c` to the
sources in `cmake/stm32cubemx/CMakeLists.txt`, then call `EPD_test()` in place
of the demo in `Core/Src/main.c`.

## Check wiring before flashing

The wiring check runs automatically before every flash (see below). To run it
on its own:

```bash
cmake --build build --target check-wiring
```

The check halts the MCU and drives the display pins directly over SWD, so
nothing is flashed and the picture on the panel is not changed. It verifies
BUSY, CS, the SPI lines (CLK, DIN, DC), RST and display power in that order,
stops at the first failure with a hint naming the wire to check, and fails the
build target. On success the MCU is reset and the existing firmware runs again.
The script is `tools/check_wiring.tcl`.

The last step checks display power. If VCC is on the wrong pin (see Option B),
the controller still runs on current leaking in through the signal pins, so the
first steps pass. The check therefore enables the controller's analog circuits
(without a display update), runs its built-in supply (VCI < 2.7 V) and
drive-voltage detections, and reads the result back over SPI. It fails if
either flag is set.

## Build and flash

Prerequisites: `cmake`, `ninja`, the ARM cross-toolchain (`arm-none-eabi-gcc`),
`openocd` and `stlink` (for `st-info`).

On macOS, use the Arm GNU Toolchain bundled with STM32CubeIDE or install the
`gcc-arm-embedded` Homebrew cask. Avoid the old Homebrew
`arm-none-eabi-gcc@9` formula if it reports a missing `libisl.23.dylib`.

If STM32CubeIDE is installed, select its newest ARM toolchain in the current
shell before configuring:

```bash
ARM_TOOLCHAIN_BIN="$(find /Applications/STM32CubeIDE.app/Contents/Eclipse/plugins \
    -path '*/tools/bin/arm-none-eabi-gcc' -type f -perm -111 \
    | tail -n 1 | sed 's#/arm-none-eabi-gcc$##')"
export PATH="$ARM_TOOLCHAIN_BIN:$PATH"
```

Configure and build from the project root:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TOOLCHAIN_FILE=cmake/gcc-arm-none-eabi.cmake
cmake --build build
```

The commands in this README use paths relative to the project root. From
another folder, pass the full path, for example
`cmake --build ~/test-epd/EPD-example/build --target flash`.

If you changed ARM compiler installations, configure in a new build directory
such as `build-cube`, because CMake caches the compiler path in the build tree.

Connect the Nucleo's `USB_STLINK` connector (CN15) with a USB cable that
carries data; charge-only cables power the board but the Mac does not see it.
Check that the probe is detected:

```bash
st-info --probe
```

It should report `Found 1 stlink programmers`. Then check the wiring, and if
it passes, build and flash:

```bash
cmake --build build --target flash
```

If the wiring check fails, nothing is flashed. To flash without the check, call
OpenOCD directly:

```bash
openocd -f interface/stlink.cfg -f target/stm32wbx.cfg \
    -c "program build/EPD-example.elf verify reset exit"
```

`Verified OK` means the flash succeeded. The `Adding extra erase range` warning
and `Unable to match requested speed 500 kHz` messages are harmless.

If OpenOCD prints `Error: open failed`, it cannot open the ST-LINK probe. Check
the USB cable, use the `USB_STLINK` connector, close STM32CubeIDE or other
debuggers, and retry.
