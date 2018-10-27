--############
--# Settings #
--############
DHT_PIN=1

INTERVAL_DHT=5000
INTERVAL_THINGSPEAK=60000

THINGSPEAK_CHANNEL_APIWRITEKEY = "--thingspeak_apiwritekey--"
THINGSPEAK_CHANNEL_TEMP_FIELD = "field1"
THINGSPEAK_CHANNEL_HUMID_FIELD = "field2"


--################
--# END settings #
--################


--####################
--# Global variables #
--################

temperature = 0
humidity = 0

acc_temperature = 0
acc_humidity = 0

measure_count = 0

intensity = 0

if file.open("intensity.lua", "r") then
  intensity = tonumber(file.readline())
  file.close()
else
  intensity = 9
  
  file.open('intensity.lua', "w")
  file.writeline(tostring(intensity))
  file.close()                
end

--####################
--#END Global variables #
--####################

-- init LED 7 SEG display
max7219 = require("max7219")
max7219.setup({debug = false, numberOfDigits = 4, slaveSelectPin = 2})
max7219.shutdown(false)
max7219.setIntensity(intensity)
max7219.sendByte(1,0xA)
max7219.sendByte(2,0xA)
max7219.sendByte(3,0xA)
max7219.sendByte(4,0xA)

-- DHT SENSOR AT D1
function get_sensor_Data()
    dht=require("dht")
    status,temp,humi,temp_decimial,humi_decimial = dht.read(DHT_PIN)
        if( status == dht.OK ) then
            -- Prevent "0.-2 deg C" or "-2.-6"          
            temperature = temp.."."..(math.abs(temp_decimial)/100)
            humidity = humi.."."..(math.abs(humi_decimial)/100)
            -- If temp is zero and temp_decimal is negative, then add "-" to the temperature string
            if(temp == 0 and temp_decimial<0) then
                temperature = "-"..temperature
            end

            measure_count = measure_count+1
            acc_temperature = acc_temperature + tonumber(temperature)

            -- adjust humidity
            -- adj_humidity = 0.54*humidity + 37.63
            adj_humidity = tonumber(humidity)*0.54 + 37.63
            acc_humidity = acc_humidity + adj_humidity
            
            print("Temperature: "..temperature.." deg C")
            print("Adjusted humidity: "..adj_humidity.."%\n\r")
        elseif( status == dht.ERROR_CHECKSUM ) then          
            print( "DHT Checksum error" )
            temperature=-1 --TEST
        elseif( status == dht.ERROR_TIMEOUT ) then
            print( "DHT Time out" )
            temperature=-2 --TEST
        end
    -- Release module
    dht=nil
    package.loaded["dht"]=nil
end

-- POST TO THINGSPEAK
function DisplayAndPost()

    avg_temperature = 0
    avg_humidity = 0

    avg_temperature = acc_temperature/measure_count
    avg_humidity = acc_humidity/measure_count

    print("Average temperature: "..avg_temperature.." deg C")
    print("Average humidity: "..avg_humidity.."%\n\r")

    acc_temperature = 0
    acc_humidity = 0
    measure_count = 0

    -- DISPLAY
    max7219.write2(2,math.floor(avg_temperature))
    max7219.write2(1,math.floor(avg_humidity))

    -- POST
    if wifi.sta.status() == 5 then

        con = nil
        con = net.createConnection(net.TCP, 0)
 
        con:on("receive", function(con, payloadout)
            if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                print("Posted OK to ThingSpeak!\n\r");
                con:close();
                collectgarbage();
            end
        end)
 
        con:on("connection", function(con, payloadout)
 
        -- Post data to Thingspeak
        con:send(
            "POST /update?api_key=" .. THINGSPEAK_CHANNEL_APIWRITEKEY .. 
            "&field1=" .. avg_temperature .. 
            "&field2=" .. avg_humidity .. 
            " HTTP/1.1\r\n" .. 
            "Host: api.thingspeak.com\r\n" .. 
            "Connection: close\r\n" .. 
            "Accept: */*\r\n" .. 
            "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n" .. 
            "\r\n")

        end)
        
        con:on("disconnection", function(con, payloadout)
            print("Disconnected!\n\r\n\r\n\r")
            collectgarbage();
        end)

        -- Connect to Thingspeak
        con:connect(80,'api.thingspeak.com')
    else
        print("Connecting...")
    end
end



print("Getting DHT sensor data every " .. (INTERVAL_DHT/1000) .." sec")
print("Stop DHT sensor by tmr.stop(0)\n\r")

print("Post to ThinkSpeak every " .. (INTERVAL_THINGSPEAK/1000) .." sec")
print("Stop posting by tmr.stop(1)\n\r")

srv=net.createServer(net.TCP, 10)
print("Web server created on " .. wifi.sta.getip())
print("\n\r------------------------------------------------\n\r")

srv:listen(80,function(conn)

    conn:on("receive",function(conn,request)
--        print(request)

        local buf = "";
        local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
        if(method == nil)then
            _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
        end
        local _GET = {}
        if (vars ~= nil)then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end

        if(_GET.blinkingLED == "ON")then
              lighton=0
              gpio.write(LED_PIN,gpio.LOW)
              tmr.start(2)
              print('LED is blinking at D0!\n\r')
        elseif(_GET.blinkingLED == "OFF")then
              tmr.stop(2)
              gpio.write(LED_PIN,gpio.HIGH)
              print('Stop LED blinking at D0!\n\r')
        end        
        
        if(_GET.intensity ~= nil)then
            intensity = math.floor(tonumber(_GET.intensity))
            if (intensity<0) then
                intensity = 0
                max7219.setIntensity(0)
            elseif (intensity >= 16) then
                intensity = 15
            end
            max7219.setIntensity(intensity)
            
            file.open('intensity.lua', "w")
            file.writeline(tostring(intensity))
            file.close()                
            
            print('Set intensity = '..intensity..'\n\r')
        end

        if(_GET.enableDisp == "ON")then
              max7219.shutdown(false)
              max7219.write2(2,math.floor(avg_temperature))
              max7219.write2(1,math.floor(avg_humidity))
              max7219.setIntensity(intensity)
              print('Display is turned ON!\n\r')
        elseif(_GET.enableDisp == "OFF")then
              max7219.shutdown(true)
              print('Display is turned OFF!\n\r')
        end

        if(_GET.ssid ~= nil and _GET.psw ~= nil)then
              print('SSID: '.._GET.ssid..'')
              print('Password: '.._GET.psw..'\n\r')
              
              file.open('credentials.lua', "w")
              file.writeline('SSID="'.._GET.ssid..'"')
              file.writeline('PASSWORD="'.._GET.psw..'"')
              file.close()                

              node.restart()
        end
        
        if(_GET.setWifi == "true")then
            conn:send('HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nCache-Control: private, no-store\r\n\r\n')
            conn:send('<!DOCTYPE HTML>')
            conn:send('<html><head><meta content="text/html;charset=utf-8">')
            conn:send('<title>NodeMCU ESP8266 WiFi setting</title></head>')
            conn:send('<body bgcolor="#ffe4c4">')
            conn:send('<h3><font color="green">')
            conn:send('<form><input type="text" name="ssid" value="'..SSID..'"> SSID<br><input type="password" name="psw" value="'..PASSWORD..'"> Password<br>')
            conn:send('<input type="submit" value="Set WiFi" onclick="return confirm(\'Are you sure to continue?\')"></form></h3>')
        else
            conn:send('HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nCache-Control: private, no-store\r\n\r\n')
            conn:send('<!DOCTYPE HTML>')
            conn:send('<html><head><meta content="text/html;charset=utf-8">')
            conn:send('<meta http-equiv="refresh" content="5; url=http://'..wifi.sta.getip()..'/">')
            conn:send('<title>NodeMCU ESP8266</title></head>')
            conn:send('<body bgcolor="#ffe4c4"><h2><font color="black">Temperature & Humidity monitor with DHT sensor</h2>')
            conn:send('<h3><font color="green">')
            conn:send('<input style="text-align: center"type="text"size=4 name="p"value="'..temperature..'"> &#8451; Temperature<br>')
            conn:send('<input style="text-align: center"type="text"size=4 name="j"value="'..humidity..'"> % Humidity<br></h3>')
            conn:send('<h2><font color="black"><br>Control over WebServer</h2>')
            conn:send('<h3><font color="green">')
            conn:send('Blinking LED  <a href=\"?blinkingLED=ON\"><button>ON</button></a>&nbsp;<a href=\"?blinkingLED=OFF\"><button>OFF</button></a></h3>')
            conn:send('<h2><font color="black"><br>Display setting</h2>')
            conn:send('<h3><font color="green">')
            conn:send('Enable <a href=\"?enableDisp=ON\"><button>ON</button></a>&nbsp;<a href=\"?enableDisp=OFF\"><button>OFF</button></a>')
            conn:send('<form>Intensity <input type="text" name="intensity" value="'..intensity..'" size=2>')
            conn:send(' <input type="submit" value="Set"></form></h3>')
            conn:send('<h2><font color="black"><br><a href="http://'..wifi.sta.getip()..'/?setWifi=true">WiFi setting</a></h2>')
        end
        


        conn:on("sent", function(conn)
            conn:close()
            collectgarbage();
        end)
    end)
end)

get_sensor_Data()
DisplayAndPost()
tmr.alarm(0, INTERVAL_DHT, tmr.ALARM_AUTO, function() get_sensor_Data() end)
tmr.alarm(1, INTERVAL_THINGSPEAK, tmr.ALARM_AUTO, function() DisplayAndPost() end)
