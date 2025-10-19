# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'noreply@heyho.com'
  layout 'mailer'
end
