
# FPGA NES on the ulx3s 12F Board using prj trellis, nextpnr and yosys

## Intro

This is a port of the MIST NES core to the ulx3s board
using only open source tools for synthesys and place and route.

At the moment it has working DVI out (640x480@60Hz),
games are loaded from the onboard SPI flash from offset 0x200000 and
audio out from the 3.5mm jack

Two options are available for joystick input:
1. The ulx3s onboard buttons or
2. An external NES gamepad

Read the [joystick instructions here](#Joystick support) 


## Building

Before flashing and compiling the bitstream,
make sure you have the super tilt bros game uploaded to the flash using:

```
make prog_game
```

After that type:

```
make prog
```

to produce the FPGA bitstream and flash it to the FPGA SRAM.

If everything goes well you should see the game on your DVI screen
after the bitstream is uploaded.

If everything works it's recommended to upload the bitstream to the onboard FLASH using:

```
make prog_flash
```

so you don't need to reupload it when you upload a different game.

## Uploading games

1. Find your favorite game rom file
2. Rename it's extension from .nes to .img
4. Type
```
ujprog -j FLASH -f 0x200000 [path_to_your_game].img
```

If everything is ok, the game should start running.

N.B. Games upto 512KB using mappers MMC0, MMC1, MMC3 and MMC5 are supported for now

# Joystick support

Right now there are two options for joystick input -
the onboard ulx3s buttons or an original NES joypad connected
to the J1 expansion header.

1. If you want to use the onboard buttons make sure that first DIP switch
on the board is set to OFF. The PWR button acts as the start button.

2. If you have an original NES gamepad you want to use set the first DIP switch to ON
and wire your gamepad as follows:

```
J1 HEADER TOP ROW, LEFT TO RIGHT
[3.3V] [GND] [joy_data] [joy_clock] [joy_strobe]
```

# Future improvements

1. Maybe add support for loading the games from the SDCARD
