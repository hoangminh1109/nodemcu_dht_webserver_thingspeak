--------------------------------------------------------------------------------
-- MAX7229 module for NodeMCU
-- SOURCE: https://github.com/marcelstoer/nodemcu-max7219
-- AUTHOR: marcel at frightanic dot com
-- LICENSE: http://opensource.org/licenses/MIT
--------------------------------------------------------------------------------

-- Set module name as parameter of require
local modname = ...
local M = {}
_G[modname] = M
--------------------------------------------------------------------------------
-- Local variables
--------------------------------------------------------------------------------
local debug = false
local numberOfDigits
-- ESP8266 pin which is connected to CS of the MAX7219
local slaveSelectPin
-- numberOfModules * 8 bytes for the char representation, left-to-right
local digits = {}

--------------------------------------------------------------------------------
-- Local/private functions
--------------------------------------------------------------------------------

local function out(msg)
  if debug then
    print("[MAX7219] " .. msg)
  end
end

local function sendByte(register, data)
  -- enble sending data
  gpio.write(slaveSelectPin, gpio.LOW)

  spi.send(1, register * 256 + data)
  tmr.delay(5)

  -- make the chip latch data into the registers
  gpio.write(slaveSelectPin, gpio.HIGH)
end

local function commit()
  for i = 1, numberOfDigits do
    local register = i
    --out("register = "..register..", digit = "..digits[i])
    sendByte(register, digits[i])
  end
end

--------------------------------------------------------------------------------
-- Public functions
--------------------------------------------------------------------------------
-- Configures both the SoC and the MAX7219 modules.
-- @param config table with the following keys (* = mandatory)
--               - numberOfModules*
--               - slaveSelectPin*, ESP8266 pin which is connected to CS of the MAX7219
--               - debug
function M.setup(config)
  local config = config or {}

  numberOfDigits = assert(config.numberOfDigits, "'numberOfDigits' is a mandatory parameter")
  slaveSelectPin = assert(config.slaveSelectPin, "'slaveSelectPin' is a mandatory parameter")

  if config.debug then debug = config.debug end

  out("Number of digits: " .. numberOfDigits ..", SS pin: " .. slaveSelectPin)

  local MAX7219_REG_DECODEMODE = 0x09
  local MAX7219_REG_INTENSITY = 0x0A
  local MAX7219_REG_SCANLIMIT = 0x0B
  local MAX7219_REG_SHUTDOWN = 0x0C
  local MAX7219_REG_DISPLAYTEST = 0x0F

  spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 16, 8)
  -- Must NOT be done _before_ spi.setup() because that function configures all HSPI* pins for SPI. Hence,
  -- if you want to use one of the HSPI* pins for slave select spi.setup() would overwrite that.
  gpio.mode(slaveSelectPin, gpio.OPENDRAIN)
  gpio.write(slaveSelectPin, gpio.HIGH)

  sendByte(MAX7219_REG_SCANLIMIT, numberOfDigits)
  sendByte(MAX7219_REG_DECODEMODE, 0xFF)
  sendByte(MAX7219_REG_DISPLAYTEST, 0)
  sendByte(MAX7219_REG_INTENSITY, 0x0)
  sendByte(MAX7219_REG_SHUTDOWN, 1)

  M.clear()
end

function M.clear()
  for i = 1, numberOfDigits do
    digits[i] = 0x00
  end
  commit()
end

function M.write4(number)
    th = math.floor(number/1000);
    h = math.floor((number-th*1000)/100)
    t = math.floor((number -th*1000 - h*100)/10)
    u = math.floor((number -th*1000 - h*100 - t*10))

    digits[1] = th
    digits[2] = h
    digits[3] = t
    digits[4] = u

  commit()
end

function M.write2(index, number)
    t = math.floor(number/10);
    u = math.floor((number-t*10))

    digits[(index-1)*2+1] = t
    digits[(index-1)*2+2] = u

  commit()
end


-- Sets the brightness of the display.
-- intensity: 0x00 - 0x0F (0 - 15)
function M.setIntensity(intensity)
  local MAX7219_REG_INTENSITY = 0x0A

  sendByte(MAX7219_REG_INTENSITY, intensity)
end

-- Turns the display on or off.
-- shutdown: true=turn off, false=turn on
function M.shutdown(shutdown)
  local MAX7219_REG_SHUTDOWN = 0x0C
    
    if (shutdown) then 
      sendByte(MAX7219_REG_SHUTDOWN, 0) 
    else 
      sendByte(MAX7219_REG_SHUTDOWN, 1) 
    end
end

-- send byte
function M.sendByte(register, data)
    sendByte(register, data)
end

return M
