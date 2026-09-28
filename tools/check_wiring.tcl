# Wiring check for the 2.9" e-Paper (SSD1680) on the Nucleo-WB55RG.
#
# Runs entirely over SWD: the MCU is halted right after reset, so no firmware
# runs and nothing is flashed. The pins are driven by writing GPIOA registers
# from OpenOCD. The display is only sent deep sleep, hardware resets and the
# controller's built-in voltage detections (no display update), so the picture
# on the panel is never changed.
#
# Each BUSY check sets PA3's pull resistor opposite to the expected level, so
# a disconnected BUSY wire can never pass by accident.
#
# Usage: cmake --build build --target check-wiring  (or --target flash)

set RCC_AHB2ENR 0x5800004C
set GPIOA_MODER 0x48000000
set GPIOA_PUPDR 0x4800000C
set GPIOA_IDR   0x48000010
set GPIOA_BSRR  0x48000018

set RST  [expr {1 << 1}]
set DC   [expr {1 << 2}]
set BUSY_BIT 3
set CS   [expr {1 << 4}]
set CLK  [expr {1 << 5}]
set DIN  [expr {1 << 7}]

proc rd {addr} { return [lindex [read_memory $addr 32 1] 0] }

proc pin {mask val} {
    if {$val} { mww $::GPIOA_BSRR $mask } else { mww $::GPIOA_BSRR [expr {$mask << 16}] }
}

proc busy {} { return [expr {([rd $::GPIOA_IDR] >> $::BUSY_BIT) & 1}] }

proc busy_pull {dir} {
    set shift [expr {2 * $::BUSY_BIT}]
    set p [expr {[rd $::GPIOA_PUPDR] & ~(3 << $shift)}]
    if {$dir eq "up"} { set p [expr {$p | (1 << $shift)}] } else { set p [expr {$p | (2 << $shift)}] }
    mww $::GPIOA_PUPDR $p
    sleep 5
}

# Wait up to ms for BUSY to reach level.
proc wait_busy {level ms} {
    for {set t 0} {$t < $ms} {incr t 10} {
        if {[busy] == $level} { return 1 }
        sleep 10
    }
    return [expr {[busy] == $level}]
}

# Check that BUSY stays at level for ms.
proc busy_stays {level ms} {
    for {set t 0} {$t < $ms} {incr t 10} {
        if {[busy] != $level} { return 0 }
        sleep 10
    }
    return 1
}

# Bit-banged SPI mode 0, MSB first. dc: 0 = command, 1 = data.
proc send {dc byte {use_cs 1}} {
    pin $::DC $dc
    if {$use_cs} { pin $::CS 0 }
    for {set i 7} {$i >= 0} {incr i -1} {
        if {($byte >> $i) & 1} {
            mww $::GPIOA_BSRR [expr {($::CLK << 16) | $::DIN}]
        } else {
            mww $::GPIOA_BSRR [expr {($::CLK | $::DIN) << 16}]
        }
        mww $::GPIOA_BSRR $::CLK
    }
    pin $::CLK 0
    pin $::CS 1
}

# Read one byte from register cmd. After the command, the controller shifts
# data out on SDA (our DIN pin) on each falling edge; sample while CLK is high.
proc read_reg {cmd} {
    set din_mode [expr {3 << 14}]
    pin $::DC 0
    pin $::CS 0
    for {set i 7} {$i >= 0} {incr i -1} {
        if {($cmd >> $i) & 1} {
            mww $::GPIOA_BSRR [expr {($::CLK << 16) | $::DIN}]
        } else {
            mww $::GPIOA_BSRR [expr {($::CLK | $::DIN) << 16}]
        }
        mww $::GPIOA_BSRR $::CLK
    }
    pin $::CLK 0
    pin $::DC 1
    mww $::GPIOA_MODER [expr {[rd $::GPIOA_MODER] & ~$din_mode}]
    set value 0
    for {set i 0} {$i < 8} {incr i} {
        pin $::CLK 1
        set value [expr {($value << 1) | (([rd $::GPIOA_IDR] >> 7) & 1)}]
        pin $::CLK 0
    }
    mww $::GPIOA_MODER [expr {([rd $::GPIOA_MODER] & ~$din_mode) | (1 << 14)}]
    pin $::CS 1
    return $value
}

# Send a command with data bytes and wait for BUSY to return low.
proc command {cmd args} {
    send 0 $cmd
    foreach d $args { send 1 $d }
    return [wait_busy 0 3000]
}

proc hw_reset {} {
    pin $::RST 1; sleep 10
    pin $::RST 0; sleep 10
    pin $::RST 1; sleep 10
}

proc deep_sleep {{use_cs 1}} {
    send 0 0x10 $use_cs
    send 1 0x01 $use_cs
}

proc pass {name} { echo "  PASS  $name" }
proc warn {name hint} {
    echo "  WARN  $name"
    foreach line [split $hint "\n"] { echo "        $line" }
}

proc finish {ok {name ""} {hint ""}} {
    if {!$ok} {
        echo "  FAIL  $name"
        foreach line [split $hint "\n"] { echo "        $line" }
    }
    reset run
    if {$ok} {
        echo "\nAll wiring checks passed. Safe to flash."
        shutdown
    } else {
        echo "\nWiring check failed. Fix the connection above, then run again."
        shutdown error
    }
}

proc run_checks {} {
    echo "\nE-Paper wiring check (no flashing, display content unchanged)\n"

    # Halt at the reset vector so no firmware touches the pins.
    reset halt

    # GPIOA clock, idle levels, then pin modes (outputs: RST DC CS CLK DIN).
    mww $::RCC_AHB2ENR [expr {[rd $::RCC_AHB2ENR] | 1}]
    pin [expr {$::RST | $::DC | $::CS}] 1
    pin [expr {$::CLK | $::DIN}] 0
    set moder [rd $::GPIOA_MODER]
    foreach p {1 2 4 5 7} {
        set moder [expr {($moder & ~(3 << (2 * $p))) | (1 << (2 * $p))}]
    }
    set moder [expr {$moder & ~(3 << (2 * $::BUSY_BIT))}]
    mww $::GPIOA_MODER $moder
    pass "SWD connection, GPIO setup"

    # 1. Hardware reset wakes the display; idle BUSY must be driven low.
    busy_pull up
    hw_reset
    if {![wait_busy 0 2000]} {
        busy_pull down
        if {[busy] == 0} {
            return [finish 0 "BUSY line / display power" \
                "BUSY is floating: the display is not driving it.\nCheck BUSY -> PA3 (D0), VCC -> 3V3, GND -> GND."]
        }
        return [finish 0 "Reset" \
            "The display is powered and drives BUSY, but stays busy after reset.\nCheck RST -> PA1 (A2)."]
    }
    pass "BUSY (PA3/D0): display controller is running and drives BUSY low"

    # 2. With CS held high the display must ignore SPI.
    busy_pull down
    deep_sleep 0
    if {![busy_stays 0 300]} {
        hw_reset
        return [finish 0 "Chip select" \
            "The display accepted SPI while CS was high.\nCheck CS -> PA4 (D10)."]
    }
    pass "CS (PA4/D10): display ignores SPI while deselected"

    # 3. Deep-sleep command (needs CLK, DIN, CS and DC) must drive BUSY high.
    deep_sleep 1
    if {![wait_busy 1 1000]} {
        return [finish 0 "SPI command" \
            "The display did not respond to a command.\nCheck CLK -> PA5 (D13), DIN -> PA7 (D11), CS -> PA4 (D10), DC -> PA2 (D1).\nCLK and DIN swapped is a common mistake."]
    }
    pass "SPI CLK (PA5/D13), DIN (PA7/D11), DC (PA2/D1): display accepted a command"

    # 4. Only a hardware reset leaves deep sleep: proves RST.
    busy_pull up
    hw_reset
    if {![wait_busy 0 1000]} {
        return [finish 0 "Reset" \
            "The display stayed in deep sleep after a reset pulse.\nCheck RST -> PA1 (A2)."]
    }
    pass "RST (PA1/A2): reset wakes the display"

    # 5. Supply: the controller also runs on current leaking in through the
    #    signal pins, but then its supply (VCI) is low and the boost converter
    #    cannot reach the drive voltage. Let the controller measure both.
    #    Status register 0x2F: bit 5 HV not ready, bit 4 VCI low, bits 1:0 chip ID.
    set status [read_reg 0x2F]
    if {($status & 3) != 1} {
        warn "Display power not checked" \
            [format "Could not read the controller status (read 0x%02X).\nMake sure VCC is on the module's power input (Pico header: pin 39 VSYS)." $status]
        return [finish 1]
    }
    command 0x22 0xC0             ;# clock + analog on, no display update
    command 0x20
    command 0x15 0x07             ;# VCI detection, threshold 2.7 V
    command 0x14 0x00             ;# HV ready detection
    set status [read_reg 0x2F]
    command 0x22 0x03             ;# analog + clock off
    command 0x20
    if {$status & 0x30} {
        return [finish 0 "Display power" \
            [format "The controller runs, but its supply is too weak (status 0x%02X):\nit is powered through the signal pins, not through VCC.\nCheck VCC: 8-pin cable -> VCC; Pico header -> pin 39 (VSYS), not 36 or 37." $status]]
    }
    pass "VCC: supply above 2.7 V and drive voltage ready"

    finish 1
}

init
run_checks
