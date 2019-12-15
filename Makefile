PROJ=nes
IDCODE ?= 0x21111043 # 12f

TRELLIS=/usr/local/share/trellis

all: ${PROJ}.bit

%.json: $(wildcard *.v)
	yosys -q -p "synth_ecp5 -abc9 -json $@" $^

%_out.config: %.json
	nextpnr-ecp5 --json  $< --textcfg $@ --25k --freq 21 --package CABGA381 --lpf ecp5evn.lpf

%.bit: %_out.config
	ecppack --freq 19.4 --idcode $(IDCODE) --svf ${PROJ}.svf $< $@

${PROJ}.svf : ${PROJ}.bit

prog: ${PROJ}.svf
	openocd -f ${TRELLIS}/misc/openocd/ecp5-evn.cfg -c "transport select jtag; init; svf $<; exit"

clean:
	rm -f *.svf *.bit *.config *.json

.PHONY: prog clean
