# WebSocket Console Test Script for Chat System
# Run this in Rails console: load 'websocket_console_test.rb'

puts "🚀 Starting WebSocket Chat System Test..."

# Create test users if they don't exist
def create_test_users
  puts "\n📝 Creating test users..."

  customer = User.find_or_create_by(email: 'customer@test.com') do |user|
    user.first_name = 'Test'
    user.last_name = 'Customer'
    user.role = 'customer'
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end

  skillmaster = User.find_or_create_by(email: 'skillmaster@test.com') do |user|
    user.first_name = 'Test'
    user.last_name = 'Skillmaster'
    user.role = 'skillmaster'
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end

  support = User.find_or_create_by(email: 'support@test.com') do |user|
    user.first_name = 'Test'
    user.last_name = 'Support'
    user.role = 'c_support'
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end

  puts "✅ Users created: Customer(#{customer.id}), Skillmaster(#{skillmaster.id}), Support(#{support.id})"
  [customer, skillmaster, support]
end

# Test chat creation
def test_chat_creation(customer, skillmaster, support)
  puts "\n💬 Testing chat creation..."

  # Test support chat
  support_chat = Chat.create!(
    initiator: customer,
    recipient: support,
    chat_type: 'support'
  )

  # Create chat participants
  ChatParticipant.create!(chat: support_chat, user: customer)
  ChatParticipant.create!(chat: support_chat, user: support)

  puts "✅ Support chat created: #{support_chat.id} (Ticket: #{support_chat.ticket_number})"

  # Test group chat (staff only)
  group_chat = Chat.create!(
    initiator: support,
    chat_type: 'group',
    title: 'Test Group Chat'
  )

  ChatParticipant.create!(chat: group_chat, user: support)
  ChatParticipant.create!(chat: group_chat, user: skillmaster)

  puts "✅ Group chat created: #{group_chat.id}"

  [support_chat, group_chat]
end

# Test WebSocket token generation
def test_websocket_tokens(chats, users)
  puts "\n🔑 Testing WebSocket token generation..."

  chats.each_with_index do |chat, index|
    user = users[index % users.length]

    token = JsonWebToken.encode(
      user_id: user.id,
      chat_id: chat.id,
      exp: 24.hours.from_now.to_i
    )

    puts "✅ Token for Chat #{chat.id}, User #{user.email}: #{token[0..20]}..."

    # Test token decoding
    decoded = JsonWebToken.decode(token)
    puts "   Decoded: user_id=#{decoded[:user_id]}, chat_id=#{decoded[:chat_id]}"
  end
end

# Test message creation and broadcasting
def test_message_broadcasting(chat, sender)
  puts "\n📤 Testing message broadcasting..."

  message = Message.create!(
    chat: chat,
    sender: sender,
    content: "Test message from #{sender.first_name} at #{Time.current}"
  )

  puts "✅ Message created: #{message.id} - '#{message.content}'"
  puts "   Broadcast should have been triggered via after_create_commit callback"

  message
end

# Test WebSocket service methods
def test_websocket_service(chat, user)
  puts "\n🔄 Testing WebSocket service methods..."

  # Test system message broadcast
  ChatWebSocketService.broadcast_system_message(
    chat,
    'user_joined',
    {
      user: { id: user.id, name: "#{user.first_name} #{user.last_name}" },
      message: "#{user.first_name} joined the chat"
    }
  )
  puts "✅ System message broadcasted: user_joined"

  # Test typing indicator
  ChatWebSocketService.broadcast_typing_indicator(chat, user, true)
  puts "✅ Typing indicator broadcasted: typing=true"

  # Test user status
  ChatWebSocketService.broadcast_user_status(chat, user, 'online')
  puts "✅ User status broadcasted: status=online"
end

# Generate WebSocket connection examples
def generate_connection_examples(chats, users)
  puts "\n🌐 WebSocket Connection Examples:"
  puts "=" * 50

  chats.each_with_index do |chat, index|
    user = users[index % users.length]

    token = JsonWebToken.encode(
      user_id: user.id,
      chat_id: chat.id,
      exp: 24.hours.from_now.to_i
    )

    puts "\n📱 Chat #{chat.id} (#{chat.chat_type}) - User: #{user.email}"
    puts "   WebSocket URL: ws://localhost:3000/cable?token=#{token}"
    puts "   REST API: GET /api/chats/#{chat.id}/connection_info"
    puts "   cURL: curl -H 'Authorization: Bearer YOUR_JWT' http://localhost:3000/api/chats/#{chat.id}/connection_info"
  end
end

# Main test execution
begin
  customer, skillmaster, support = create_test_users
  chats = test_chat_creation(customer, skillmaster, support)
  test_websocket_tokens(chats, [customer, skillmaster, support])

  # Test message broadcasting
  test_message_broadcasting(chats.first, customer)

  # Test WebSocket services
  test_websocket_service(chats.first, customer)

  # Generate connection examples
  generate_connection_examples(chats, [customer, skillmaster, support])

  puts "\n🎉 All tests completed successfully!"
  puts "\nNext steps:"
  puts "1. Start your Rails server: rails s"
  puts "2. Use the WebSocket URLs above to test with a WebSocket client"
  puts "3. Try the browser console test (see below)"

rescue => e
  puts "\n❌ Test failed: #{e.message}"
  puts e.backtrace.first(5)
end
