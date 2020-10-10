require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'csv'

BASE_URL = "https://www.dealdash.com/"
NEW_SEARCH_URL = "https://www.dealdash.com/newsearch?"
BASE_AJAX_URL = "https://www.dealdash.com/ajax_get_page.php?page="
AUCTION_URL = "https://www.dealdash.com/battle.php?auction_id="

puts "start"

puts "1. searching auction ids..."
auction_items = (0..7).map do |page|
  puts "searching page #{page}..."
    begin
      url = "#{BASE_AJAX_URL}#{page}"
      doc = Nokogiri::HTML(open(url))
      doc.css('.auctionbox.product').map do |e|
        is_discount = e.css('ul li').first.attributes["class"].value.include?('discountpromo')
        auction_id = e.attributes['data-id'].value
        [auction_id, is_discount]
      end
    rescue
    end
end.compact.flatten(1)


doc = Nokogiri::HTML(open(BASE_URL, read_timeout: 300))

puts "init catgegory.."
auction_id_category_mapping = {}
doc.css(".categoryMenu").each do |e|
    category_name = e.content
    puts category_name
    query_id = e.attributes['data-query'].value

    if query_id == 'all' || query_id == 'new'
        next
    end

    url = "#{NEW_SEARCH_URL}cat=#{query_id}"

    page = 0
    loop do
        dest_url = "#{url}&page=#{page}"
        begin
            doc = Nokogiri::HTML(open(dest_url, read_timeout: 300))

            if doc.content == ""
                break
            end
            doc.css('.auctionbox.product').each do |e|
                auction_id = e.attributes['data-id'].value
                if auction_id_category_mapping[auction_id.to_i]
                    auction_id_category_mapping[auction_id.to_i] += ";#{category_name}"
                else
                    auction_id_category_mapping[auction_id.to_i] = category_name
                end
            end
        rescue
            puts "fail #{category_name}- page: #{page}"
        end  
        page += 1
    end
end

CSV.open("/home/ec2-user/tmp/one-#{Time.now.to_s}.csv", "wb") do |csv|
  csv << ["拍卖id", "商品名称", "立即购买价格", "是否50%折扣", "成交价", "获胜者参加竞拍的bids", "总成本价", "类别"]
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
        csv << [auction_id, auction_title, buy_it_now_price, is_discount, price, bids_placed, total_cost, auction_id_category_mapping[auction_id.to_i]]
      end
    rescue
      puts "error: #{auction_id}"
    end
  end
end

# require 'csv'
# CSV.open("/home/ec2-user/tmp/foo-#{Time.now.to_s}.csv", "wb") do |csv|
#   csv << ["id", "title", "remark"]
#   csv << ["a", "b", "c"]
# end
puts "end"
