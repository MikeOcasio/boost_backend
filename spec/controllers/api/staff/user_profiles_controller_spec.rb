require 'rails_helper'

RSpec.describe Api::Staff::UserProfilesController, type: :controller do
  let(:staff_user) { create(:user, role: 'c_support') }
  let(:customer) { create(:user, role: 'customer') }
  let(:active_chat) do
    chat = create(:chat, chat_type: 'direct', status: 'active')
    create(:chat_participant, chat: chat, user: staff_user)
    create(:chat_participant, chat: chat, user: customer)
    chat
  end

  describe 'GET #show' do
    context 'when staff has active chat with user' do
      before do
        sign_in staff_user
        active_chat # Create the active chat
      end

      it 'returns user profile data' do
        get :show, params: { id: customer.id }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to include('profile', 'chats', 'rewards', 'wallet', 'referrals')
      end
    end

    context 'when chat is archived' do
      before do
        sign_in staff_user
        active_chat.update(status: 'archived')
      end

      it 'denies access to user profile' do
        get :show, params: { id: customer.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when no chat exists' do
      before { sign_in staff_user }

      it 'denies access to user profile' do
        get :show, params: { id: customer.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not staff' do
      before { sign_in create(:user, role: 'customer') }

      it 'denies access' do
        get :show, params: { id: customer.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
