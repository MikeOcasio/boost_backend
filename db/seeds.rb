# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting database seeding..."

# Clean up existing data (for development)
if Rails.env.development?
  puts "🧹 Cleaning existing data..."
  [Review, PaypalPayout, PaymentApproval, OrderProduct, Order,
   OrderRejection, Cart, UserReward, PlatformCredential, UserPlatform,
   ProductPlatform, Product, Category, SubPlatform, Platform,
   SkillmasterApplication, Promotion, Notification, Contractor, User].each(&:delete_all)
end

# 1. Create Users (foundation)
puts "👥 Creating users..."

admin = User.create!(
  email: "admin@ravenboost.com",
  password: "SecureAdmin123!",
  password_confirmation: "SecureAdmin123!",
  first_name: "Admin",
  last_name: "User",
  role: "admin",
  confirmed_at: Time.current
)

skillmaster1 = User.create!(
  email: "skillmaster1@ravenboost.com",
  password: "SecureSkill123!",
  password_confirmation: "SecureSkill123!",
  first_name: "John",
  last_name: "Smith",
  role: "skillmaster",
  confirmed_at: Time.current
)

skillmaster2 = User.create!(
  email: "skillmaster2@ravenboost.com",
  password: "SecureSkill123!",
  password_confirmation: "SecureSkill123!",
  first_name: "Sarah",
  last_name: "Johnson",
  role: "skillmaster",
  confirmed_at: Time.current
)

customer1 = User.create!(
  email: "customer1@ravenboost.com",
  password: "SecureCustomer123!",
  password_confirmation: "SecureCustomer123!",
  first_name: "Mike",
  last_name: "Wilson",
  role: "customer",
  confirmed_at: Time.current
)

customer2 = User.create!(
  email: "customer2@ravenboost.com",
  password: "SecureCustomer123!",
  password_confirmation: "SecureCustomer123!",
  first_name: "Emma",
  last_name: "Davis",
  role: "customer",
  confirmed_at: Time.current
)

User.create!(
  email: "dev@ravenboost.com",
  password: "SecureDev123!",
  password_confirmation: "SecureDev123!",
  first_name: "Dev",
  last_name: "User",
  role: "dev",
  confirmed_at: Time.current
)

puts "✅ Created #{User.count} users"

# 2. Create Contractors for skillmasters
puts "💼 Creating contractors..."

contractor1 = Contractor.create!(
  user: skillmaster1,
  paypal_payout_email: "skillmaster1@paypal.com",
  paypal_email_verified: true,
  paypal_email_verified_at: Time.current,
  available_balance: 150.00,
  pending_balance: 75.00,
  total_earned: 500.00
)

contractor2 = Contractor.create!(
  user: skillmaster2,
  paypal_payout_email: "skillmaster2@paypal.com",
  paypal_email_verified: true,
  paypal_email_verified_at: Time.current,
  available_balance: 200.00,
  pending_balance: 100.00,
  total_earned: 800.00
)

puts "✅ Created #{Contractor.count} contractors"

# 3. Create Platforms and Sub-platforms
puts "🎮 Creating platforms..."

valorant_platform = Platform.create!(
  name: "Valorant",
  has_sub_platforms: true
)

lol_platform = Platform.create!(
  name: "League of Legends",
  has_sub_platforms: true
)

cs2_platform = Platform.create!(
  name: "Counter-Strike 2",
  has_sub_platforms: false
)

# Create sub-platforms for Valorant
["Competitive", "Unrated", "Spike Rush"].each do |sub_name|
  SubPlatform.create!(
    platform: valorant_platform,
    name: sub_name
  )
end

# Create sub-platforms for LoL
["Ranked Solo/Duo", "Ranked Flex", "Normal Draft"].each do |sub_name|
  SubPlatform.create!(
    platform: lol_platform,
    name: sub_name
  )
end

puts "✅ Created #{Platform.count} platforms and #{SubPlatform.count} sub-platforms"

# 4. Create Categories
puts "📂 Creating categories..."

fps_category = Category.create!(
  name: "FPS Games",
  description: "First-person shooter games",
  is_active: true
)

moba_category = Category.create!(
  name: "MOBA Games",
  description: "Multiplayer Online Battle Arena games",
  is_active: true
)

puts "✅ Created #{Category.count} categories"

# 5. Create Products with platforms
puts "🛍️ Creating products..."

valorant_boost = Product.new(
  name: "Valorant Rank Boost",
  description: "Professional Valorant rank boosting service from Iron to Radiant",
  price: 25.00,
  category: fps_category,
  is_active: true,
  most_popular: true,
  tag_line: "Climb the ranks with pros",
  features: ["Fast delivery", "Professional players", "24/7 support", "Safe account"],
  is_priority: true
)
valorant_boost.platforms << valorant_platform
valorant_boost.save!

lol_boost = Product.new(
  name: "League of Legends Boost",
  description: "Expert LoL rank boosting from Iron to Challenger",
  price: 30.00,
  category: moba_category,
  is_active: true,
  tag_line: "Reach your dream rank",
  features: ["Experienced players", "Fast completion", "Safe methods", "Money back guarantee"]
)
lol_boost.platforms << lol_platform
lol_boost.save!

cs2_boost = Product.new(
  name: "CS2 Premier Boost",
  description: "Counter-Strike 2 Premier rank boosting service",
  price: 35.00,
  category: fps_category,
  is_active: true,
  tag_line: "Dominate the competition"
)
cs2_boost.platforms << cs2_platform
cs2_boost.save!

valorant_coaching = Product.new(
  name: "Valorant Coaching",
  description: "One-on-one coaching sessions with professional players",
  price: 50.00,
  category: fps_category,
  is_active: true,
  tag_line: "Learn from the best"
)
valorant_coaching.platforms << valorant_platform
valorant_coaching.save!

puts "✅ Created #{Product.count} products"

# 6. Product-Platform relationships are already created above
puts "🔗 Product-platform relationships created with products"

# 7. Create Platform Credentials for Users
puts "🔑 Creating platform credentials..."

PlatformCredential.create!(
  user: skillmaster1,
  platform: valorant_platform,
  sub_platform: valorant_platform.sub_platforms.find_by(name: "Competitive"),
  username: "ProGamer123",
  password: "encrypted_password_1"
)

PlatformCredential.create!(
  user: skillmaster2,
  platform: lol_platform,
  sub_platform: lol_platform.sub_platforms.find_by(name: "Ranked Solo/Duo"),
  username: "LoLQueen",
  password: "encrypted_password_2"
)

PlatformCredential.create!(
  user: customer1,
  platform: valorant_platform,
  sub_platform: valorant_platform.sub_platforms.find_by(name: "Competitive"),
  username: "CasualGamer",
  password: "encrypted_password_3"
)

puts "✅ Created #{PlatformCredential.count} platform credentials"

# 8. Create User-Platform associations
puts "🎯 Creating user-platform associations..."

UserPlatform.create!(user: skillmaster1, platform: valorant_platform)
UserPlatform.create!(user: skillmaster1, platform: cs2_platform)
UserPlatform.create!(user: skillmaster2, platform: lol_platform)
UserPlatform.create!(user: customer1, platform: valorant_platform)
UserPlatform.create!(user: customer2, platform: lol_platform)

puts "✅ Created #{UserPlatform.count} user-platform associations"

# 9. Create Promotions
puts "🎫 Creating promotions..."

Promotion.create!(
  code: "WELCOME10",
  discount_percentage: 10.0,
  start_date: 1.month.ago,
  end_date: 1.month.from_now
)

Promotion.create!(
  code: "SUMMER25",
  discount_percentage: 25.0,
  start_date: Time.current,
  end_date: 3.months.from_now
)

puts "✅ Created #{Promotion.count} promotions"

# 11. Create Orders with pending states
puts "📦 Creating orders..."

# Pending order 1
pending_order1 = Order.create!(
  user: customer1,
  state: "open",
  total_price: 25.00,
  price: 25.00,
  internal_id: SecureRandom.hex(5),
  payment_status: "pending"
)

# Pending order 2
pending_order2 = Order.create!(
  user: customer2,
  state: "open",
  total_price: 30.00,
  price: 30.00,
  internal_id: SecureRandom.hex(5),
  payment_status: "pending"
)

# Pending order 3
pending_order3 = Order.create!(
  user: customer1,
  state: "open",
  total_price: 50.00,
  price: 50.00,
  internal_id: SecureRandom.hex(5),
  payment_status: "pending"
)

puts "✅ Created #{Order.count} orders"

# 12. Create Order Products
puts "🛒 Creating order products..."

OrderProduct.create!(order: pending_order1, product: valorant_boost, quantity: 1, price: 25.00)
OrderProduct.create!(order: pending_order2, product: lol_boost, quantity: 1, price: 30.00)
OrderProduct.create!(order: pending_order3, product: valorant_coaching, quantity: 1, price: 50.00)

puts "✅ Created #{OrderProduct.count} order products"

# 13. Create Payment Approvals
puts "💳 Creating payment approvals..."

PaymentApproval.create!(
  order: pending_order1,
  status: "pending"
)

PaymentApproval.create!(
  order: pending_order2,
  status: "pending"
)

puts "✅ Created #{PaymentApproval.count} payment approvals"

# 14. Create PayPal Payouts
puts "💰 Creating PayPal payouts..."

PaypalPayout.create!(
  contractor: contractor1,
  amount: 50.00,
  paypal_payout_batch_id: "BATCH_123",
  paypal_payout_item_id: "ITEM_123",
  status: "success",
  paypal_response: { "status" => "SUCCESS", "time_completed" => Time.current }
)

PaypalPayout.create!(
  contractor: contractor2,
  amount: 75.00,
  paypal_payout_batch_id: "BATCH_456",
  status: "pending"
)

puts "✅ Created #{PaypalPayout.count} PayPal payouts"

# 15. Create Reviews
puts "⭐ Creating reviews..."

Review.create!(
  user: customer1,
  reviewable: skillmaster1,
  order: pending_order1,
  rating: 4,
  content: "Looking forward to the service!",
  review_type: "skillmaster",
  verified_purchase: true
)

Review.create!(
  user: customer2,
  reviewable: skillmaster2,
  order: pending_order2,
  rating: 5,
  content: "Excited to work with this skillmaster!",
  review_type: "skillmaster",
  verified_purchase: true
)

puts "✅ Created #{Review.count} reviews"

# 16. Create User Rewards
puts "🏆 Creating user rewards..."

UserReward.create!(
  user: customer1,
  points: 100,
  reward_type: "completion",
  status: "pending",
  amount: 5.00
)

UserReward.create!(
  user: skillmaster1,
  points: 200,
  reward_type: "completion",
  status: "claimed",
  amount: 10.00
)

puts "✅ Created #{UserReward.count} user rewards"

# 17. Create Skillmaster Applications
puts "📋 Creating skillmaster applications..."

SkillmasterApplication.create!(
  user: skillmaster1,
  status: "approved",
  submitted_at: 1.month.ago,
  reviewed_at: 3.weeks.ago,
  reviewer_id: admin.id,
  gamer_tag: "ProGamer123",
  reasons: "5 years of professional gaming experience",
  channels: ["https://twitch.tv/progamer123", "https://youtube.com/@progamer123"],
  platforms: ["Valorant", "CS2"],
  games: ["Valorant", "Counter-Strike 2"]
)

SkillmasterApplication.create!(
  user: skillmaster2,
  status: "approved",
  submitted_at: 2.weeks.ago,
  reviewed_at: 1.week.ago,
  reviewer_id: admin.id,
  gamer_tag: "LoLQueen",
  reasons: "Diamond rank in League of Legends",
  channels: ["https://twitch.tv/lolqueen"],
  platforms: ["League of Legends"],
  games: ["League of Legends"]
)

puts "✅ Created #{SkillmasterApplication.count} skillmaster applications"

# 18. Create some sample notifications
puts "🔔 Creating notifications..."

Notification.create!(
  user: customer1,
  content: "Your order has been placed and is awaiting assignment!",
  status: "unread",
  notification_type: "order_pending"
)

Notification.create!(
  user: customer2,
  content: "Your order is in the queue for skillmaster assignment",
  status: "unread",
  notification_type: "order_pending"
)

puts "✅ Created #{Notification.count} notifications"

# Summary
puts "\n🎉 Database seeding completed successfully!"
puts "\n📊 Summary:"
puts "👥 Users: #{User.count}"
puts "💼 Contractors: #{Contractor.count}"
puts "🎮 Platforms: #{Platform.count}"
puts "🎯 Sub-platforms: #{SubPlatform.count}"
puts "📂 Categories: #{Category.count}"
puts "🛍️ Products: #{Product.count}"
puts "📦 Orders: #{Order.count}"
puts "🛒 Order Products: #{OrderProduct.count}"
puts "💳 Payment Approvals: #{PaymentApproval.count}"
puts "💰 PayPal Payouts: #{PaypalPayout.count}"
puts "⭐ Reviews: #{Review.count}"
puts "🏆 User Rewards: #{UserReward.count}"
puts "📋 Skillmaster Applications: #{SkillmasterApplication.count}"
puts "🔔 Notifications: #{Notification.count}"
puts "🎫 Promotions: #{Promotion.count}"

puts "\n🔑 Test Login Credentials:"
puts "Admin: admin@ravenboost.com / SecureAdmin123!"
puts "Skillmaster 1: skillmaster1@ravenboost.com / SecureSkill123!"
puts "Skillmaster 2: skillmaster2@ravenboost.com / SecureSkill123!"
puts "Customer 1: customer1@ravenboost.com / SecureCustomer123!"
puts "Customer 2: customer2@ravenboost.com / SecureCustomer123!"
puts "Dev: dev@ravenboost.com / SecureDev123!"

puts "\n💼 Contractor Info:"
puts "Contractor 1 (#{skillmaster1.first_name}): Available: $#{contractor1.available_balance}, Pending: $#{contractor1.pending_balance}"
puts "Contractor 2 (#{skillmaster2.first_name}): Available: $#{contractor2.available_balance}, Pending: $#{contractor2.pending_balance}"

puts "\n✨ Ready to test the PayPal-only contractor system!"
