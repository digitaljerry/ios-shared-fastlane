
require 'uri'
require 'net/http'
require 'openssl'

app_id = "com.rallyreader.app.dev"

url = URI("https://api.revenuecat.com/v1/receipts")

http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true

tiers = Array[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    55,
    60,
    65,
    70,
    75,
    80,
    85,
    90,
    95,
    100
]
prices = Array[]

for i in 0..tiers.size - 1
    tier = tiers.at(i)
    prices.append(tier-0.01)
end

puts "📱 App: #{app_id}"

revenucat_api_token = ENV["REVENUECAT_API_KEY"]

if revenucat_api_token == nil
    puts "REVENUECAT_API_KEY env variable not set"
    exit(1)
end

for i in 0..tiers.size - 1
    tier = tiers.at(i)
    price = prices.at(i)

    product_id = "#{app_id}.inapp.credit.#{tier}.Z"
  
    puts "💰 Creating \"$#{price} Book Credit Top-up\""

    begin
        # request = Net::HTTP::Post.new(url)
        # request["Accept"] = 'application/json'
        # request["Content-Type"] = 'application/json'
        # request["X-Platform"] = 'ios'
        # request["Authorization"] = 'Bearer #{revenucat_api_token}'
        # request.body = "{\"product_id\":\"#{product_id}\",\"price\":#{price},\"currency\":\"USD\",\"is_restore\":\"false\"}"

        # response = http.request(request)
        # puts response.read_body
    rescue => error
        puts error.message
    end

end
