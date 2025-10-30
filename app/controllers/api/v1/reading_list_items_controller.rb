# frozen_string_literal: true

module Api
  module V1
    # API controller for reading list CRUD operations
    class ReadingListItemsController < AuthenticatedController
      before_action :set_reading_list_item, only: %i[show update destroy]

      # GET /api/v1/reading_list_items
      def index
        items = current_user.reading_list_items
          .then { |scope| apply_status_filter(scope) }
          .then { |scope| apply_tag_filter(scope) }
          .recent
          .limit(params[:limit] || 100)

        render json: {
          success: true,
          data: {
            reading_list_items: items.as_json(methods: :estimated_read_minutes),
            count: items.size
          }
        }
      end

      # GET /api/v1/reading_list_items/:id
      def show
        render json: {
          success: true,
          data: {
            reading_list_item: @reading_list_item.as_json(methods: :estimated_read_minutes)
          }
        }
      end

      # POST /api/v1/reading_list_items
      def create
        item = current_user.reading_list_items.build(reading_list_item_params)

        if item.save
          render json: {
            success: true,
            message: 'Item added to reading list',
            data: { reading_list_item: item.as_json(methods: :estimated_read_minutes) }
          }, status: :created
        else
          render_error_response(
            message: 'Failed to add item to reading list',
            errors: item.errors.full_messages
          )
        end
      end

      # PATCH/PUT /api/v1/reading_list_items/:id
      def update
        if @reading_list_item.update(reading_list_item_params)
          render json: {
            success: true,
            message: 'Reading list item updated',
            data: { reading_list_item: @reading_list_item.as_json(methods: :estimated_read_minutes) }
          }
        else
          render_error_response(
            message: 'Failed to update reading list item',
            errors: @reading_list_item.errors.full_messages
          )
        end
      end

      # DELETE /api/v1/reading_list_items/:id
      def destroy
        @reading_list_item.destroy!

        render json: {
          success: true,
          message: 'Reading list item removed'
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to remove reading list item',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      # POST /api/v1/reading_list_items/:id/mark_reading
      def mark_reading
        set_reading_list_item
        @reading_list_item.mark_as_reading!

        render json: {
          success: true,
          message: 'Item marked as reading',
          data: { reading_list_item: @reading_list_item }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to update status',
          errors: [e.message]
        )
      end

      # POST /api/v1/reading_list_items/:id/mark_completed
      def mark_completed
        set_reading_list_item
        @reading_list_item.mark_as_completed!

        render json: {
          success: true,
          message: 'Item marked as completed',
          data: { reading_list_item: @reading_list_item }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to update status',
          errors: [e.message]
        )
      end

      # POST /api/v1/reading_list_items/:id/mark_dismissed
      def mark_dismissed
        set_reading_list_item
        @reading_list_item.mark_as_dismissed!

        render json: {
          success: true,
          message: 'Item marked as dismissed',
          data: { reading_list_item: @reading_list_item }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to update status',
          errors: [e.message]
        )
      end

      private

      def set_reading_list_item
        @reading_list_item = current_user.reading_list_items.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error_response(
          message: 'Reading list item not found',
          status: :not_found
        )
      end

      def reading_list_item_params
        params.require(:reading_list_item).permit(
          :page_visit_id,
          :url,
          :title,
          :domain,
          :added_from,
          :status,
          :estimated_read_time,
          :notes,
          :scheduled_for,
          tags: []
        )
      end

      def apply_status_filter(scope)
        return scope if params[:status].blank?

        scope.where(status: params[:status])
      end

      def apply_tag_filter(scope)
        return scope if params[:tags].blank?

        tags = Array(params[:tags])
        scope.with_tags(tags)
      end

      def render_error_response(message:, errors: nil, status: :unprocessable_entity)
        render json: {
          success: false,
          message:,
          errors:
        }, status:
      end
    end
  end
end
