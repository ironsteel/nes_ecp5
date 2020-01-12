PROJ=nes
FPGA_SIZE ?= 12

FPGA_KS ?= $(FPGA_SIZE)k

ifeq ($(FPGA_SIZE), 12)
  CHIP_ID=0x21111043
  FPGA_KS = 25k
endif
ifeq ($(FPGA_SIZE), 25)
  CHIP_ID=0x41111043
endif
ifeq ($(FPGA_SIZE), 45)
  CHIP_ID=0x41112043
endif
ifeq ($(FPGA_SIZE), 85)
  CHIP_ID=0x41113043
endif

IDCODE ?= $(CHIP_ID)

all: ${PROJ}.bit

%.json: $(wildcard *.v)
	yosys -q -l synth.log -p "synth_ecp5 -json $@" $^

%_out.config: %.json
	nextpnr-ecp5 --json  $< --textcfg $@ --$(FPGA_KS) --freq 21 --package CABGA381 --lpf ulx3s.lpf

%.bit: %_out.config
	ecppack --compress --freq 19.4 --idcode $(IDCODE) --svf ${PROJ}.svf $< $@

${PROJ}.svf : ${PROJ}.bit

prog: ${PROJ}.bit
	ujprog $<

prog_flash: ${PROJ}.bit
	ujprog -j FLASH $<

testbench:  $(filter-out $(wildcard pll.v),$(wildcard *.v)) $(wildcard sim/*.v)
	iverilog -DSIM=1 -o testbench $^ $(shell yosys-config --datdir/ecp5/cells_sim.v)

games_8.hex: rom/game_tilt.nes
	hexdump -e '1/1 "%02X" "\n"' $< -v > $@

testbench_vcd: testbench games_8.hex
	vvp -N testbench -fst +vcd

prog_game: rom/game_tilt.img
	ujprog -j FLASH -f 0x200000 $<


clean:
	rm -f *.svf *.bit *.config *.json


.PHONY: prog clean
