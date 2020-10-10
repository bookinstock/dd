require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'csv'
require 'date'
require 'uri'
require 'net/http'
require 'json'
require "redis"

# redis = Redis.new(host: "0.0.0.0", port: 16379, db: 15)

BASE_URL = "https://www.dealdash.com/"

NEW_URL = "https://www.dealdash.com/gonzales.php?auctionDetailsIds="

BASE_AJAX_URL = "https://www.dealdash.com/ajax_get_page.php?page="

AUCTION_URL = "https://www.dealdash.com/battle.php?auction_id="


# REDIS_KEY_AUCTION_IDS = "auction_ids"

require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: 'rds-auction-test.cpmjco64gbxp.ap-northeast-1.rds.amazonaws.com',
  username: 'dbmaster',
  password: 'dciMzsmR98JomEM4tpR1',
  database: 'auction'
)

#  class CreateDealDashErrorTable < ActiveRecord::Migration[5.2]
#      def change
#          create_table :deal_dash_errors do |table|
#              table.integer :auction_id
#              table.string :message

#              table.timestamps
#          end
#          add_index(:deal_dash_errors, :auction_id)
#      end
# end

# class CreateDealDashRecordTable < ActiveRecord::Migration[5.2]
#     def change
#         create_table :deal_dash_records do |table|
#             table.integer :auction_id
#             table.decimal :price, precision: 10, scale: 2
#             table.string :time
#             table.string :user
#             table.string :action
            
#             table.timestamps
#         end
#         add_index(:deal_dash_records, :auction_id)
#         add_index(:deal_dash_records, :price)
#     end
# end

# CreateDealDashRecordTable.migrate(:up)

# CreateDealDashErrorTable.migrate(:up)

# class DealDashAddTitle < ActiveRecord::Migration[5.2]
#   def change
#     add_column :deal_dash_records, :title, :string
#   end
# end

# class DealDashAddUserId < ActiveRecord::Migration[5.2]
#     def change
#       add_column :deal_dash_records, :user_id, :string
#       add_index(:deal_dash_records, :user_id)
#     end
#   end

# class CreateDealDashAuctionTable < ActiveRecord::Migration[5.2]
#     def change
#         create_table :deal_dash_auctions do |table|
#             table.integer :auction_id
#             table.string :title
#             table.string :buy_it_now_price
            
#             table.timestamps
#         end
#         add_index(:deal_dash_auctions, :auction_id)
#     end
# end


# class CreateDealDashUserTable < ActiveRecord::Migration[5.2]
#     def change
#         create_table :deal_dash_users do |table|
#             table.string :user_id
#             table.string :user_name
#             table.string :avatar_url
#             table.string :bio
#             table.string :register_date
#             table.string :first_bid
#             table.string :winning_limit_status
#             table.string :state
            
#             table.timestamps
#         end
#         add_index(:deal_dash_users, :user_id)
#     end
# end


# CreateDealDashUserTable.migrate(:up)



class DealDashError < ActiveRecord::Base
end

class DealDashRecord < ActiveRecord::Base
end

class DealDashAuction < ActiveRecord::Base
end

class DealDashUser < ActiveRecord::Base
end


# get_auction_ids_from_web_page = lambda do
#     doc = Nokogiri::HTML(open(BASE_URL, read_timeout: 300))
#     doc.css('.auctionbox.product').map { |e| e.attributes['data-id'].value }
# end




get_auction_ids_from_web_page2 = lambda do
    (0..3).map do |page|
        puts "searching page #{page}..."
        begin
            url = "#{BASE_AJAX_URL}#{page}"
            Nokogiri::HTML(open(url)).css('.auctionbox.product').map do |e|
                auction_id = e.attributes['data-id'].value
                title = e.css('.productname')[0].attributes['aria-label'].value

                begin
                    unless DealDashAuction.find_by(auction_id: auction_id)
                        url = "#{AUCTION_URL}#{auction_id}"
                        doc = Nokogiri::HTML(open(url))
                        auction_title = doc.css('.auctionTitle').first.content
                        buy_it_now_price = doc.css('.retailPriceTitle span').first.content
                        
                        DealDashAuction.create(
                            auction_id: auction_id,
                            title: auction_title,
                            buy_it_now_price: buy_it_now_price
                        )
                    end
                rescue
                end

                auction_id
            end
        rescue
        end
    end.compact.flatten
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

call_user_api = lambda do |auction_id, user_id|
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
        get_auction_ids_from_web_page2.call()
    rescue
        puts "fail"
    end
    sleep(100)
end


puts "end"
