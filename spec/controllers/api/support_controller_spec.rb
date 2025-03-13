require 'rails_helper'

RSpec.describe Api::SupportController, type: :controller do
  let(:c_support_user) { create(:user, role: 'c_support') }
  let(:manager_user) { create(:user, role: 'manager') }
  let(:customer_user) { create(:user, role: 'customer') }

  describe 'GET #available_skillmasters' do
    before do
      sign_in c_support_user
    end

    it 'returns available skillmasters' do
      create_list(:user, 3, role: 'skillmaster')

      get :available_skillmasters
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end
  end

  describe 'POST #create_urgent_chat' do
    let(:order) { create(:order) }
    let(:skillmasters) { create_list(:user, 2, role: 'skillmaster') }

    before do
      sign_in c_support_user
    end

    it 'creates a group chat with selected skillmasters' do
      post :create_urgent_chat, params: {
        order_id: order.id,
        skillmaster_ids: skillmasters.map(&:id)
      }

      expect(response).to have_http_status(:created)
      expect(Chat.last.chat_participants.count).to eq(2)
    end
  end
end
