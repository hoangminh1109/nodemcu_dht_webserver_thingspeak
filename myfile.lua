--############
--# Settings #
--############
LED_PIN=0
DHT_PIN=1
LED2_PIN=2

INTERVAL_BLINKING=500
INTERVAL_DHT=5000
INTERVAL_THINGSPEAK=60000

THINGSPEAK_CHANNEL_APIWRITEKEY = "ZRDUKPYQ0QV7WWX2"
THINGSPEAK_CHANNEL_TEMP_FIELD = "field1"
THINGSPEAK_CHANNEL_HUMID_FIELD = "field2"


--################
--# END settings #
--################

-- BLINKING AT D0
lighton=0
gpio.mode(LED_PIN,gpio.OUTPUT)
tmr.alarm(0,INTERVAL_BLINKING,tmr.ALARM_AUTO,function()
	if lighton==0 then
		lighton=1
		gpio.write(LED_PIN,gpio.HIGH)
	else
		lighton=0
		gpio.write(LED_PIN,gpio.LOW)
	end
end)

print("Blinking the led at D0 every 0.5 sec")
print("Stop blinking by tmr.stop(0)\n\r")

--####################
--# Global variables #
--################

temperature = 0
humidity = 0

--####################
--#END Global variables #
--####################

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
            print("Temperature: "..temperature.." deg C")
            print("Humidity: "..humidity.."%\n\r")
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
function postThingSpeak()
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
            "&field1=" .. temperature .. 
            "&field2=" .. humidity .. 
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
print("Stop DHT sensor by tmr.stop(1)\n\r")

print("Post to ThinkSpeak every " .. (INTERVAL_THINGSPEAK/1000) .." sec")
print("Stop posting by tmr.stop(2)\n\r")

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

        if(_GET.pinD2 == "ON")then
              gpio.write(LED2_PIN, gpio.HIGH);
              print('LED at D2 turned ON!\n\r')
        elseif(_GET.pinD2 == "OFF")then
              gpio.write(LED2_PIN, gpio.LOW);
              print('LED at D2 turned OFF!\n\r')
        end        
        
        conn:send('HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nCache-Control: private, no-store\r\n\r\n')
        conn:send('<!DOCTYPE HTML>')
        conn:send('<html><head><meta content="text/html;charset=utf-8">')
        conn:send('<meta http-equiv="refresh" content="5; url=http://'..wifi.sta.getip()..'/">')
        conn:send('<title>NodeMCU ESP8266</title></head>')
        conn:send('<body bgcolor="#ffe4c4"><h2><font color="black">Temperature & Humidity monitor with DHT sensor</h2>')
        conn:send('<h3><font color="green">')
        conn:send('<input style="text-align: center"type="text"size=4 name="p"value="'..temperature..'"> &#8451; Temperature<br>')
        conn:send('<input style="text-align: center"type="text"size=4 name="j"value="'..humidity..'"> % Humidity<br><br></h3>')
        conn:send('<h2><font color="black">Control over WebServer</h2>')
        conn:send('<h3><font color="green">')
        conn:send('D2 LED  <a href=\"?pinD2=ON\"><button>ON</button></a>&nbsp;<a href=\"?pinD2=OFF\"><button>OFF</button></a></h3>')

        conn:on("sent", function(conn)
            conn:close()
            collectgarbage();
        end)
    end)
end)

get_sensor_Data()
postThingSpeak()
tmr.alarm(1, INTERVAL_DHT, tmr.ALARM_AUTO, function() get_sensor_Data() end)
tmr.alarm(2, INTERVAL_THINGSPEAK, tmr.ALARM_AUTO, function() postThingSpeak() end)
