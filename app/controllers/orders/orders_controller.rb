# Orders Controller - Simplified for Non-Payment Order Creation
#
# This controller now focuses solely on order management functionality.
# PayPal payment processing and order creation from successful payments
# has been moved to Api::PaymentsController for better separation of concerns.
#
# For payment-based order creation, use:
# - POST /api/payments/create_paypal_order - Create PayPal order
# - POST /api/payments/capture_paypal_payment - Capture PayPal payment after approval
#
# This controller only handles:
# - Direct order creation by devs (for testing/admin purposes)
# - Order viewing, updating, and state management
# - Order completion workflows

module Orders
  class OrdersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_order,
                  only: %i[show update destroy pick_up_order admin_approve_completion admin_reject_completion verify_completion
                           admin_approve]

    # GET /orders/info
    # Fetch all orders. Only accessible by admins, devs, or specific roles as determined by other methods.
    def index
      if current_user
        # Fetch orders based on user role
        orders = if current_user.role == 'admin' || current_user.role == 'dev'
                   Order.all
                 elsif current_user.role == 'skillmaster'
                   Order.where(assigned_skill_master_id: current_user.id,
                               state: %w[assigned in_progress delayed disputed complete])
                 else
                   Order.where(user_id: current_user.id)
                 end

        render json: {
          orders: orders.includes(:user).as_json(
            include: {
              products: {
                only: %i[id name price tax image quantity]
              }
            },
            only: %i[id state created_at total_price assigned_skill_master_id internal_id platform promo_data
                     order_data]
          ).map do |order|
            # Find the actual order object to get the user
            order_object = orders.find { |o| o.id == order['id'] }
            platform = Platform.find_by(id: order['platform']) # Use find_by to avoid exceptions
            # Fetch skill master info
            skill_master_info = User.find_by(id: order['assigned_skill_master_id'])

            order.merge(
              platform: platform ? { id: platform.id, name: platform.name } : nil,
              skill_master: {
                id: skill_master_info&.id,
                gamer_tag: skill_master_info&.gamer_tag,
                first_name: skill_master_info&.first_name
              },
              user: {
                id: order_object&.user&.id,
                first_name: order_object&.user&.first_name,
                last_name: order_object&.user&.last_name,
                email: order_object&.user&.email,
                role: order_object&.user&.role
              }
            ) # Add platform info or nil
          end
        }
      else
        render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end
    end

    # GET /api/orders/:id
    # Show details of a specific order.
    # Skill masters can only see their own assigned orders with platform credentials.
    # Admins and devs can see all orders.
    def show
      if current_user&.id == @order.user_id ||
         (current_user&.id == @order.assigned_skill_master_id &&
          current_user&.role == 'skillmaster') ||
         current_user&.role.in?(%w[admin dev])
        render_view
      else
        render_unauthorized
      end
    end

    # POST orders/info
    def create
      if current_user.role == 'dev'
        @order = Order.new(order_params.merge(state: 'open'))
        @order.platform = params[:platform] if params[:platform].present?
        @order.promo_data = params[:promo_data] if params[:promo_data].present?
        @order.order_data = params[:order_data] if params[:order_data].present?

        if assign_platform_credentials(@order, params[:platform])
          if @order.save
            # Add products to the order
            add_products_to_order(@order, params[:product_ids])

            # Calculate totals from order_data
            totals = calculate_order_totals(params[:order_data])
            @order.update(
              total_price: totals[:total_price],
              tax: totals[:tax]
            )

            render json: { success: true, order_id: @order.id }, status: :created
          else
            render json: { success: false, errors: @order.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { success: false, message: 'Invalid platform credential.' }, status: :unprocessable_entity
        end
      else
        render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end
    end

    # PATCH/PUT /api/orders/:id
    # Update an existing order.
    # Admins and devs can update any order, while skill masters can only update the order status if applicable.

    def update
      # Extract parameters from different possible structures
      state_param = extract_state_parameter
      completion_data_param = extract_completion_data_parameter(params)

      if current_user.role == 'admin' || current_user.role == 'dev'
        # Allow admin/dev to update any attribute
        if state_param.present?
          # Validate and transition the state based on the provided value
          case state_param
          when 'in_progress'
            if @order.may_start_progress?
              @order.start_progress!
            else
              return render json: { success: false, message: 'Order cannot transition to in progress.' },
                            status: :unprocessable_entity
            end
          when 'complete'

            if @order.may_mark_complete?
              begin
                # Handle completion data and images when admin/dev marks as complete
                completion_updates = process_completion_data(completion_data_param)

                # Update order with completion data before state transition
                if completion_updates.any?
                  @order.update!(completion_updates)
                  Rails.logger.info "Successfully updated completion data: #{completion_updates}"
                end

                @order.mark_complete!
                Rails.logger.info 'Order successfully marked as complete'

                # Clear completion_data after successful completion to remove any remaining base64 data
                @order.update!(completion_data: {})
                Rails.logger.info 'Completion data cleared after successful completion'

                # Return success response for admin/dev completion
                return render json: {
                  success: true,
                  message: 'Order marked as complete successfully.',
                  order: @order.as_json(only: %i[id state completion_data before_image after_image
                                                 skillmaster_submission_notes])
                }
              rescue StandardError => e
                Rails.logger.error "Error during completion process: #{e.message}"
                Rails.logger.error e.backtrace.join("\n")
                return render json: { success: false, message: "Error completing order: #{e.message}" },
                              status: :unprocessable_entity
              end
            else
              return render json: { success: false, message: "Order cannot be marked as complete. Current state: #{@order.state}. Available transitions: #{@order.aasm.events(permitted: true)}" },
                            status: :unprocessable_entity
            end
          when 'disputed'
            if @order.may_mark_disputed?
              @order.mark_disputed!
            else
              return render json: { success: false, message: 'Order cannot be marked as disputed.' },
                            status: :unprocessable_entity
            end
          else
            return render json: { success: false, message: 'Invalid state transition.' }, status: :unprocessable_entity
          end
        end

        # Update other order attributes (excluding state)
        if @order.update(order_params.except(:state)) # Exclude the state parameter from the update
          render json: @order
        else
          render json: @order.errors, status: :unprocessable_entity
        end

      elsif current_user.role == 'skillmaster'
        byebug
        # Skill masters can update the state and submit completion notes
        if state_param.present?
          case state_param
          when 'in_progress'
            if @order.may_start_progress?
              @order.start_progress!
              render json: @order
            else
              render json: { success: false, message: 'Order cannot transition to in progress.' },
                     status: :unprocessable_entity
            end
          when 'complete'
            # Skillmaster can mark work as complete - but payment requires admin approval
            if @order.may_mark_complete?
              begin
                # Handle completion data and images when marking as complete
                completion_updates = process_completion_data(completion_data_param)

                # Update order with completion data before state transition
                if completion_updates.any?
                  @order.update!(completion_updates)
                  Rails.logger.info "Successfully updated completion data: #{completion_updates}"
                end

                @order.mark_complete!
                @order.update!(submitted_for_review_at: Time.current)
                Rails.logger.info 'Order successfully marked as complete by skillmaster'

                # Clear completion_data after successful completion to remove any remaining base64 data
                @order.update!(completion_data: {})
                Rails.logger.info 'Completion data cleared after successful completion'

                render json: {
                  success: true,
                  message: 'Work completed successfully. Payment pending admin approval.',
                  order: @order.as_json(only: %i[id state submitted_for_review_at completion_data before_image
                                                 after_image skillmaster_submission_notes])
                }
              rescue StandardError => e
                Rails.logger.error "Error during skillmaster completion process: #{e.message}"
                Rails.logger.error e.backtrace.join("\n")
                render json: { success: false, message: "Error completing order: #{e.message}" },
                       status: :unprocessable_entity
              end
            else
              render json: { success: false, message: "Order cannot be marked as complete. Current state: #{@order.state}. Available transitions: #{@order.aasm.events(permitted: true)}" },
                     status: :unprocessable_entity
            end
          when 'disputed'
            if @order.may_mark_disputed?
              @order.mark_disputed!
              render json: @order
            else
              render json: { success: false, message: 'Order cannot be marked as disputed.' },
                     status: :unprocessable_entity
            end
          else
            render json: { success: false, message: 'Invalid state transition for skillmaster.' },
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, message: 'State parameter is required.' }, status: :unprocessable_entity
        end

      else
        render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end
    end

    # DELETE /api/orders/:id
    # Delete an existing order.
    # Only accessible by admins or devs.
    def destroy
      # Check if the current user has the necessary role
      if current_user.role == 'dev' || current_user.role == 'admin'
        # Attempt to destroy the order and handle any errors
        if @order.present?
          @order.destroy
          head :no_content
        else
          render json: { success: false, message: 'Order not found.' }, status: :not_found
        end
      else
        render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end
    end

    # ! TODO: Update to include all data as index and show methods
    # Method to retrieve orders in the graveyard pool (unassigned orders).
    # GET /orders/info/graveyard_orders
    def graveyard_orders
      @graveyard_orders = Order.where(assigned_skill_master_id: nil)

      render json: {
        orders: @graveyard_orders.as_json(
          include: {
            products: {
              only: %i[id name price tax image quantity]
            }
          },
          only: %i[id state created_at total_price internal_id platform order_data promo_data]
        ).map do |order|
          platform = Platform.find_by(id: order['platform']) # Use find_by to avoid exceptions
          order.merge(platform: platform ? { id: platform.id, name: platform.name } : nil) # Add platform info or nil
        end
      }
    end

    # POST orders/info/:id/pick_up_order
    # Assign an order to a skill master. Only accessible by admins, devs, or skill masters.
    # Skill masters can only pick up orders that match their platform.

    # ! contractor gets assigned in PayPal to order.
    def pick_up_order
      # Check user role and determine the skill master ID
      if current_user.role == 'admin' || current_user.role == 'dev'
        skill_master_id = params[:assigned_skill_master_id] || current_user.id
      elsif current_user.role == 'skillmaster'
        skill_master_id = current_user.id
      else
        return render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end

      # Check if the order is in the 'open' state
      unless @order.open?
        return render json: { success: false, message: "Order is not available for pick up. Current state: #{@order.state}" },
                      status: :unprocessable_entity
      end

      # Find the skill master and check their platforms if they are a skill master
      if current_user.role == 'skillmaster'
        skill_master_platforms = current_user.platforms.map(&:id) # Or `map(&:id)` depending on your platform logic
        order_platform = @order.platform # Assuming `@order.platform` is either the platform name or ID

        unless skill_master_platforms.include?(order_platform)
          return render json: { success: false, message: "Order platform does not match skill master's platforms." },
                        status: :forbidden
        end
      end

      # Assign the order to the skill master and attempt to transition the order state
      @order.assigned_skill_master_id = skill_master_id

      # Transition the order from 'open' to 'assigned' using AASM
      if @order.may_assign? && @order.assign! && @order.save
        render json: { success: true, message: "Order #{@order.id} picked up successfully!" }
      else
        render json: { success: false, message: 'Failed to pick up the order.' }, status: :unprocessable_entity
      end
    end

    # POST /orders/info/:id/admin_approve_completion
    # Admin approves payment release for completed work (NEW WORKFLOW)
    def admin_approve_completion
      unless current_user.role.in?(%w[admin dev])
        return render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end

      unless @order.complete?
        return render json: { success: false, message: 'Order must be completed before payment can be approved.' },
                      status: :unprocessable_entity
      end

      unless @order.customer_verified_at.present?
        return render json: { success: false, message: 'Order must be verified by customer before admin can approve payment.' },
                      status: :unprocessable_entity
      end

      if @order.admin_reviewed_at.present?
        return render json: { success: false, message: 'Payment has already been reviewed by admin.' },
                      status: :unprocessable_entity
      end

      # Mark as admin approved
      @order.update!(
        admin_reviewed_at: Time.current,
        admin_reviewer_id: current_user.id,
        admin_approval_notes: params[:notes]
      )

      # NOW trigger payment capture since admin has approved
      if @order.paypal_order_id.present?
        CapturePaypalPaymentJob.perform_later(@order.id)
        Rails.logger.info "Admin approved order #{@order.id} - PayPal payment capture job queued"
      end

      # NOTE: Earnings movement from pending to available happens in CapturePaypalPaymentJob
      # after successful payment capture

      render json: {
        success: true,
        message: 'Payment approved by admin. Payment will be processed.',
        order: @order.as_json(only: %i[id state admin_reviewed_at])
      }
    end

    # POST /orders/info/:id/admin_reject_completion
    # Admin rejects payment and sends order back to in_progress (NEW WORKFLOW)
    def admin_reject_completion
      unless current_user.role.in?(%w[admin dev])
        return render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end

      unless @order.complete?
        return render json: { success: false, message: 'Order must be completed before it can be rejected.' },
                      status: :unprocessable_entity
      end

      if @order.admin_reviewed_at.present?
        return render json: { success: false, message: 'Payment has already been reviewed by admin.' },
                      status: :unprocessable_entity
      end

      # Send order back to in_progress for rework
      if @order.may_reject_and_rework?
        @order.reject_and_rework!
        @order.update!(
          admin_reviewed_at: Time.current,
          admin_reviewer_id: current_user.id,
          admin_rejection_notes: params[:notes] || 'Work needs improvement before payment approval.',
          submitted_for_review_at: nil # Clear submission timestamp
        )

        render json: {
          success: true,
          message: 'Work rejected. Skillmaster has been notified to make improvements.',
          order: @order.as_json(only: %i[id state admin_reviewed_at admin_rejection_notes])
        }
      else
        render json: {
          success: false,
          message: 'Order cannot be rejected at this time.'
        }, status: :unprocessable_entity
      end
    end

    # POST /orders/info/:id/verify_completion
    # Customer verifies that the order was completed successfully (UPDATED FOR NEW WORKFLOW)
    def verify_completion
      unless current_user.id == @order.user_id
        return render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end

      unless @order.complete?
        return render json: { success: false, message: 'Order is not completed yet.' }, status: :unprocessable_entity
      end

      verification_status = params[:verified] # true/false

      # Log parameters for debugging
      Rails.logger.info "Verify completion - Order #{@order.id}, verified param: #{verification_status.inspect}, all params: #{params.inspect}"

      # Handle missing parameter
      if verification_status.nil?
        return render json: {
          success: false,
          message: 'Missing required parameter: verified (true/false)'
        }, status: :bad_request
      end

      if verification_status.to_s == 'true'
        # Customer confirms completion - order stays complete and will move to available balance after 7 days
        @order.update!(customer_verified_at: Time.current)
        Rails.logger.info "Order #{@order.id} verified by customer at #{Time.current}"
        render json: {
          success: true,
          message: 'Order completion verified by customer.',
          order: @order.as_json(only: %i[id state customer_verified_at])
        }
      elsif verification_status.to_s == 'false'
        # Customer disputes completion - move to in_review state
        if @order.may_mark_in_review?
          @order.mark_in_review!
          @order.update!(customer_verified_at: nil)

          # TODO: Send notification to admin for investigation
          Rails.logger.info "Order #{@order.id} moved to in_review - customer disputed completion"

          render json: {
            success: true,
            message: 'Order marked for review. An admin will investigate.',
            order: @order.as_json(only: %i[id state])
          }
        else
          render json: {
            success: false,
            message: 'Order cannot be marked for review at this time.'
          }, status: :unprocessable_entity
        end
      else
        render json: {
          success: false,
          message: 'Invalid verification status. Must be true or false.'
        }, status: :bad_request
      end
    end

    # POST /orders/info/:id/admin_approve
    # Admin approves order after review (moves from in_review back to complete)
    def admin_approve
      unless current_user.role.in?(%w[admin dev])
        return render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end

      unless @order.in_review?
        return render json: { success: false, message: 'Order is not in review state.' }, status: :unprocessable_entity
      end

      if @order.may_approve_completion?
        @order.approve_completion!
        @order.update!(
          admin_reviewed_at: Time.current,
          admin_reviewer_id: current_user.id,
          customer_verified_at: Time.current # Set this so payment can be processed
        )

        render json: {
          success: true,
          message: 'Order approved by admin.',
          order: @order.as_json(only: %i[id state admin_reviewed_at customer_verified_at])
        }
      else
        render json: {
          success: false,
          message: 'Order cannot be approved at this time.'
        }, status: :unprocessable_entity
      end
    end

    # GET /orders/info/pending_review
    # Get orders that need admin review (UPDATED FOR NEW WORKFLOW)
    def pending_review
      unless current_user.role.in?(%w[admin dev])
        return render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end

      # Get completed orders needing payment approval and orders in dispute review
      review_orders = Order.where(
        "(state = 'complete' AND admin_reviewed_at IS NULL AND submitted_for_review_at IS NOT NULL) OR state = 'in_review'"
      ).includes(:user, :assigned_skill_master, :products)
                           .order(updated_at: :desc)

      render json: {
        success: true,
        orders: review_orders.map do |order|
          # Determine review type and status
          if order.state == 'complete'
            if order.customer_verified_at.present?
              review_type = 'payment_approval'
              status = 'ready_for_admin_approval'
            else
              review_type = 'payment_approval'
              status = 'awaiting_customer_verification'
            end
          else
            review_type = 'dispute_review'
            status = 'disputed'
          end

          {
            id: order.id,
            internal_id: order.internal_id,
            state: order.state,
            total_price: order.total_price,
            updated_at: order.updated_at,
            submitted_for_review_at: order.submitted_for_review_at,
            customer_verified_at: order.customer_verified_at,
            skillmaster_submission_notes: order.skillmaster_submission_notes,
            admin_rejection_notes: order.admin_rejection_notes,
            review_type: review_type,
            status: status,
            customer: {
              id: order.user.id,
              name: "#{order.user.first_name} #{order.user.last_name}",
              email: order.user.email
            },
            skillmaster: {
              id: order.assigned_skill_master&.id,
              name: order.assigned_skill_master&.first_name,
              gamer_tag: order.assigned_skill_master&.gamer_tag
            },
            products: order.products.map { |p| { name: p.name, price: p.price } }
          }
        end
      }
    end

    # GET /orders/info/:id/download_invoice
    # Download the invoice for a specific order
    def download_invoice
      pdf = Prawn::Document.new
      pdf.text "Ravenboost Invoice ##{@order.internal_id}", size: 30, style: :bold
      pdf.move_down 20

      # Fetch user details
      user = @order.user
      pdf.text "Customer Name: #{user.first_name} #{user.last_name}"
      pdf.text "Email: #{user.email}"
      pdf.text "Order Date: #{@order.created_at.strftime('%B %d, %Y')}"
      pdf.move_down 20

      # Add line items and calculate totals
      pdf.text 'Order Details', size: 20, style: :bold
      pdf.move_down 10

      total_price = 0
      total_tax = 0

      # Iterate through products in the order
      @order.products.each do |product|
        # Assuming each product has a tax attribute
        product_tax = product.tax || 0
        product_total = product.price + product_tax

        pdf.text "#{product.name} - Price: $#{'%.2f' % product.price} - Tax: $#{'%.2f' % product_tax} - Total: $#{'%.2f' % product_total}"

        total_price += product.price
        total_tax += product_tax
      end

      # Calculate final totals
      final_total = total_price + total_tax

      pdf.move_down 20
      pdf.text "Total Price (Before Tax): $#{'%.2f' % total_price}"
      pdf.text "Total Tax: $#{'%.2f' % total_tax}"
      pdf.text "Final Total: $#{'%.2f' % final_total}", size: 16, style: :bold

      # Send the PDF file as a response
      send_data pdf.render, filename: "invoice_#{@order.internal_id}.pdf", type: 'application/pdf',
                            disposition: 'attachment'
    end

    # GET /orders/info/customer_unverified
    # Get completed orders that need customer verification for the current user
    def customer_unverified
      unless current_user
        return render json: { success: false, message: 'Authentication required.' }, status: :unauthorized
      end

      # Find completed orders for the current user that need verification
      unverified_orders = Order.where(
        user_id: current_user.id,
        state: 'complete',
        customer_verified_at: nil
      ).where.not(submitted_for_review_at: nil)
                               .includes(:user, :assigned_skill_master, :products)
                               .order(submitted_for_review_at: :desc)

      render json: {
        success: true,
        count: unverified_orders.count,
        orders: unverified_orders.map do |order|
          {
            id: order.id,
            internal_id: order.internal_id,
            state: order.state,
            total_price: order.total_price,
            created_at: order.created_at,
            submitted_for_review_at: order.submitted_for_review_at,
            before_image: order.before_image,
            after_image: order.after_image,
            skillmaster_submission_notes: order.skillmaster_submission_notes,
            skillmaster: {
              id: order.assigned_skill_master&.id,
              name: order.assigned_skill_master&.first_name,
              gamer_tag: order.assigned_skill_master&.gamer_tag
            },
            products: order.products.map do |product|
              {
                id: product.id,
                name: product.name,
                price: product.price,
                tax: product.tax
              }
            end
          }
        end
      }
    end

    private

    def render_view
      skill_master_info = User.find_by(id: @order.assigned_skill_master_id)
      user_info = User.find_by(id: @order.user_id)

      # Find platform safely
      platform = @order.platform.present? ? Platform.find_by(id: @order.platform) : nil

      # Handle platform credentials safely
      platform_credentials_data = if @order.platform_credential.present?
                                    @order.platform_credential.as_json(
                                      only: %i[id user_id created_at updated_at username password platform_id
                                               sub_platform_id]
                                    ).merge(
                                      platform: {
                                        id: @order.platform_credential.platform.id,
                                        name: @order.platform_credential.platform.name
                                      },
                                      sub_platform: {
                                        id: @order.platform_credential.sub_platform&.id,
                                        name: @order.platform_credential.sub_platform&.name
                                      }
                                    )
                                  else
                                    nil
                                  end

      render json: {
        order: @order.as_json(
          include: {
            products: {
              only: %i[id name price tax]
            }
          },
          only: %i[id state created_at total_price internal_id promo_data order_data]
        ).merge(
          platform: platform ? { id: platform.id, name: platform.name } : nil,
          user: {
            id: user_info&.id,
            first_name: user_info&.first_name,
            last_name: user_info&.last_name,
            email: user_info&.email,
            role: user_info&.role
          }
        ),
        platform_credentials: platform_credentials_data,
        skill_master: {
          id: skill_master_info&.id,
          gamer_tag: skill_master_info&.gamer_tag,
          first_name: skill_master_info&.first_name
        }
      }
    end

    def render_unauthorized
      render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
    end

    def assign_platform_credentials(order, platform_id)
      # Use the platform set on the order itself
      platform_id = order.platform

      if platform_id.present?
        # Find platform credential by user_id and platform_id
        platform_credential = PlatformCredential.find_by(user_id: order.user_id || current_user.id,
                                                         platform_id: platform_id)

        # Assign platform credential to the order if it exists
        if platform_credential
          order.platform_credential = platform_credential
          true
        else
          false
        end
      else
        false
      end
    end

    def add_products_to_order(order, product_ids)
      return if product_ids.blank?

      product_ids.each do |product_id|
        product = Product.find_by(id: product_id)
        if product
          order.order_products.create(product: product)
        else
          Rails.logger.warn "Product with ID #{product_id} not found"
        end
      end
    end

    # Set the order for actions that require it
    def set_order
      @order = Order.includes(:products, :user).find(params[:id])
    end

    # Upload completion images to S3 with webp format
    def upload_completion_image_to_s3(file, image_type)
      return nil if file.blank?

      # If the file is already a valid S3 URL, return it directly
      return file if file.is_a?(String) && file.match?(%r{^https?://.*\.amazonaws\.com/})

      if file.is_a?(ActionDispatch::Http::UploadedFile)
        obj = S3_BUCKET.object("orders/completion/#{image_type}/#{SecureRandom.uuid}.webp")
        obj.upload_file(file.tempfile, content_type: 'image/webp')
        obj.public_url
      elsif file.is_a?(String) && file.start_with?('data:image/')
        # Extract the base64 part from the data URL
        base64_data = file.split(',')[1]
        # Decode the base64 data
        decoded_data = Base64.decode64(base64_data)

        # Generate a unique filename for completion images
        filename = "orders/completion/#{image_type}/#{SecureRandom.uuid}.webp"

        # Create a temporary file to upload
        Tempfile.create(['completion_image', '.webp']) do |temp_file|
          temp_file.binmode
          temp_file.write(decoded_data)
          temp_file.rewind

          # Upload the temporary file to S3
          obj = S3_BUCKET.object(filename)
          obj.upload_file(temp_file, content_type: 'image/webp')

          return obj.public_url
        end
      else
        raise ArgumentError,
              "Expected an instance of ActionDispatch::Http::UploadedFile, a base64 string, or an S3 URL, got #{file.class.name}"
      end
    end

    def delete_completion_image_from_s3(image_url)
      return if image_url.blank?
      return unless image_url.match?(%r{^https?://.*\.amazonaws\.com/})

      # Extract the key from the S3 URL
      uri = URI.parse(image_url)
      key = uri.path[1..-1] # Remove the leading '/'

      begin
        S3_BUCKET.object(key).delete
      rescue StandardError => e
        Rails.logger.error "Failed to delete completion image from S3: #{e.message}"
      end
    end

    # Extract state parameter from various possible structures
    def extract_state_parameter
      # Check for direct state parameter
      return params[:state] if params[:state].present? && params[:state].is_a?(String)

      # Check for nested state in order params
      if params[:order].present? && params[:order][:state].present? && params[:order][:state].is_a?(String)
        return params[:order][:state]
      end

      # Check for state in completeStatusData (frontend might send it here)
      if params[:completeStatusData].present? && params[:completeStatusData][:state].present?
        return params[:completeStatusData][:state]
      end

      nil
    end

    # Extract completion data from various possible structures
    def extract_completion_data_parameter(params)
      completion_data = {}

      # Check for completeStatusData parameter
      if params[:completeStatusData].present?
        # Permit common completion data fields
        permitted_completion_data = params[:completeStatusData].permit(
          :before_image,
          :after_image,
          :skillmaster_submission_notes,
          :state,
          completion_data: {}
        )

        completion_data_hash = permitted_completion_data.to_h
        completion_data.merge!(completion_data_hash) if completion_data_hash.any?
      end

      # Check for completion data in order params
      if params[:order].present? && params[:order][:completion_data].present?
        completion_data.merge!(params[:order][:completion_data].to_unsafe_h)
      end

      # Check for individual completion fields
      %w[before_image after_image skillmaster_submission_notes].each do |field|
        if params[field].present?
          completion_data[field] = params[field]
        elsif params[:order].present? && params[:order][field].present?
          completion_data[field] = params[:order][field]
        end
      end

      completion_data
    end

    # Process completion data and upload images
    def process_completion_data(completion_data_param)
      completion_updates = {}

      # Process before and after images if provided (check both string and symbol keys)
      before_image = completion_data_param[:before_image] || completion_data_param['before_image']
      if before_image.present?
        Rails.logger.info 'Processing before image...'
        before_image_url = upload_completion_image_to_s3(before_image, 'before')
        completion_updates[:before_image] = before_image_url if before_image_url
        Rails.logger.info "Before image uploaded: #{before_image_url}"
      end

      after_image = completion_data_param[:after_image] || completion_data_param['after_image']
      if after_image.present?
        Rails.logger.info 'Processing after image...'
        after_image_url = upload_completion_image_to_s3(after_image, 'after')
        completion_updates[:after_image] = after_image_url if after_image_url
        Rails.logger.info "After image uploaded: #{after_image_url}"
      end

      # Handle skillmaster submission notes (check both string and symbol keys)
      submission_notes = completion_data_param[:skillmaster_submission_notes] || completion_data_param['skillmaster_submission_notes']
      completion_updates[:skillmaster_submission_notes] = submission_notes if submission_notes.present?

      # Log clean completion updates (no base64 data)
      Rails.logger.info "Completion updates: #{completion_updates}"

      # Debug validation before state change
      if completion_updates.any?
        @order.assign_attributes(completion_updates)
        @order.reload # Reset to original state
      end

      completion_updates
    end

    def order_params
      params.require(:order).permit(
        :user_id,
        :state,
        :total_price,
        :platform,
        :platform_credential_id,
        :promotion_id,
        :assigned_skill_master_id,
        :price,
        :tax,
        :dynamic_price,
        :start_level,
        :end_level,
        :before_image,
        :after_image,
        :skillmaster_submission_notes,
        order_data: [],
        completion_data: {}
      )
    end

    def calculate_order_totals(order_data)
      return { total_price: 0, tax: 0 } if order_data.blank?

      total_price = 0
      total_tax = 0

      # Parse the order_data array and sum up prices and taxes
      order_data.each do |item|
        item = JSON.parse(item) if item.is_a?(String)

        # Get quantity from either item_qty or quantity, defaulting to 1
        quantity = item['item_qty'].present? ? item['item_qty'] : (item['quantity'] || 1)

        item_price = item['price'].to_f
        item_tax = item['tax'].to_f

        # Add tax to the price for total calculation
        total_price += item_price + (item_tax * quantity)
        total_tax += item_tax * quantity
      end

      { total_price: total_price, tax: total_tax }
    end
  end
end
