require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'csv'
require 'date'
require 'uri'
require 'net/http'
require 'json'
require "redis"

redis = Redis.new(host: "0.0.0.0", port: 16379, db: 15)

BASE_URL = "https://www.dealdash.com/"

NEW_URL = "https://www.dealdash.com/gonzales.php?auctionDetailsIds="

REDIS_KEY_AUCTION_IDS = "auction_ids"


get_auction_ids_from_web_page = lambda do
    doc = Nokogiri::HTML(open(BASE_URL, read_timeout: 300))
    doc.css('.auctionbox.product').map { |e| e.attributes['data-id'].value }
end

get_auction_ids_from_redis = lambda do
    redis.smembers(REDIS_KEY_AUCTION_IDS) || []
end

save_auction_ids_to_redis = lambda do |auction_ids|
    redis.sadd(REDIS_KEY_AUCTION_IDS, auction_ids)
end

call_api = lambda do |auction_ids|
    url = "#{NEW_URL}#{auction_ids.join(',')}"
    url = URI.parse(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.read_timeout = 300
    parsed_body = nil
    http.request_get(url) {|response| parsed_body = JSON[response.body]}
    parsed_body["auctionsDetails"]
end

puts "start"

if ARGV[0] == "out"
    filename = ARGV[1]

    Dir.mkdir filename

    auction_ids = redis.smembers(REDIS_KEY_AUCTION_IDS)

    auction_ids.each do |auction_id|
        CSV.open("#{filename}/#{filename}-#{auction_id}.csv", "wb") do |csv|
            csv << ["auction_id", "price", "time", "user", "action"]
            values = redis.hvals(auction_id)
            values.each do |value|
                puts "write to csv -> #{auction_id}-#{value}"
                csv << value.split(";")
            end
        end
    end
else
    loop do
        new_auction_ids = get_auction_ids_from_web_page.call()
        old_auction_ids = get_auction_ids_from_redis.call()
        new_auction_ids = new_auction_ids - old_auction_ids
        if not new_auction_ids.empty?
            save_auction_ids_to_redis.call(new_auction_ids)
        end
        auction_ids = new_auction_ids + old_auction_ids
        auction_details = call_api.call(auction_ids)

        auction_details.each do |data|
            data['history'].each do |(a,b,c,d)|
                auction_id = data['auctionId']
                value = [auction_id, a, b, c, d].join(';')
                redis.hmset(auction_id, a, value)
                puts "write to redis -> #{auction_id}-#{a}-#{value}"
            end
        end
        sleep(9)
    end
end


puts "end"
