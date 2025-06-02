module Orders
  class OrdersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_order, only: %i[show update destroy pick_up_order]

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
              platform: { id: platform.id, name: platform.name },
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
      if current_user&.id == @order.user_id
        render_view
      elsif current_user&.id == @order.assigned_skill_master_id &&
            (current_user&.role == 'skillmaster' || current_user&.role.in?(%w[admin dev]))
        render_view
      else
        render_unauthorized
      end
    end

    # POST orders/info
    def create
      session_id = params[:session_id]

      if current_user.role == 'dev'
        @order = Order.new(order_params)
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
      elsif current_user.role.in?(%w[customer skillmaster admin]) && session_id.present?
        process_stripe_checkout(session_id)
      else
        render json: { success: false, message: 'Unauthorized action.' }, status: :forbidden
      end
    end

    # PATCH/PUT /api/orders/:id
    # Update an existing order.
    # Admins and devs can update any order, while skill masters can only update the order status if applicable.
    def update
      if current_user.role == 'admin' || current_user.role == 'dev'
        # Allow admin/dev to update any attribute
        if order_params.key?(:state)
          # Validate and transition the state based on the provided value
          case order_params[:state]
          when 'in_progress'
            if @order.may_start_progress?
              @order.start_progress!
            else
              return render json: { success: false, message: 'Order cannot transition to in progress.' },
                            status: :unprocessable_entity
            end
          when 'complete'
            if @order.may_complete_order?
              @order.complete_order!
            else
              return render json: { success: false, message: 'Order cannot be marked as complete.' },
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
        # Skill masters can only update the state
        if order_params.key?(:state)
          case order_params[:state]
          when 'in_progress'
            if @order.may_start_progress?
              @order.start_progress!
              render json: @order
            else
              render json: { success: false, message: 'Order cannot transition to in progress.' },
                     status: :unprocessable_entity
            end
          when 'complete'
            if @order.may_complete_order?
              @order.complete_order!
              render json: @order
            else
              render json: { success: false, message: 'Order cannot be marked as complete.' },
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
            render json: { success: false, message: 'Invalid state transition.' }, status: :unprocessable_entity
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
          order.merge(platform: { id: platform.id, name: platform.name }) # Add platform info or nil
        end
      }
    end

    # POST orders/info/:id/pick_up_order
    # Assign an order to a skill master. Only accessible by admins, devs, or skill masters.
    # Skill masters can only pick up orders that match their platform.
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

    private

    def render_view
      skill_master_info = User.find_by(id: @order.assigned_skill_master_id)
      user_info = User.find_by(id: @order.user_id)

      render json: {
        order: @order.as_json(
          include: {
            products: {
              only: %i[id name price tax]
            }
          },
          only: %i[id state created_at total_price internal_id promo_data order_data]
        ).merge(
          platform: {
            id: @order.platform,
            name: Platform.find(@order.platform).name
          },
          user: {
            id: user_info&.id,
            first_name: user_info&.first_name,
            last_name: user_info&.last_name,
            email: user_info&.email,
            role: user_info&.role
          }
        ),
        platform_credentials: @order.platform_credential.as_json(
          only: %i[id user_id created_at updated_at username password platform_id sub_platform_id]
        ).merge(
          platform: {
            id: @order.platform_credential.platform.id,
            name: @order.platform_credential.platform.name
          },
          sub_platform: {
            id: @order.platform_credential.sub_platform&.id,
            name: @order.platform_credential.sub_platform&.name
          }
        ),
        skill_master: {
          id: skill_master_info&.id,
          gamer_tag: skill_master_info&.gamer_tag,
          first_name: skill_master_info&.first_name
        }
      }
    end

    def process_stripe_checkout(session_id)
      session = Stripe::Checkout::Session.retrieve(session_id)
      if session.payment_status == 'paid'
        @order = Order.new(order_params.merge(user_id: current_user.id, assigned_skill_master_id: nil))
        @order.platform = params[:platform] if params[:platform].present?
        @order.promo_data = params[:promo_data] if params[:promo_data].present?
        @order.order_data = params[:order_data] if params[:order_data].present?

        if assign_platform_credentials(@order, params[:platform]) && @order.save
          add_products_to_order(@order, params[:product_ids])
          @order.update(total_price: calculate_order_totals(params[:order_data]))

          render json: { success: true, order_id: @order.id }, status: :created
        else
          render json: { success: false, errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { success: false, message: 'Payment not successful.' }, status: :unprocessable_entity
      end
    rescue Stripe::InvalidRequestError => e
      render json: { success: false, message: e.message }, status: :unprocessable_entity
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

    # Strong parameters for order creation and update

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
        order_data: []
      )
    end

    def calculate_order_totals(order_data)
      return { total_price: 0, tax: 0 } if order_data.blank?

      total_price = 0
      total_tax = 0
      promo_discount = 0

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
