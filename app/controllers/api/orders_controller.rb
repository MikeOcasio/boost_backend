module Api
  class OrdersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_order, only: [:show, :update, :destroy, :pick_up_order]

    # GET /api/orders
    # Fetch all orders. Only accessible by admins, devs, or specific roles as determined by other methods.
    def index
      @orders = Order.all
      render json: @orders
    end

    # GET /api/orders/:id
    # Show details of a specific order.
    # Skill masters can only see their own assigned orders with platform credentials.
    # Admins and devs can see all orders.
    def show
      if current_user.skill_master? && @order.assigned_skill_master_id == current_user.id
        render json: { order: @order, platform_credentials: @order.platform_credential }
      elsif current_user.admin? || current_user.dev?
        render json: @order
      else
        render json: { success: false, message: "Unauthorized action." }, status: :forbidden
      end
    end

    # POST /api/orders
    # Create a new order.
    # Admins and devs can create orders for any user and attach platform credentials.
    # Customers can create their own orders and attach their own platform credentials.
    def create
      if current_user.admin? || current_user.dev?
        @order = Order.new(order_params)

        # Assign platform credentials if provided
        if params[:platform_credential_id]
          platform_credential = PlatformCredential.find_by(id: params[:platform_credential_id], user_id: @order.user_id)
          @order.platform_credential = platform_credential if platform_credential
        end

        if @order.save
          render json: @order, status: :created
        else
          render json: @order.errors, status: :unprocessable_entity
        end
      elsif current_user.customer?
        @order = Order.new(order_params.merge(user_id: current_user.id, assigned_skill_master_id: nil))

        # Check if customer has provided platform credentials and attach them to the order
        if params[:platform_credential_id]
          platform_credential = PlatformCredential.find_by(id: params[:platform_credential_id], user_id: current_user.id)
          if platform_credential
            @order.platform_credential = platform_credential
          else
            return render json: { success: false, message: "Invalid platform credential." }, status: :unprocessable_entity
          end
        end

        if @order.save
          render json: @order, status: :created
        else
          render json: @order.errors, status: :unprocessable_entity
        end
      else
        render json: { success: false, message: "Unauthorized action." }, status: :forbidden
      end
    end

    # PATCH/PUT /api/orders/:id
    # Update an existing order.
    # Admins and devs can update any order, while skill masters can only update the order status if applicable.
    def update
      if current_user.admin? || current_user.dev?
        if @order.update(order_params)
          render json: @order
        else
          render json: @order.errors, status: :unprocessable_entity
        end
      elsif current_user.skill_master? && order_params.key?(:aasm_state)
        if @order.update(status: order_params[:aasm_state])
          render json: @order
        else
          render json: @order.errors, status: :unprocessable_entity
        end
      else
        render json: { success: false, message: "Unauthorized action." }, status: :forbidden
      end
    end

    # DELETE /api/orders/:id
    # Delete an existing order.
    # Only accessible by admins or devs.
    def destroy
      if current_user.admin? || current_user.dev?
        @order.destroy
        head :no_content
      else
        render json: { success: false, message: "Unauthorized action." }, status: :forbidden
      end
    end

    # Method to retrieve orders in the graveyard pool (unassigned orders).
    def graveyard_orders
      @graveyard_orders = Order.where(assigned_skill_master_id: nil)
      render json: @graveyard_orders
    end

    # POST /api/orders/:id/pick_up_order
    # Assign an order to a skill master. Only accessible by admins, devs, or skill masters.
    # Skill masters can only pick up orders that match their platform.
    def pick_up_order
      # Check user role and determine the skill master ID
      if current_user.admin? || current_user.dev?
        skill_master_id = params[:assigned_skill_master_id] || current_user.id
      elsif current_user.skill_master?
        skill_master_id = current_user.id
      else
        return render json: { success: false, message: "Unauthorized action." }, status: :forbidden
      end

      # Find the skill master and check their platforms if they are a skill master
      if current_user.skill_master?
        skill_master_platforms = current_user.platforms
        order_platform = @order.platform

        unless skill_master_platforms.include?(order_platform)
          return render json: { success: false, message: "Order platform does not match skill master's platforms." }, status: :forbidden
        end
      end

      # Assign the order to the skill master
      if @order.update(assigned_skill_master_id: skill_master_id)
        render json: { success: true, message: "Order #{@order.id} picked up successfully!" }
      else
        render json: { success: false, message: "Failed to pick up order." }, status: :unprocessable_entity
      end
    end

    # GET /orders/:id/download_invoice
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
      pdf.text "Order Details", size: 20, style: :bold
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
      send_data pdf.render, filename: "invoice_#{@order.internal_id}.pdf", type: 'application/pdf', disposition: 'attachment'
    end

    private

    # Set the order for actions that require it
    def set_order
      @order = Order.includes(:products, :user).find(params[:id])
    end

    # Strong parameters for order creation and update
    def order_params
      params.require(:order).permit(:user_id, :aasm_state, :assigned_skill_master_id, :total_price, :tax, :price, :platform)
    end
  end
end
