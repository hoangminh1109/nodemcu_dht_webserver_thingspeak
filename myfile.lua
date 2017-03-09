--############
--# Settings #
--############
LED_PIN=0
DHT_PIN=1

INTERVAL_BLINKING=500
INTERVAL_DHT=60000

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



-- DHT SENSOR AT D1
temperature = 0
humidity = 0

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
            print("Humidity: "..humidity.."%")
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
        -- Stop the loop
--        tmr.stop(1)

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
 
        -- Get sensor data
        get_sensor_Data() 

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
        

--        con:on("sent",function(con)
--            print("Sent!")
--            con:close();
--            collectgarbage();
--        end)
 
        con:on("disconnection", function(con, payloadout)
            print("Disconnected!\n\r\n\r\n\r")
--            con:close();
            collectgarbage();
--            print("Going to deep sleep for "..(time_between_sensor_readings/1000).." seconds")
--            node.dsleep(time_between_sensor_readings*1000) 
        end)

        -- Connect to Thingspeak
        con:connect(80,'api.thingspeak.com')
    else
        print("Connecting...")
    end
end

print("Blinking the led at D0 every 0.5 sec")
print("Reads the DHT sensor and Post to ThinkSpeak every " .. (INTERVAL_DHT/1000) .." sec")
print("Stop blinking by tmr.stop(0); Stop DHT sensor by tmr.stop(1)")
print("\n\r")

postThingSpeak()

tmr.alarm(1, INTERVAL_DHT, tmr.ALARM_AUTO, function() postThingSpeak() end)

srv=net.createServer(net.TCP, 10)
print("Server created on " .. wifi.sta.getip())
print("\n\r\n\r")

srv:listen(80,function(conn)

    conn:on("receive",function(conn,request)
        print(request)
        
        conn:send('HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nCache-Control: private, no-store\r\n\r\n')
        conn:send('<!DOCTYPE HTML>')
        conn:send('<html><head><meta content="text/html;charset=utf-8">')
        conn:send('<meta http-equiv="refresh" content="20">')
        conn:send('<title>NodeMCU ESP8266</title></head>')
        conn:send('<body bgcolor="#ffe4c4"><h2>Temperature & Humidity monitor with DHT sensor</h2>')
        conn:send('<h3><font color="green">')
        conn:send('<input style="text-align: center"type="text"size=4 name="p"value="'..temperature..'"> &#8451; Temperature<br>')
        conn:send('<input style="text-align: center"type="text"size=4 name="j"value="'..humidity..'"> % Humidity<br><br>')

        conn:on("sent", function(conn) conn:close() end)
    end)
end)

