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
          admin_user: current_user,
          notes: params[:notes]
        )

        # Trigger PayPal payment capture which will handle contractor payout
        CapturePaypalPaymentJob.perform_later(@payment_approval.order.id)
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
        admin_user: current_user,
        notes: params[:notes] || 'Payment rejected by admin'
      )

      # Update order status - no specific fields needed, payment_approval relationship handles this

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

  # POST /api/admin/payment_approvals/bulk_approve
  def bulk_approve
    payment_approval_ids = params[:payment_approval_ids]
    admin_notes = params[:notes]

    if payment_approval_ids.blank? || !payment_approval_ids.is_a?(Array)
      return render json: {
        success: false,
        error: 'payment_approval_ids must be provided as an array'
      }, status: :bad_request
    end

    approved_count = 0
    failed_approvals = []

    begin
      ActiveRecord::Base.transaction do
        payment_approval_ids.each do |approval_id|
          payment_approval = PaymentApproval.find(approval_id)

          # Skip if already processed
          if payment_approval.status != 'pending'
            failed_approvals << {
              id: approval_id,
              error: "Payment approval is already #{payment_approval.status}"
            }
            next
          end

          # Update payment approval
          payment_approval.update!(
            status: 'approved',
            approved_at: Time.current,
            admin_user: current_user,
            notes: admin_notes
          )

          # Trigger PayPal payment capture which will handle contractor payout
          CapturePaypalPaymentJob.perform_later(payment_approval.order.id)

          approved_count += 1
        rescue ActiveRecord::RecordNotFound
          failed_approvals << {
            id: approval_id,
            error: 'Payment approval not found'
          }
        rescue StandardError => e
          Rails.logger.error "Error bulk approving payment #{approval_id}: #{e.message}"
          failed_approvals << {
            id: approval_id,
            error: 'Failed to approve payment'
          }
        end
      end

      render json: {
        success: true,
        message: "Successfully approved #{approved_count} payment(s)",
        approved_count: approved_count,
        failed_approvals: failed_approvals,
        total_requested: payment_approval_ids.length
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error "Error in bulk approval transaction: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to process bulk approval'
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
