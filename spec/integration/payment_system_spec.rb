require 'rails_helper'

RSpec.describe 'Payment System Integration', type: :request do
  let(:user) { create(:user, role: 'customer') }
  let(:skillmaster) { create(:user, role: 'skillmaster') }
  let(:contractor) { create(:contractor, user: skillmaster, stripe_account_id: 'acct_test123') }

  before do
    sign_in user
    # Mock Stripe API calls
    allow(Stripe::Checkout::Session).to receive(:create).and_return(
      double('Session', id: 'cs_test_123', url: 'https://checkout.stripe.com/pay/cs_test_123')
    )
  end

  describe 'Checkout Session Creation' do
    it 'creates checkout session with manual capture' do
      product_data = [
        { id: 1, name: 'Test Service', price: 100.0, tax: 10.0, quantity: 1 }
      ]

      expect {
        post '/api/payments/create_checkout_session', params: {
          currency: 'usd',
          products: product_data
        }
      }.to change(Order, :count).by(1)

      expect(response).to have_http_status(:created)

      order = Order.last
      expect(order.user).to eq(user)
      expect(order.total_price).to eq(110.0)
      expect(order.state).to eq('open')
    end
  end

  describe 'Payment Capture Job' do
    let(:order) do
      create(:order,
        user: user,
        assigned_skill_master: skillmaster,
        state: 'complete',
        stripe_payment_intent_id: 'pi_test123',
        payment_captured_at: nil
      )
    end

    it 'captures payment and splits funds when order is completed' do
      # Mock Stripe payment intent
      payment_intent = double('PaymentIntent', amount: 10000) # $100.00 in cents
      allow(Stripe::PaymentIntent).to receive(:capture).and_return(payment_intent)

      expect {
        CapturePaymentJob.perform_now(order.id)
      }.to change { contractor.reload.pending_balance }.by(75.0)

      order.reload
      expect(order.payment_captured_at).to be_present
      expect(order.skillmaster_earned).to eq(75.0)
      expect(order.company_earned).to eq(25.0)
    end
  end

  describe 'Wallet Management' do
    before do
      sign_in skillmaster
      contractor.update!(
        available_balance: 100.0,
        pending_balance: 50.0,
        last_withdrawal_at: 8.days.ago
      )
    end

    it 'shows wallet information' do
      get '/api/wallet/show'

      expect(response).to have_http_status(:ok)

      wallet_data = JSON.parse(response.body)
      expect(wallet_data['wallet']['available_balance']).to eq('100.0')
      expect(wallet_data['wallet']['pending_balance']).to eq('50.0')
      expect(wallet_data['wallet']['can_withdraw']).to be true
    end

    it 'allows withdrawal when cooldown has passed' do
      # Mock Stripe transfer
      transfer = double('Transfer', id: 'tr_test123')
      allow(Stripe::Transfer).to receive(:create).and_return(transfer)

      post '/api/wallet/withdraw', params: { amount: 50.0 }

      expect(response).to have_http_status(:ok)

      contractor.reload
      expect(contractor.available_balance).to eq(50.0)
      expect(contractor.last_withdrawal_at).to be_within(1.minute).of(Time.current)
    end
  end
end
