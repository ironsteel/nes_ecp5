# FPGA NES on the ulx3s board using prj trellis, nextpnr and yosys

## Intro

This is a port of the MIST NES core to the ulx3s board
using only open source tools for synthesys and place and route.

At the moment it has working DVI out (640x480@60Hz),
games can be loaded from the onboard SPI flash from offset 0x200000 or
from the sdcard using the esp32 OSD functionality and
audio out from the 3.5mm jack

Three options are available for joystick input:

1. The ulx3s onboard buttons
2. An external NES gamepad
3. [This usb gamepad](https://www.aliexpress.com/item/32760610851.html?spm=2114.search0302.3.15.38b943f3RqiZLv&ws_ab_test=searchweb0_0,searchweb201602_0,searchweb201603_0,ppcSwitch_0&algo_pvid=881975df-54a8-44c4-b1c7-eaa707cb17b5&algo_expid=881975df-54a8-44c4-b1c7-eaa707cb17b5-2) connected to us2 via usb-otg adapter 

## Getting started

1. Make sure you have [ghdl](https://github.com/ghdl/ghdl) and [ghdl-yosys-plugin](https://github.com/ghdl/ghdl-yosys-plugin) installed in addition to nextpnr and yosys.
2. Type

```
make prog_flash
```

to synth and PnR the design and flash it to the ulx3s

3. Follow [emard's esp32 setup guide](https://github.com/emard/esp32ecp5/blob/master/README.md) 
4. Upload the esp32/nes.py file from this repo to the esp32's flash root dir
5. Change the esp32 main.py file to match something like this

```
import network
from machine import SDCard
sta_if = network.WLAN(network.STA_IF)
sta_if.active(True)
sta_if.connect("YourWifiAP", "YourPassowrd")
os.mount(SDCard(slot=3),"/sd")
import uftpd
import nes

```

6. Add some nes ROM's to your sdcard
7. Hook up your ulx3s to a monitor and press all the direction buttons on the board
at the same time to bring up the file browser on the screen
8. Choose your ROM and load it by pressing the right button on the board.
9. If everything's right, the game should start

## Customization

By default the project is built with sdcard support for loading the roms via the esp32
and joystick support using the onboard buttons and the usb gamepad connected to us2 connector.

You can also load the games from the onboard flash memory
by changing the value of the parameters in the top.v file like this: 
```
  parameter C_flash_loader=1, // fujprog -j flash -f 0x200000 100in1.img
  parameter C_esp32_loader=0 // usage: import nes # for OSD press together A B SELECT START or all 4 directions
```
and recompiling the bitstream and reflashing it to the board.

And then upload your game:
1. Find and download your favorite game rom file
2. Type
```
fujprog -j FLASH -f 0x200000 [path_to_your_game].nes
```

If everything went well the game should start.

If you have an original NES joypad
you can use it by changing

```
parameter use_external_nes_joypad=1
``` 

in the top.v file and connecting it to the
J1 header as follows:

```
J1 HEADER TOP ROW, LEFT TO RIGHT
[3.3V] [GND] [joy_data] [joy_clock] [joy_strobe]
```

## Changing the target ecp5 device

The target ecp5 device by default is a 12K one.

If you have a ulx3s board with a bigger ecp5 FPGA, you can override it using

```
FPGA_SIZE=45 make prog
```

or changing the `FPGA_SIZE` variable in the Makefile.

## Unsupported mappers

mapper16, mapper67, mapper68,
mapper69, mapper83, VRC7, MapperFDS and MapperNSF.

These mappers are not supported because their
source code is using system verilog features that
yosys doesn't support right now.

