require 'rails_helper'

RSpec.describe Chat, type: :model do
  let(:customer) { create(:user, role: 'customer') }
  let(:skillmaster) { create(:user, role: 'skillmaster') }
  let(:admin) { create(:user, role: 'admin') }

  # Create platform first
  let(:platform) { create(:platform, name: 'PC') }

  # Then create platform credential
  let(:platform_credential) do
    create(:platform_credential,
           user: customer,
           platform: platform,
           username: 'test_user',
           password: 'test_pass')
  end

  # Finally create order with existing platform credential
  let(:order) do
    create(:order,
           user: customer,
           assigned_skill_master_id: skillmaster.id,
           platform_credential: platform_credential,
           state: 'assigned',
           platform: platform.name) # Use platform name string, not the Platform instance
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:chat_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:chat_type).in_array(%w[direct group support]) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active archived]) }
    it { is_expected.to belong_to(:initiator).class_name('User') }
    it { is_expected.to belong_to(:recipient).class_name('User').optional }
    it { is_expected.to belong_to(:order).optional }
    it { is_expected.to have_many(:messages).dependent(:destroy) }
    it { is_expected.to have_many(:chat_participants).dependent(:destroy) }
    it { is_expected.to have_many(:participants).through(:chat_participants) }
  end

  describe 'scopes' do
    let(:customer1) { create(:user, role: 'customer') }
    let(:customer2) { create(:user, role: 'customer') }
    let(:customer3) { create(:user, role: 'customer') }
    let(:admin1) { create(:user, role: 'admin') }
    let(:admin2) { create(:user, role: 'admin') }
    let(:admin3) { create(:user, role: 'admin') }
    let(:skillmaster) { create(:user, role: 'skillmaster') }

    let!(:active_chat) do
      create(:chat,
             chat_type: 'support',
             status: 'active',
             initiator: customer1,
             recipient: admin1)
    end

    let!(:archived_chat) do
      create(:chat,
             chat_type: 'support',
             status: 'archived',
             initiator: customer2,
             recipient: admin2)
    end

    let!(:support_chat) do
      create(:chat,
             chat_type: 'support',
             status: 'active',
             initiator: customer3,
             recipient: admin3)
    end

    let!(:direct_chat) do
      create(:chat,
             chat_type: 'direct',
             status: 'active',
             initiator: admin1,
             recipient: skillmaster)
    end

    it 'returns active chats' do
      expect(Chat.active).to include(active_chat, direct_chat)
      expect(Chat.active).not_to include(archived_chat)
    end

    it 'returns archived chats' do
      expect(Chat.archived).to include(archived_chat)
      expect(Chat.archived).not_to include(active_chat, direct_chat)
    end

    it 'returns support tickets' do
      expect(Chat.support_tickets).to include(support_chat)
      expect(Chat.support_tickets).not_to include(direct_chat)
    end
  end

  describe 'chat creation' do
    context 'direct chat' do
      it 'allows customer to create chat with assigned skillmaster' do
        chat = build(:chat,
                     chat_type: 'direct',
                     initiator: customer,
                     recipient: skillmaster,
                     order: order)
        expect(chat).to be_valid
      end

      it 'prevents customer from creating chat with unassigned skillmaster' do
        # byebug
        other_skillmaster = create(:user, role: 'skillmaster')
        chat = build(:chat,
                     chat_type: 'direct',
                     initiator: customer,
                     recipient: other_skillmaster)
        expect(chat).not_to be_valid
        expect(chat.errors[:base]).to include('Cannot create chat without an active order')
      end

      it 'prevents creation without initiator' do
        chat = build(:chat, initiator: nil, recipient: skillmaster)
        expect(chat).not_to be_valid
        expect(chat.errors[:initiator]).to include('must exist')
      end

      it 'prevents creation with invalid order state' do
        invalid_order = create(:order,
                               user: customer,
                               assigned_skill_master_id: skillmaster.id,
                               platform_credential: platform_credential,
                               state: 'complete')

        chat = build(:chat,
                     chat_type: 'direct',
                     initiator: customer,
                     recipient: skillmaster,
                     order: invalid_order)

        expect(chat).not_to be_valid
        expect(chat.errors[:base]).to include('Cannot create chat without an active order')
      end
    end

    context 'group chat' do
      let(:admin1) { create(:user, role: 'admin') }
      let(:admin2) { create(:user, role: 'admin') }
      let(:dev) { create(:user, role: 'dev') }
      let(:customer) { create(:user, role: 'customer') }

      it 'requires at least two participants after creation' do
        chat = build(:chat, chat_type: 'group', initiator: admin1)

        # Should be invalid with no participants
        expect(chat).not_to be_valid
        expect(chat.errors[:base]).to include('Group chat requires at least two participants')

        # Add participants and save
        chat.chat_participants.build(user: admin1)
        chat.chat_participants.build(user: admin2)

        # Debug output
        puts "Chat participants before save: #{chat.chat_participants.length}"
        puts "Chat participants users: #{chat.chat_participants.map(&:user).map(&:role)}"

        result = chat.save
        puts "Save result: #{result}"
        puts "Validation errors: #{chat.errors.full_messages}" unless result

        expect(result).to be true

        # Remove one participant
        chat.chat_participants.last.destroy
        expect(chat.reload).not_to be_valid
        expect(chat.errors[:base]).to include('Group chat requires at least two participants')
      end

      it 'prevents customers from joining group chats' do
        chat = build(:chat, chat_type: 'group', initiator: admin1)

        # Add valid admins
        chat.chat_participants.build(user: admin1)
        chat.chat_participants.build(user: admin2)

        # Debug output
        puts "Chat participants before save: #{chat.chat_participants.length}"
        puts "Chat participants users: #{chat.chat_participants.map(&:user).map(&:role)}"

        result = chat.save
        puts "Save result: #{result}"
        puts "Validation errors: #{chat.errors.full_messages}" unless result

        expect(result).to be true

        # Try to add customer
        chat.chat_participants.create(user: customer)

        expect(chat.reload).not_to be_valid
        expect(chat.errors[:base]).to include('Group chat can only include staff members')
      end

      it 'allows mixed staff roles' do
        chat = build(:chat, chat_type: 'group', initiator: admin1)
        chat.chat_participants.build(user: admin1)
        chat.chat_participants.build(user: dev)
        chat.chat_participants.build(user: create(:user, role: 'skillmaster'))

        # Debug output
        puts "Chat participants before save: #{chat.chat_participants.length}"
        puts "Chat participants users: #{chat.chat_participants.map(&:user).map(&:role)}"

        result = chat.save
        puts "Save result: #{result}"
        puts "Validation errors: #{chat.errors.full_messages}" unless result

        expect(result).to be true
        expect(chat.reload).to be_valid
      end
    end

    context 'support chat' do
      it 'generates ticket number for support chats' do
        chat = create(:chat,
                      chat_type: 'support',
                      initiator: customer,
                      recipient: admin)
        expect(chat.ticket_number).to be_present
        expect(chat.ticket_number).to match(/TICKET-\d+-[A-F0-9]+/)
      end

      it 'prevents support chat between two customers' do
        other_customer = create(:user, role: 'customer')
        chat = build(:chat,
                     chat_type: 'support',
                     initiator: customer,
                     recipient: other_customer)
        expect(chat).not_to be_valid
      end

      it 'prevents support chat initiated by admin' do
        chat = build(:chat,
                     chat_type: 'support',
                     initiator: admin,
                     recipient: customer)
        expect(chat).not_to be_valid
      end
    end
  end

  describe 'callbacks' do
    it 'generates ticket number for support chats' do
      chat = create(:chat, :support)
      expect(chat.ticket_number).to be_present
      expect(chat.ticket_number).to match(/TICKET-\d+-[A-F0-9]+/)
    end

    it 'does not generate ticket number for non-support chats' do
      # Create a direct chat between admin and skillmaster (no order needed)
      chat = create(:chat,
                    chat_type: 'direct',
                    initiator: admin,
                    recipient: skillmaster)
      expect(chat.ticket_number).to be_nil
    end

    it 'does not generate ticket number for group chats' do
      admin1 = create(:user, role: 'admin')
      admin2 = create(:user, role: 'admin')

      chat = build(:chat, chat_type: 'group', initiator: admin1)
      chat.chat_participants.build(user: admin1)
      chat.chat_participants.build(user: admin2)
      chat.save!

      expect(chat.ticket_number).to be_nil
    end
  end

  describe '#archive!' do
    it 'archives an active chat' do
      chat = create(:chat,
                    chat_type: 'support', # Use support chat type which doesn't require an order
                    status: 'active',
                    initiator: customer,
                    recipient: admin)
      chat.archive!
      expect(chat.reload.status).to eq('archived')
    end

    it 'maintains archived status when trying to archive again' do
      chat = create(:chat, :support, status: 'archived')
      chat.archive!
      expect(chat.reload.status).to eq('archived')
    end
  end

  describe 'chat permissions' do
    it 'allows internal staff chat between admins' do
      chat = build(:chat,
                   chat_type: 'direct',
                   initiator: admin,
                   recipient: create(:user, role: 'admin'))
      expect(chat).to be_valid
    end

    it 'allows internal staff chat between admin and skillmaster' do
      chat = build(:chat,
                   chat_type: 'direct',
                   initiator: admin,
                   recipient: skillmaster)
      expect(chat).to be_valid
    end
  end
end
