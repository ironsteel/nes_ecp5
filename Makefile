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

# ******* tools installation paths *******
# https://github.com/ldoolitt/vhd2vl
VHDL2VL ?= /mt/scratch/tmp/openfpga/vhd2vl/src/vhd2vl
# https://github.com/YosysHQ/yosys
YOSYS ?= /mt/scratch/tmp/openfpga/yosys/yosys
# https://github.com/YosysHQ/nextpnr
NEXTPNR-ECP5 ?= /mt/scratch/tmp/openfpga/nextpnr/nextpnr-ecp5
# https://github.com/SymbiFlow/prjtrellis
TRELLIS ?= /mt/scratch/tmp/openfpga/prjtrellis

# open source synthesis tools
ECPPLL ?= $(TRELLIS)/libtrellis/ecppll
ECPPACK ?= $(TRELLIS)/libtrellis/ecppack
# usage	LANG=C LD_LIBRARY_PATH=$(LIBTRELLIS) $(ECPPACK) --db $(TRELLISDB) --compress --idcode $(IDCODE) $< $@
TRELLISDB ?= $(TRELLIS)/database
LIBTRELLIS ?= $(TRELLIS)/libtrellis
BIT2SVF ?= $(TRELLIS)/tools/bit_to_svf.py
#BASECFG ?= $(TRELLIS)/misc/basecfgs/empty_$(FPGA_CHIP_EQUIVALENT).config
# yosys options, sometimes those can be used: -noccu2 -nomux -nodram
YOSYS_OPTIONS ?=
# nextpnr options
NEXTPNR_OPTIONS ?=

all: ${PROJ}.bit

%.json: $(wildcard *.v)
	$(YOSYS) -q -l synth.log -p "synth_ecp5 -json $@" $^

%_out.config: %.json
	$(NEXTPNR-ECP5) --json  $< --textcfg $@ --$(FPGA_KS) --freq 21 --package CABGA381 --lpf ulx3s.lpf

%.bit: %_out.config
	LANG=C LD_LIBRARY_PATH=$(LIBTRELLIS) $(ECPPACK) --db $(TRELLISDB) --compress --idcode $(IDCODE) $< $@

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
	rm -f *.bit *.config *.json


.PHONY: prog clean
