--load credentials
--SID and PassWord should be saved according wireless router in use
dofile("credentials.lua")

function startup()
    tmr.stop(0)
    if file.open("init.lua") == nil then
      print("init.lua deleted")
    else
      print("Running\n\r\n\r")
      file.close("init.lua")
      dofile("myfile.lua")
    end
end

-- BLINKING AT D0
LED_PIN=0
INTERVAL_BLINKING=500

lighton=0
gpio.mode(LED_PIN,gpio.OUTPUT)
tmr.alarm(2,INTERVAL_BLINKING,tmr.ALARM_AUTO,function()
    if lighton==0 then
        lighton=1
        gpio.write(LED_PIN,gpio.HIGH)
    else
        lighton=0
        gpio.write(LED_PIN,gpio.LOW)
    end
end)
gpio.write(LED_PIN,gpio.HIGH)
tmr.stop(2)

print("Blinking the led at D0 every 0.5 sec")
print("Stop blinking by tmr.stop(0)\n\r")

--init.lua
wifi.sta.disconnect()
-- vdd = adc.readvdd33()
-- print("Vdd = "..vdd.." mV")
print("set up wifi mode")
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID,PASSWORD,0)
wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
    if wifi.sta.getip()== nil then 
        print("IP unavaiable, Waiting...") 
    else 
        tmr.stop(1)
        print("Config done, IP is "..wifi.sta.getip())
        print("You have 5 seconds to abort Startup")
        print("Waiting...")
        tmr.alarm(0,1000,0,startup)
    end 
 end)
