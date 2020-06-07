PROJ=nes
FPGA_PREFIX ?=
#FPGA_PREFIX ?= um5g-
FPGA_SIZE ?= 12

FPGA_KS ?= $(FPGA_PREFIX)$(FPGA_SIZE)k

ifeq ($(FPGA_SIZE), 12)
  CHIP_ID=0x21111043
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

YOSYS           ?= yosys
YOSYS_OPTIONS   ?= -abc9 -nowidelut
NEXTPNR-ECP5    ?= nextpnr-ecp5
NEXTPNR_OPTIONS ?= --timing-allow-fail --router router2
ECPPACK         ?= ecppack

all: ${PROJ}.bit ${PROJ}.json

VERILOG_FILES  = top.v
VERILOG_FILES += ecp5pll.sv
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
VERILOG_FILES += palette_ram.v
VERILOG_FILES += vga.v
VERILOG_FILES += framebuffer.v
VERILOG_FILES += sigma_delta_dac.v
VERILOG_FILES += vga2dvid.v
VERILOG_FILES += flashmem.v
VERILOG_FILES += tmds_encoder.v

VERILOG_FILES += osd/osd.v
VERILOG_FILES += osd/spi_osd.v
VERILOG_FILES += osd/spi_ram_btn.v
VERILOG_FILES += osd/spirw_slave_v.v

# choose one
VERILOG_FILES += usb/report_decoder/usbh_report_decoder_darfon.v
#VERILOG_FILES += usb/report_decoder/usbh_report_decoder_nes.v
#VERILOG_FILES += usb/report_decoder/usbh_report_decoder_saitek.v
#VERILOG_FILES += usb/report_decoder/usbh_report_decoder_xbox360.v
# for xbox360 also edit top.v C_usb_speed=1, C_report_bytes=20

VERILOG_FILES += usb/usbhost/usbh_crc16.v
VERILOG_FILES += usb/usbhost/usbh_crc5.v
VERILOG_FILES += usb/usbhost/usbh_host_hid.v
VERILOG_FILES += usb/usbhost/usbh_sie.v

VERILOG_FILES += usb/usb11_phy_vhdl/usb_phy.v
VERILOG_FILES += usb/usb11_phy_vhdl/usb_rx_phy.v
VERILOG_FILES += usb/usb11_phy_vhdl/usb_tx_phy.v

VHDL_FILES  = t65/T65_Pack.vhd
VHDL_FILES += t65/T65_MCode.vhd
VHDL_FILES += t65/T65_ALU.vhd
VHDL_FILES += t65/T65.vhd

#GHDL_MODULE = -mghdl

%.json: ${VERILOG_FILES} ${VHDL_FILES}
	$(YOSYS) $(GHDL_MODULE) -q -l synth.log \
	-p "ghdl --std=08 --ieee=synopsys ${VHDL_FILES} -e t65" \
	-p "read_verilog -sv ${VERILOG_FILES}" \
	-p "hierarchy -top top" \
	-p "synth_ecp5 ${YOSYS_OPTIONS} -json $@"

%_out.config: %.json
	$(NEXTPNR-ECP5) $(NEXTPNR_OPTIONS) --json  $< --textcfg $@ --$(FPGA_KS) --freq 21 --package CABGA381 --lpf ulx3s_v20.lpf

%.bit: %_out.config
	LANG=C $(ECPPACK) --freq 62.0 --compress --idcode $(IDCODE) $< $@

prog: ${PROJ}.bit
	fujprog $<

prog_flash: ${PROJ}.bit
	fujprog -j FLASH $<

prog_game: rom/game_tilt.img
	fujprog -j FLASH -f 0x200000 $<

clean:
	rm -f *.bit *.config *.json

.PHONY: prog clean
