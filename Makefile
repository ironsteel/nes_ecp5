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
YOSYS_OPTIONS ?= -nowidelut
#YOSYS_OPTIONS ?= -abc9
# nextpnr options
#NEXTPNR_OPTIONS ?=
NEXTPNR_OPTIONS ?= --timing-allow-fail
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

all: ${PROJ}.bit ${PROJ}.json

$(CLK0_NAME).v:
	$(ECPPLL) $(CLK0_OPTIONS) --file $@

VERILOG_FILES = top.v
VERILOG_FILES += $(CLK0_FILE_NAME) 
VERILOG_FILES += nes.v
VERILOG_FILES += ppu.sv
VERILOG_FILES += apu.sv
VERILOG_FILES += cart.sv
VERILOG_FILES += dpram.v
VERILOG_FILES += mappers/generic.sv
VERILOG_FILES += mappers/MMC1.sv
VERILOG_FILES += mappers/MMC2.sv
VERILOG_FILES += mappers/MMC3.sv
VERILOG_FILES += mappers/MMC5.sv
VERILOG_FILES += mappers/VRC.sv
VERILOG_FILES += mappers/misc.sv
VERILOG_FILES += mappers/Namco.sv
VERILOG_FILES += mappers/Sunsoft.sv
VERILOG_FILES += mappers/JYCompany.sv
VERILOG_FILES += mappers/Sachen.sv

VERILOG_FILES += sdram.v
VERILOG_FILES += game_loader.v
VERILOG_FILES += flash_loader.v
VERILOG_FILES += ecp5pll.sv
VERILOG_FILES += palette_ram.v
VERILOG_FILES += vga.v
VERILOG_FILES += framebuffer.v
VERILOG_FILES += sigma_delta_dac.v
VERILOG_FILES += vga2dvid.v
VERILOG_FILES += flashmem.v
VERILOG_FILES += tmds_encoder.v

VERILOG_FILES += osd/osd.v         
VERILOG_FILES += osd/spi_osd.v   
VERILOG_FILES += osd/spirw_slave_v.v

VERILOG_FILES += usb/report_decoder/usbh_report_decoder_darfon.v

VERILOG_FILES += usb/usbhost/usbh_crc16.v
VERILOG_FILES += usb/usbhost/usbh_crc5.v
VERILOG_FILES += usb/usbhost/usbh_host_hid.v
VERILOG_FILES += usb/usbhost/usbh_sie.v

VERILOG_FILES += usb/usb11_phy_vhdl/usb_phy.v
VERILOG_FILES += usb/usb11_phy_vhdl/usb_rx_phy.v
VERILOG_FILES += usb/usb11_phy_vhdl/usb_tx_phy.v

VHDL_FILES = t65/T65_Pack.vhd
VHDL_FILES += t65/T65_MCode.vhd
VHDL_FILES += t65/T65_ALU.vhd
VHDL_FILES += t65/T65.vhd

GHDL_MODULE = -mghdl

%.json: ${VERILOG_FILES} ${VHDL_FILES}
	$(YOSYS) $(GHDL_MODULE) -q -l synth.log \
	-p "ghdl --std=08 --ieee=synopsys ${VHDL_FILES} -e t65" \
	-p "read_verilog -sv ${VERILOG_FILES}" \
	-p "hierarchy -top top" \
	-p "synth_ecp5 ${YOSYS_OPTIONS} -json $@"

#        -p "read -vlog2k ${VERILOG_FILES}" \

%_out.config: %.json
	$(NEXTPNR-ECP5) $(NEXTPNR_OPTIONS) --json  $< --textcfg $@ --$(FPGA_KS) --freq 21 --package CABGA381 --lpf ulx3s_v20.lpf

%.bit: %_out.config
	LANG=C LD_LIBRARY_PATH=$(LIBTRELLIS) $(ECPPACK) --db $(TRELLISDB) --compress --idcode $(IDCODE) $< $@

prog: ${PROJ}.bit
	fujprog $<

prog_flash: ${PROJ}.bit
	fujprog -j FLASH $<

prog_game: rom/game_tilt.img
	fujprog -j FLASH -f 0x200000 $<


clean:
	rm -f *.bit *.config *.json


.PHONY: prog clean
