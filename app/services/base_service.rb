# frozen_string_literal: true

class BaseService
  # Standard Result object for all services
  Result = Struct.new(:success, :data, :errors, :message, keyword_init: true) do
    alias_method :success?, :success

    def failure?
      !success
    end

    def error_messages
      return [] unless errors

      Array(errors).flatten.compact
    end
  end

  # Class-level call method pattern
  def self.call(...)
    new(...).call
  end

  private

  # Result builder methods
  def success_result(data: nil, message: nil)
    Result.new(success: true, data:, message:, errors: [])
  end

  def failure_result(errors: [], message: nil)
    Result.new(success: false, data: nil, message:, errors: Array(errors))
  end

  # Logging helpers
  def log_info(message)
    Rails.logger.info "[#{self.class.name}] #{message}"
  end

  def log_error(message, error = nil)
    if error
      Rails.logger.error "[#{self.class.name}] #{message}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    else
      Rails.logger.error "[#{self.class.name}] #{message}"
    end
  end

  # Validation helpers
  def validate_presence_of(*attributes, object:)
    missing = attributes.select { |attr| object.send(attr).blank? }
    return true if missing.empty?

    errors = missing.map { |attr| "#{attr.to_s.humanize} is required" }
    failure_result(errors:, message: 'Validation failed')
  end
end
