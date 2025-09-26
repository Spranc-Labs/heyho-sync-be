# frozen_string_literal: true

module EmailHelpers
  def clear_email_queue
    ActionMailer::Base.deliveries.clear
  end

  def last_email
    ActionMailer::Base.deliveries.last
  end

  def email_count
    ActionMailer::Base.deliveries.count
  end

  def emails_sent_to(email_address)
    ActionMailer::Base.deliveries.select { |email| email.to.include?(email_address) }
  end
end

RSpec.configure do |config|
  config.include EmailHelpers, type: :request

  config.before do
    ActionMailer::Base.deliveries.clear
  end
end
