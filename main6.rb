require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'csv'
require 'date'
require 'uri'
require 'net/http'
require 'json'
require "redis"
require 'date'

redis = Redis.new(host: "0.0.0.0", port: 6379, db: 15)

BASE_URL = "https://www.dealdash.com/"

NEW_URL = "https://www.dealdash.com/gonzales.php?auctionDetailsIds="

BASE_AJAX_URL = "https://www.dealdash.com/ajax_get_page.php?page="

AUCTION_URL = "https://www.dealdash.com/battle.php?auction_id="



# REDIS_KEY_AUCTION_IDS = "auction_ids"

require 'active_record'

# ActiveRecord::Base.establish_connection(
#   adapter: 'mysql2',
#   host: 'rds-auction-test.cpmjco64gbxp.ap-northeast-1.rds.amazonaws.com',
#   username: 'dbmaster',
#   password: 'dciMzsmR98JomEM4tpR1',
#   database: 'auction'
# )

ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: '127.0.0.1',
  username: 'mars_dbuser',
  password: '123456!',
  database: 'deal_dash'
)


class DealDashError < ActiveRecord::Base
end

class DealDashRecord < ActiveRecord::Base
end

class DealDashAuction < ActiveRecord::Base
end

class DealDashUser < ActiveRecord::Base
end


# ====

# DealDashUser.all.each do |user|  
#     user.revised_register_date = DateTime.strptime(user.register_date,'%s')
#     user.save
#     print(".")
# end

# print "end"

# ====



# get_auction_ids_from_web_page = lambda do
#     doc = Nokogiri::HTML(open(BASE_URL, read_timeout: 300))
#     doc.css('.auctionbox.product').map { |e| e.attributes['data-id'].value }
# end




get_auction_ids_from_web_page2 = lambda do
    id_title_maping = {}
    auction_ids = (0..4).map do |page|
        puts "searching page #{page}..."
        begin
            url = "#{BASE_AJAX_URL}#{page}"
            Nokogiri::HTML(open(url)).css('.auctionbox.product').map do |e|
                auction_id = e.attributes['data-id'].value
                title = e.css('.productname')[0].attributes['aria-label'].value
                id_title_maping[auction_id] = title

                # begin
                #     unless DealDashAuction.find_by(auction_id: auction_id)
                #         url = "#{AUCTION_URL}#{auction_id}"
                #         doc = Nokogiri::HTML(open(url))
                #         auction_title = doc.css('.auctionTitle').first.content
                #         buy_it_now_price = doc.css('.retailPriceTitle span').first.content
                        
                #         DealDashAuction.create(
                #             auction_id: auction_id,
                #             title: auction_title,
                #             buy_it_now_price: buy_it_now_price
                #         )
                #     end
                # rescue
                # end

                auction_id
            end
        rescue
        end
    end.compact.flatten

    [auction_ids, id_title_maping]
end


# get_auction_ids_from_redis = lambda do
#     redis.smembers(REDIS_KEY_AUCTION_IDS) || []
# end

# save_auction_ids_to_redis = lambda do |auction_ids|
#     redis.sadd(REDIS_KEY_AUCTION_IDS, auction_ids)
# end

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

call_user_api = lambda do |auction_id, user|
    url = "https://www.dealdash.com/api/v1/auction/extraData/#{auction_id}/#{user}"
    url = URI.parse(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.read_timeout = 300
    parsed_body = nil
    http.request_get(url) {|response| parsed_body = JSON[response.body]}
    parsed_body.first
end

puts "start"

loop do
    begin
        auction_ids, id_title_maping = get_auction_ids_from_web_page2.call()
        auction_details = call_api.call(auction_ids)

        auction_details.each do |data|
            begin
                data['history'].each do |(price, time, user, action)|
                    auction_id = data['auctionId']
                    price = price.to_d
                    print "."
                    begin
                        user_id = redis.get("dealdash:#{auction_id}:#{user}")
                        unless user_id
                            begin
                                user_data = call_user_api.call(auction_id, user)
                                user_id = user_data["user_id"]
                                unless DealDashUser.find_by(user_id: user_id)
                                    DealDashUser.create(
                                        user_id: user_id,
                                        user_name: user_data["user_name"],
                                        avatar_url: user_data["avatar_url"],
                                        bio: user_data["bio"],
                                        register_date: user_data["register_date"],
                                        revised_register_date: DateTime.strptime(user_data["register_date"],'%s'),
                                        first_bid: user_data["first_bid"],
                                        winning_limit_status: user_data["winning_limit_status"],
                                        state: user_data["state"],
                                    )
                                end
                                redis.set("dealdash:#{auction_id}:#{user}", user_id)
                            rescue
                            end
                        end
                        record = DealDashRecord.find_by(auction_id: auction_id, price: price)
                        unless record
                            record = DealDashRecord.create(
                                auction_id: auction_id,
                                title: id_title_maping[auction_id.to_s],
                                price: price, 
                                time: time, 
                                user: user, 
                                action: action,
                            )
                        end
                        record.user_id = user_id
                        record.save
                    rescue
                    end
                end
            rescue
            end
        end
    rescue
        puts "fail"
    end
    sleep(15)
end


puts "end"
