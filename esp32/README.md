# ESP32 OSD NES ROM Loader

Uploading to ESP32 is explained in
[esp32ecp5](https://github.com/emard/esp32ecp5) project.

Upload "nes.py" to ESP32

Compile NES bitstream "nes.bit.gz" with ESP32 support. Also USB support
is recommended if you have compatible joystick (darfon, saitek, xbox360).

Option 1: bitstream in SPI FLASH: Upload NES bitstream to SPI flash

    ujprog -j flash nes.bit

Option 2: bitstream in ESP32 FLASH: gzip NES bitstream

    gzip -9 nes.bit

For Option 2, upload "ecp5.py", "nes.bit.gz" to root directory of ESP32.

Upload few ROMs from some site like
[wowroms](https://wowroms.com/en/roms/nintendo-entertainment-system)
to SD card, it can be done using "uftpd.py", SD card reader is not required.

Start ESP32 NES OSD

    screen /dev/ttyUSB0 115200
    >>> import nes

It will upload NES bitstream "nes.bit.gz" to ESP32 and register interrupt
handler, it should respond to those keypresses:

    UP+DOWN+LEFT+RIGHT (pressed together): directory list window open/close
    UP or DOWN: move cursor in the directory list
    RIGHT: enter subdirectory or load file
    LEFT: back one subdirectory level
 