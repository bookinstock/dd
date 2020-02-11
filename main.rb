require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'csv'

BASE_AJAX_URL = "https://www.dealdash.com/ajax_get_page.php?page="
AUCTION_URL = "https://www.dealdash.com/battle.php?auction_id="

puts "start"

puts "1. searching auction ids..."
auction_items = (0..7).map do |page|
  puts "searching page #{page}..."
  url = "#{BASE_AJAX_URL}#{page}"
  doc = Nokogiri::HTML(open(url))
  doc.css('.auctionbox.product').map do |e|
    is_discount = e.css('ul li').first.attributes["class"].value.include?('discountpromo')
    auction_id = e.attributes['data-id'].value
    [auction_id, is_discount]
  end
end.flatten(1)

CSV.open("./foo.csv", "wb") do |csv|
  csv << ["拍卖id", "商品名称", "立即购买价格", "是否50%折扣", "成交价", "获胜者参加竞拍的bids", "总成本价"]
  puts "2. searching auction page..."
  auction_items.each do |(auction_id, is_discount)|
    puts "searching auction id = #{auction_id}"
    begin
      url = "#{AUCTION_URL}#{auction_id}"
      doc = Nokogiri::HTML(open(url))
      auction_title = doc.css('.auctionTitle').first.content
      buy_it_now_price = doc.css('.retailPriceTitle span').first.content
      doc.css('.innerWonListContainer table tbody tr').each do |e|
        price, bids_placed, total_cost = e.css('td')[-3..-1].map {|ee| ee.content}
        csv << [auction_id, auction_title, buy_it_now_price, is_discount, price, bids_placed, total_cost]
      end
    rescue
      puts "error: #{auction_id}"
    end
  end
end

puts "end"
