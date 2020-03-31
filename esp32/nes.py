# micropython ESP32
# NES ROM image loader

# AUTHOR=EMARD
# LICENSE=BSD

# this code is SPI master to FPGA SPI slave
# FPGA sends pulse to GPIO after BTN state is changed.
# on GPIO pin interrupt from FPGA:
# btn_state = SPI_read
# SPI_write(buffer)
# FPGA SPI slave will accept image and start it

from machine import SPI, Pin, SDCard
from micropython import const, alloc_emergency_exception_buf
from uctypes import addressof
import os

import ecp5
import gc

class nes:
  def __init__(self):
    self.screen_x = const(64)
    self.screen_y = const(20)
    self.cwd = "/"
    self.init_fb()
    self.exp_names = " KMGTE"
    self.mark = bytearray([32,16,42]) # space, right triangle, asterisk
    self.read_dir()
    self.spi_read_irq = bytearray([1,0,0,0,0,0,0])
    self.spi_read_btn = bytearray([1,0xFE,0,0,0,0,0])
    self.spi_result = bytearray(7)
    self.spi_reset_nes = bytearray([0,0xFF,0,0,0,1])
    self.spi_enable_osd = bytearray([0,0xFE,0,0,0,1])
    self.spi_write_osd = bytearray([0,0xFD,0,0,0])
    self.led = Pin(5, Pin.OUT)
    self.led.off()
    self.spi_channel = const(2)
    self.init_pinout_sd()
    self.spi_freq = const(4000000)
    self.hwspi=SPI(self.spi_channel, baudrate=self.spi_freq, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(self.gpio_sck), mosi=Pin(self.gpio_mosi), miso=Pin(self.gpio_miso))
    alloc_emergency_exception_buf(100)
    self.enable = bytearray(1)
    self.irq_handler(0)
    self.irq_handler_ref = self.irq_handler # allocation happens here
    self.spi_request = Pin(0, Pin.IN, Pin.PULL_UP)
    self.spi_request.irq(trigger=Pin.IRQ_FALLING, handler=self.irq_handler_ref)

# init file browser
  def init_fb(self):
    self.fb_topitem = 0
    self.fb_cursor = 0
    self.fb_selected = -1

  @micropython.viper
  def init_pinout_sd(self):
    self.gpio_sck  = const(16)
    self.gpio_mosi = const(4)
    self.gpio_miso = const(12)

  @micropython.viper
  def irq_handler(self, pin):
    p8result = ptr8(addressof(self.spi_result))
    self.led.on()
    self.hwspi.write_readinto(self.spi_read_irq, self.spi_result)
    self.led.off()
    btn_irq = p8result[6]
    if btn_irq & 0x80: # btn event
      self.led.on()
      self.hwspi.write_readinto(self.spi_read_btn, self.spi_result)
      self.led.off()
      btn = p8result[6]
      p8enable = ptr8(addressof(self.enable))
      if p8enable[0]&2: # wait to release all BTNs
        if btn==1:
          p8enable[0]&=1 # clear bit that waits for all BTNs released
      else: # all BTNs released
        if (btn&0x78)==0x78: # all cursor BTNs pressed at the same time
          self.show_dir() # refresh directory
          p8enable[0]=(p8enable[0]^1)|2;
          self.osd_enable(p8enable[0]&1)
        if p8enable[0]==1:
          if btn==9: # btn3 cursor up
            self.move_dir_cursor(-1)
          if btn==17: # btn4 cursor down
            self.move_dir_cursor(1)
          if btn==33: # btn6 cursor left
            self.updir()
          if btn==65: # btn6 cursor right
            self.select_entry()

  def select_entry(self):
    if self.direntries[self.fb_cursor][1]: # is it directory
      self.cwd = self.fullpath(self.direntries[self.fb_cursor][0])
      self.init_fb()
      self.read_dir()
      self.show_dir()
    else:
      self.change_file()

  def updir(self):
    if len(self.cwd) < 2:
      self.cwd = "/"
    else:
      s = self.cwd.split("/")[:-1]
      self.cwd = ""
      for name in s:
        if len(name) > 0:
          self.cwd += "/"+name
    self.init_fb()
    self.read_dir()
    self.show_dir()

  def fullpath(self,fname):
    if self.cwd.endswith("/"):
      return self.cwd+fname
    else:
      return self.cwd+"/"+fname

  def change_file(self):
    oldselected = self.fb_selected - self.fb_topitem
    self.fb_selected = self.fb_cursor
    try:
      filename = self.fullpath(self.direntries[self.fb_cursor][0])
    except:
      filename = False
      self.fb_selected = -1
    self.show_dir_line(oldselected)
    self.show_dir_line(self.fb_cursor - self.fb_topitem)
    if filename:
      self.load(filename)
      self.osd_enable(0)
      self.enable[0]=0

  def load(self, filename):  
    try:
      filedata = open(filename,"rb")
    except:
      filedata = False
    if filedata:
      self.reset_nes(1)
      self.reset_nes(0)
      self.load_stream(filedata)
      filedata.close()

  # read from file -> write to SPI RAM
  def load_stream(self, filedata, addr=0, blocksize=1024):
    block = bytearray(blocksize)
    self.led.on()
    self.hwspi.write(bytearray([0x00, (addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF]))
    while True:
      if filedata.readinto(block):
        self.hwspi.write(block)
      else:
        break
    self.led.off()

  @micropython.viper
  def reset_nes(self, reset:int):
    pres = ptr8(addressof(self.spi_reset_nes))
    pres[5] = reset&1
    self.led.on()
    self.hwspi.write(self.spi_reset_nes)
    self.led.off()

  @micropython.viper
  def osd_enable(self, en:int):
    pena = ptr8(addressof(self.spi_enable_osd))
    pena[5] = en&1
    self.led.on()
    self.hwspi.write(self.spi_enable_osd)
    self.led.off()

  @micropython.viper
  def osd_print(self, x:int, y:int, i:int, text):
    p8msg=ptr8(addressof(self.spi_write_osd))
    a=0xF000+(x&63)+((y&31)<<6)
    p8msg[2]=i
    p8msg[3]=a>>8
    p8msg[4]=a
    self.led.on()
    self.hwspi.write(self.spi_write_osd)
    self.hwspi.write(text)
    self.led.off()

  @micropython.viper
  def osd_cls(self):
    p8msg=ptr8(addressof(self.spi_write_osd))
    p8msg[3]=0xF0
    p8msg[4]=0
    self.led.on()
    self.hwspi.write(self.spi_write_osd)
    self.hwspi.read(1280,32)
    self.led.off()

  # y is actual line on the screen
  def show_dir_line(self, y):
    if y < 0 or y >= self.screen_y:
      return
    mark = 0
    invert = 0
    if y == self.fb_cursor - self.fb_topitem:
      mark = 1
      invert = 1
    if y == self.fb_selected - self.fb_topitem:
      mark = 2
    i = y+self.fb_topitem
    if i >= len(self.direntries):
      self.osd_print(0,y,0,"%64s" % "")
      return
    if self.direntries[i][1]: # directory
      self.osd_print(0,y,invert,"%c%-57s     D" % (self.mark[mark],self.direntries[i][0]))
    else: # file
      mantissa = self.direntries[i][2]
      exponent = 0
      while mantissa >= 1024:
        mantissa >>= 10
        exponent += 1
      self.osd_print(0,y,invert,"%c%-57s %4d%c" % (self.mark[mark],self.direntries[i][0], mantissa, self.exp_names[exponent]))

  def show_dir(self):
    for i in range(self.screen_y):
      self.show_dir_line(i)

  def move_dir_cursor(self, step):
    oldcursor = self.fb_cursor
    if step == 1:
      if self.fb_cursor < len(self.direntries)-1:
        self.fb_cursor += 1
    if step == -1:
      if self.fb_cursor > 0:
        self.fb_cursor -= 1
    if oldcursor != self.fb_cursor:
      screen_line = self.fb_cursor - self.fb_topitem
      if screen_line >= 0 and screen_line < self.screen_y: # move cursor inside screen, no scroll
        self.show_dir_line(oldcursor - self.fb_topitem) # no highlight
        self.show_dir_line(screen_line) # highlight
      else: # scroll
        if screen_line < 0: # cursor going up
          screen_line = 0
          if self.fb_topitem > 0:
            self.fb_topitem -= 1
            self.show_dir()
        else: # cursor going down
          screen_line = self.screen_y-1
          if self.fb_topitem+self.screen_y < len(self.direntries):
            self.fb_topitem += 1
            self.show_dir()

  def read_dir(self):
    self.direntries = []
    ls = sorted(os.listdir(self.cwd))
    for fname in ls:
      stat = os.stat(self.fullpath(fname))
      if stat[0] & 0o170000 == 0o040000:
        self.direntries.append([fname,1,0]) # directory
      else:
        self.direntries.append([fname,0,stat[6]]) # file

  # NOTE: this can be used for debugging
  #def osd(self, a):
  #  if len(a) > 0:
  #    enable = 1
  #  else:
  #    enable = 0
  #  self.led.on()
  #  self.hwspi.write(bytearray([0,0xFE,0,0,0,enable])) # enable OSD
  #  self.led.off()
  #  if enable:
  #    self.led.on()
  #    self.hwspi.write(bytearray([0,0xFD,0,0,0])) # write content
  #    self.hwspi.write(bytearray(a)) # write content
  #    self.led.off()

def load(filename):
  n=nes()
  n.load(filename)

os.mount(SDCard(slot=3),"/sd")
ecp5.prog("/sd/nes/bitstreams/nes12f_esp32_darfon.bit")
gc.collect()
n=nes()
