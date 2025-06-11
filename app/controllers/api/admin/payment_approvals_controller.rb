class Api::Admin::PaymentApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_payment_approval, only: %i[show approve reject]

  # GET /api/admin/payment_approvals
  def index
    payment_approvals = PaymentApproval.includes(:order, :user, :skillmaster)
                                       .order(created_at: :desc)
                                       .page(params[:page])
                                       .per(params[:per_page] || 25)

    render json: {
      success: true,
      payment_approvals: payment_approvals.map do |approval|
        {
          id: approval.id,
          order_id: approval.order.id,
          order_internal_id: approval.order.internal_id,
          customer_name: "#{approval.user.first_name} #{approval.user.last_name}",
          skillmaster_name: "#{approval.skillmaster.first_name} #{approval.skillmaster.last_name}",
          amount: approval.amount,
          skillmaster_earnings: approval.skillmaster_earnings,
          status: approval.status,
          created_at: approval.created_at,
          approved_at: approval.approved_at,
          rejected_at: approval.rejected_at,
          admin_notes: approval.admin_notes,
          order_completed_at: approval.order.admin_approved_completion_at
        }
      end,
      pagination: {
        current_page: payment_approvals.current_page,
        total_pages: payment_approvals.total_pages,
        total_count: payment_approvals.total_count
      }
    }, status: :ok
  end

  # POST /api/admin/payment_approvals/:id/approve
  def approve
    if @payment_approval.status != 'pending'
      return render json: {
        success: false,
        error: "Payment approval is already #{@payment_approval.status}"
      }, status: :unprocessable_entity
    end

    begin
      ActiveRecord::Base.transaction do
        # Update payment approval
        @payment_approval.update!(
          status: 'approved',
          approved_at: Time.current,
          approved_by: current_user,
          admin_notes: params[:notes]
        )

        # Move earnings from pending to available balance
        contractor = @payment_approval.skillmaster.contractor
        contractor.increment!(:available_balance, @payment_approval.skillmaster_earnings)
        contractor.decrement!(:pending_balance, @payment_approval.skillmaster_earnings)

        # Update order status
        @payment_approval.order.update!(
          payment_approval_status: 'approved',
          payment_approved_at: Time.current,
          payment_approved_by: current_user
        )

        # Queue payout job if contractor is ready for payouts
        if contractor.can_receive_payouts?
          PaypalPayoutJob.perform_later(contractor.id, @payment_approval.skillmaster_earnings)
        end
      end

      render json: {
        success: true,
        message: 'Payment approved successfully',
        payment_approval: format_payment_approval(@payment_approval)
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Error approving payment: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to approve payment'
      }, status: :internal_server_error
    end
  end

  # POST /api/admin/payment_approvals/:id/reject
  def reject
    if @payment_approval.status != 'pending'
      return render json: {
        success: false,
        error: "Payment approval is already #{@payment_approval.status}"
      }, status: :unprocessable_entity
    end

    begin
      @payment_approval.update!(
        status: 'rejected',
        rejected_at: Time.current,
        rejected_by: current_user,
        admin_notes: params[:notes] || 'Payment rejected by admin'
      )

      # Update order status
      @payment_approval.order.update!(
        payment_approval_status: 'rejected',
        payment_rejected_at: Time.current,
        payment_rejected_by: current_user
      )

      render json: {
        success: true,
        message: 'Payment rejected successfully',
        payment_approval: format_payment_approval(@payment_approval)
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Error rejecting payment: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to reject payment'
      }, status: :internal_server_error
    end
  end

  private

  def set_payment_approval
    @payment_approval = PaymentApproval.find(params[:id])
  end

  def ensure_admin_access
    return if current_user.admin? || current_user.dev?

    render json: { success: false, error: 'Access denied' }, status: :forbidden
  end

  def format_payment_approval(approval)
    {
      id: approval.id,
      order_id: approval.order.id,
      order_internal_id: approval.order.internal_id,
      customer_name: "#{approval.user.first_name} #{approval.user.last_name}",
      skillmaster_name: "#{approval.skillmaster.first_name} #{approval.skillmaster.last_name}",
      amount: approval.amount,
      skillmaster_earnings: approval.skillmaster_earnings,
      status: approval.status,
      created_at: approval.created_at,
      approved_at: approval.approved_at,
      rejected_at: approval.rejected_at,
      admin_notes: approval.admin_notes,
      approved_by: approval.approved_by&.email,
      rejected_by: approval.rejected_by&.email
    }
  end
end
