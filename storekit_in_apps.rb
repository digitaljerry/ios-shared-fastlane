
require 'json'

app_id = "com.rallyreader.app.dev"

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

products = []

for i in 0..tiers.size - 1
    tier = tiers.at(i)
    price = prices.at(i)

    product_id = "#{app_id}.inapp.credit.#{tier}.A"
    random_identifier = ([*('A'..'Z'),*('0'..'9')]-%w(0 1 I O)).sample(8).join
  
    puts "💰 Parsing \"$#{price} Book Credit Top-up\""

    begin
        product = {
            "displayPrice" => "#{price}",
            "familyShareable" => false,
            "internalID" => "#{random_identifier}",
            "localizations" => [
              {
                "description" => "Book Credit Top-up for purchasing books.",
                "displayName" => "$#{price} Book Credit Top-up",
                "locale" => "en_US"
              }
            ],
            "productID" => "#{product_id}",
            "referenceName" => "$#{price} Book Credit Top-up",
            "type" => "Consumable"
          }
        products.append(product)
    rescue => error
        puts error.message
    end

    File.open("Configuration.json","w") do |f|
        f.write(JSON.pretty_generate(products))
    end

end

puts products

