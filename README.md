# NES on the ECP5 Evaluation Board

Work in progress

Run `make prog` to load the bitstream to the board.


Using the patched ujprog source from here 
https://github.com/ironsteel/tools/tree/flash_hack do:

./ujprog -j FLASH -f 0x200000 [path-to-game-rom]

to write the game rom to the onboard SPI flash


You must ensure JP2 is shorted to connect the 12MHz
FTDI clock to the FPGA.
