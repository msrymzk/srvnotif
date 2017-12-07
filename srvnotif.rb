#!/usr/bin/env ruby
require 'rubygems'
require 'twitter'
require 'geoip'
require 'json'

# e,g,
# IN:
# Jul 13 23:59:44 www2147ue kernel: [ip4](I) IN=eth0 OUT= MAC=52:54:05:00:21:47:74:8e:f8:63:52:41:08:00 SRC=113.111.58.240 DST=219.94.240.161 LEN=60 TOS=0x00 PREC=0x00 TTL=46 ID=13054 DF PROTO=TCP SPT=54563 DPT=8081 WINDOW=14520 RES=0x00 SYN URGP=0 
# OUT:
# {"MON"=>"Jul", "DAY"=>"13", "TIME"=>"23:59:44", "HOST"=>"www2147ue", "[ip4](I)"=>"", "IN"=>"eth0", "OUT"=>"", "MAC"=>"52:54:05:00:21:47:74:8e:f8:63:52:41:08:00", "SRC"=>"113.111.58.240", "DST"=>"219.94.240.161", "LEN"=>"60", "TOS"=>"0x00", "PREC"=>"0x00", "TTL"=>"46", "ID"=>"13054", "DF"=>"", "PROTO"=>"TCP", "SPT"=>"54563", "DPT"=>"8081", "WINDOW"=>"14520", "RES"=>"0x00", "SYN"=>"", "URGP"=>"0"}
def parsemsg(msg)
 tbl = nil
 if /\[ip\w*\]/ =~ msg
  ss = msg.strip.split(' kernel: ')
  tbl = Hash[["MON", "DAY", "TIME", "HOST"].zip(ss[0].split(nil))]
  sss = ss[1].split(nil).map{|i| ii = i.split("="); ii.size == 1 ? ii << "" : ii}
  tbl.merge!(Hash[*sss.flatten(1)])
 end
 return tbl
end

def mkmsg(tbl)
   proto = tbl["PROTO"]
   if proto == "TCP"
    flgs = ["NS", "CWR", "ECE", "URG", "ACK", "PSH", "RST", "SYN", "FIN"].select{|i| tbl[i]}
    proto = proto + ":" + flgs.reduce{|a,b| a + "/" + b} if flgs.length > 0
   end
   msg = sprintf("[%s] %s:%s >> %s:%s (%s)", tbl["TIME"], tbl["SRC"], tbl["SPT"], "", tbl["DPT"], proto)
end



=begin
config.json
{
  "APP_KEY":"your app key",
  "APP_SECRET":"your app secret",
  "OAUTH_TOKEN":"your oauth token",
  "OAUTH_TOKEN_SECRET":"your oauth token secret"
}
=end
key = {}
File.open("config.json") do |file|
  key = JSON.load(file)
end

# initialize GeoIP
datfile = File.join(File.expand_path(File.dirname(__FILE__)), 'GeoLiteCity.dat')
gi = GeoIP.new(datfile)

cnt = 0
while true
 puts $0 + ' +++++ ' + Time.now.to_s
 STDOUT.flush
 File.open(ARGV[0]) do |file|
  while msg = file.gets
   res = parsemsg(msg)
   if not res
     print "OTHER MESSAGE? -> " + msg
     next
   end
   s = mkmsg(res)
   s = s + " +#{cnt} access" if cnt > 0
   puts s if s.size > 0
   begin
    tw = Twitter::REST::Client.new do |config|
      config.consumer_key = key['APP_KEY']
      config.consumer_secret = key['APP_SECRET']
      config.access_token = key['OAUTH_TOKEN']
      config.access_token_secret = key['OAUTH_TOKEN_SECRET']
    end
    c = gi.country(res["SRC"])
    if c
      tw.update(s, :lat => c.latitude, :long => c.longitude, :display_coordinates => true) if s.size > 0
    else
      tw.update(s) if s.size > 0
    end
   rescue => e
    cnt = cnt + 1
    p e
   else
    cnt = 0
   end
   STDOUT.flush
   sleep 1
  end
 end
 sleep 1
end
puts $0 + ' ----- ' + Time.now.to_s
STDOUT.flush
