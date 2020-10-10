require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'csv'
require 'date'
require 'uri'
require 'net/http'
require 'json'
# require 'mechanize'
start = Time.now

BASE_URL = "https://www.dealdash.com/"
BASE_AJAX_URL = "https://www.dealdash.com/ajax_get_page.php?page="
BASE_AUCTION_IDS_URL = "https://www.dealdash.com/gonzales.php?"
NEW_SEARCH_URL = "https://www.dealdash.com/newsearch?"


doc = Nokogiri::HTML(open(BASE_URL, read_timeout: 300))
pages = doc.css('.selectpage').size

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

auction_ids = []

records = (0..pages).map do |page|
  puts "searching page #{page}..."
  url = "#{BASE_AJAX_URL}#{page}"
  doc = Nokogiri::HTML(open(url, read_timeout: 300))
  doc.css('.auctionbox.product').map do |e|
    begin
        auction_id = e.attributes['data-id'].value
        puts "searching auction id = #{auction_id}"
        auction_ids << auction_id
        name = e.css('.productname span').first.attributes["data-name"].value
        first_li = e.css('ul li').first
        price = first_li.content()
        is_discount = first_li.attributes["class"].value.include?('discountpromo')
        [auction_id.to_i, name, price, is_discount]
    rescue
        "puts error"
    end
  end
end.flatten(1)


puts "auction_ids #{auction_ids.inspect}"

now = DateTime.now
url = "#{BASE_AUCTION_IDS_URL}idlist=#{auction_ids.join(",")}&_t=#{now.strftime('%Q')}"
url = URI.parse(url)

http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true
http.read_timeout = 300
parsed_body = nil

begin
    http.request_get(url) {|response| parsed_body = JSON[response.body]}
rescue
    http.request_get(url) {|response| parsed_body = JSON[response.body]}
end


t = now.to_time
t += 1

auction_id_time_mapping = parsed_body["auctions"].map do |e|
    [e["i"], e["t"] <= 0 ? "sold" : t + e["t"]]
end.to_h


CSV.open("/home/ec2-user/tmp/two-#{start}.csv", "wb") do |csv|
    csv << ["id", "title", "status", "is_discount"]

    records.each do |record|
        auction_id, name, price, is_discount = record
        value = auction_id_time_mapping[auction_id].to_s
        if value == "sold"
            status = "sold_#{price}"
        else
            if price == "$0.00"
                status = "starts_at_#{value}"
            else
                status = "open"
            end
        end

        category = auction_id_category_mapping[auction_id]

        csv << [auction_id, name, status, is_discount, category]
    end
end

puts "end"