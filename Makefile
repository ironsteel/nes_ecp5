PROJ=nes
FPGA_PREFIX ?=
#FPGA_PREFIX ?= um5g-
FPGA_SIZE ?= 12

FPGA_KS ?= $(FPGA_PREFIX)$(FPGA_SIZE)k

ifeq ($(FPGA_SIZE), 12)
  CHIP_ID=0x21111043
  FPGA_KS = $(FPGA_PREFIX)25k
endif
ifeq ($(FPGA_SIZE), 25)
  CHIP_ID=0x41111043
endif
ifeq ($(FPGA_SIZE), 45)
  CHIP_ID=0x41112043
endif
ifeq ($(FPGA_SIZE), 85)
  CHIP_ID=0x41113043 # forksand board: 0x81113043
endif


IDCODE ?= $(CHIP_ID)

# ******* tools installation paths *******
# https://github.com/ldoolitt/vhd2vl
#VHDL2VL ?= /mt/scratch/tmp/openfpga/vhd2vl/src/vhd2vl
VHDL2VL ?= vhdl2vl
# https://github.com/YosysHQ/yosys
#YOSYS ?= /mt/scratch/tmp/openfpga/yosys/yosys
YOSYS ?= yosys
# https://github.com/YosysHQ/nextpnr
#NEXTPNR-ECP5 ?= /mt/scratch/tmp/openfpga/nextpnr/nextpnr-ecp5
NEXTPNR-ECP5 ?= nextpnr-ecp5
# https://github.com/SymbiFlow/prjtrellis
#TRELLIS ?= /mt/scratch/tmp/openfpga/prjtrellis
TRELLIS ?= /mt/scratch/tmp/openfpga/prjtrellis

# open source synthesis tools
#ECPPLL ?= $(TRELLIS)/libtrellis/ecppll
ECPPLL ?= ecppll
#ECPPACK ?= $(TRELLIS)/libtrellis/ecppack
ECPPACK ?= ecppack
# usage	LANG=C LD_LIBRARY_PATH=$(LIBTRELLIS) $(ECPPACK) --db $(TRELLISDB) --compress --idcode $(IDCODE) $< $@
TRELLISDB ?= $(TRELLIS)/database
LIBTRELLIS ?= $(TRELLIS)/libtrellis
BIT2SVF ?= $(TRELLIS)/tools/bit_to_svf.py
#BASECFG ?= $(TRELLIS)/misc/basecfgs/empty_$(FPGA_CHIP_EQUIVALENT).config
# yosys options, sometimes those can be used: -noccu2 -nomux -nodram
#YOSYS_OPTIONS ?=
YOSYS_OPTIONS ?= -abc9
# nextpnr options
NEXTPNR_OPTIONS ?=
#NEXTPNR_OPTIONS ?= --timing-allow-fail

CLK0_NAME = clk_25_125_48_6_25
CLK0_FILE_NAME = $(CLK0_NAME).v
CLK0_OPTIONS = \
  --module=$(CLK0_NAME) \
  --clkin_name=clk25_i \
  --clkin=25 \
  --clkout0_name=clk125_o \
  --clkout0=125 \
  --clkout1_name=clk48_o \
  --clkout1=48 \
  --clkout2_name=clk6_o \
  --clkout2=6 \
  --clkout3_name=clk25_o \
  --clkout3=25

all: ${PROJ}.bit

$(CLK0_NAME).v:
	$(ECPPLL) $(CLK0_OPTIONS) --file $@

VERILOG_FILES = $(wildcard *.v)

%.json: $(VERILOG_FILES)
	$(YOSYS) -q -l synth.log \
	-p "hierarchy -top top" \
	-p "synth_ecp5 ${YOSYS_OPTIONS} -json $@" $^

#        -p "read -vlog2k ${VERILOG_FILES}" \

%_out.config: %.json
	$(NEXTPNR-ECP5) $(NEXTPNR_OPTIONS) --json  $< --textcfg $@ --$(FPGA_KS) --freq 21 --package CABGA381 --lpf ulx3s.lpf

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
