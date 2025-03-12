require 'rails_helper'

RSpec.describe Api::ChatsController, type: :controller do
  let(:customer) { create(:user, role: 'customer') }
  let(:skillmaster) { create(:user, role: 'skillmaster') }
  let(:admin) { create(:user, role: 'admin') }
  let(:platform) { create(:platform) }
  let(:platform_credential) { create(:platform_credential, user: customer, platform: platform) }
  let(:order) do
    create(:order,
           user: customer,
           assigned_skill_master_id: skillmaster.id,
           platform_credential: platform_credential,
           state: 'assigned')
  end

  describe 'GET #index' do
    context 'when user is authenticated' do
      before do
        sign_in customer

        # Create first chat (direct chat with skillmaster)
        @chat1 = create(:chat,
                        initiator: customer,
                        recipient: skillmaster,
                        order: order,
                        chat_type: 'direct')
        create(:chat_participant, chat: @chat1, user: customer)
        create(:chat_participant, chat: @chat1, user: skillmaster)

        # Create second chat (support chat with admin)
        @chat2 = create(:chat,
                        initiator: customer,
                        recipient: admin,
                        chat_type: 'support')
        create(:chat_participant, chat: @chat2, user: customer)
        create(:chat_participant, chat: @chat2, user: admin)
      end

      it 'returns user\'s chats' do
        get :index

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body.length).to eq(2)

        # Verify the returned chats are correct
        chat_ids = body.map { |chat| chat['id'] }
        expect(chat_ids).to include(@chat1.id, @chat2.id)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    context 'when creating a direct chat' do
      before { sign_in customer }

      it 'creates a chat between customer and assigned skillmaster' do
        post :create, params: {
          chat: {
            chat_type: 'direct',
            recipient_id: skillmaster.id,
            order_id: order.id
          }
        }

        expect(response).to have_http_status(:created)
        expect(Chat.last.recipient).to eq(skillmaster)
      end

      it 'prevents creating chat with invalid order' do
        post :create, params: {
          chat: {
            chat_type: 'direct',
            recipient_id: skillmaster.id,
            order_id: 999_999
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when creating a support chat' do
      before { sign_in customer }

      it 'creates a support chat with ticket number' do
        post :create, params: {
          chat: {
            chat_type: 'support',
            recipient_id: admin.id
          }
        }

        expect(response).to have_http_status(:created)
        expect(Chat.last.ticket_number).to be_present
      end
    end

    context 'when creating a group chat' do
      before { sign_in admin }

      it 'creates a group chat with multiple participants' do
        other_admin = create(:user, role: 'admin')
        other_skillmaster = create(:user, role: 'skillmaster')

        post :create, params: {
          chat: {
            chat_type: 'group',
            title: 'Staff Discussion',
            participant_ids: [admin.id, other_admin.id, other_skillmaster.id]
          }
        }

        expect(response).to have_http_status(:created)
        expect(Chat.last.participants.count).to eq(3)
      end

      it 'prevents creating group chat with customers' do
        other_customer = create(:user, role: 'customer')

        post :create, params: {
          chat: {
            chat_type: 'group',
            title: 'Invalid Group',
            participant_ids: [admin.id, other_customer.id]
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'automatically adds creator to participants' do
        other_admin = create(:user, role: 'admin')

        post :create, params: {
          chat: {
            chat_type: 'group',
            title: 'Staff Discussion',
            participant_ids: [other_admin.id]
          }
        }

        expect(response).to have_http_status(:created)
        expect(Chat.last.participants).to include(admin)
      end
    end
  end

  describe 'GET #show' do
    let(:chat) { create(:chat, initiator: customer, recipient: skillmaster, order: order) }

    before { sign_in customer }

    it 'returns chat details' do
      get :show, params: { id: chat.id }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['id']).to eq(chat.id)
    end

    it 'returns 404 for non-existent chat' do
      get :show, params: { id: 999_999 }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #archive' do
    let(:chat) { create(:chat, initiator: customer, recipient: skillmaster, order: order) }

    before { sign_in customer }

    it 'archives an active chat' do
      post :archive, params: { id: chat.id }
      expect(response).to have_http_status(:success)
      expect(chat.reload.status).to eq('archived')
    end

    it 'prevents archiving already archived chat' do
      chat = create(:chat, :archived, initiator: customer, recipient: skillmaster)
      post :archive, params: { id: chat.id }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'prevents unauthorized user from archiving chat' do
      other_customer = create(:user, role: 'customer')
      sign_in other_customer

      post :archive, params: { id: chat.id }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
