# NES on the ulx3s Board

Work in progress, uses VGA PMOD

# TODO

1. Use external SDRAM for storing the game
2. Add support for DVI output
3. Remove main_mem.v and use the SDRAM for the cpu and ppu memory
4. Integrate original GameLoader.v, so we don't need to convert the nes games
5. Maybe add support for loading the games from the SDCARD
