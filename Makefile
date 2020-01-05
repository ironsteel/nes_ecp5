PROJ=nes
IDCODE ?= 0x21111043 # 12f

all: ${PROJ}.bit

%.json: $(wildcard *.v)
	yosys -q -l synth.log -p "synth_ecp5 -json $@" $^

%_out.config: %.json
	nextpnr-ecp5 --json  $< --textcfg $@ --25k --freq 21 --package CABGA381 --lpf ulx3s.lpf

%.bit: %_out.config
	ecppack --freq 19.4 --idcode $(IDCODE) --svf ${PROJ}.svf $< $@

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
