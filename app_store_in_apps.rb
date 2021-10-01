require "spaceship"

# exec("export FASTLANE_ITC_TEAM_ID=\"2280804\"")

app_id = "com.rallyreader.app.dev"

Spaceship::Tunes.login("jernejz@gmail.com")
Spaceship::Tunes.select_team
app = Spaceship::Application.find(app_id)

puts "📱 App: #{app_id}"

full_prices = Array[
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
tiers = Array[]
prices = Array[]

for i in 0..full_prices.size - 1
    full_price = full_prices.at(i)
    prices.append(full_price-0.01)
    tiers.append(i+1)
end

for i in 0..tiers.size - 1
  full_price = full_prices.at(i)
  tier = tiers.at(i)
  price = prices.at(i)
  product_id = "#{app_id}.inapp.credit.#{full_price}.A"
  
  puts "💰 Creating \"$#{price} Book Credit\""

  begin
    app.in_app_purchases.create!(
        type: Spaceship::Tunes::IAPType::CONSUMABLE, 
        versions: {
          'en-US': {
            name: "$#{price} Book Credit",
            description: "Book Credit for purchasing books."
          }
        },
        reference_name: "$#{price} Book Credit",
        product_id: product_id,
        cleared_for_sale: false,
        review_notes: "Product for tier #{tier}",
        review_screenshot: "iap.jpg", 
        pricing_intervals: 
        [
            {
              country: "WW",
              begin_date: nil,
              end_date: nil,
              tier: tier
            }
        ]
    )
  rescue => error
    puts error.message
  end

end
