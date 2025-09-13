# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.2.0'

gem 'rails', '~> 7.0.0'

gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'redis', '>= 4.0'

gem 'bootsnap', require: false

gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
  gem 'rspec-rails', '~> 6.0'

  # Code quality tools
  gem 'rubocop', '~> 1.56', require: false
  gem 'rubocop-performance', '~> 1.19', require: false
  gem 'rubocop-rails', '~> 2.21', require: false
  gem 'rubocop-rspec', '~> 2.24', require: false

  # Security scanning
  gem 'brakeman', '~> 6.0', require: false

  # Documentation
  gem 'yard', '~> 0.9', require: false
  gem 'yard-activerecord', '~> 0.0.16', require: false

  # Git hooks
  gem 'lefthook', '~> 1.4', require: false
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver', '~> 4.10'
end
