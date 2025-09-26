# Codebase Style Guide for HeyHo Sync API

This guide helps maintain consistency with Ruby, Rails, and RSpec best practices based on:
- [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide)
- [Rails Style Guide](https://github.com/rubocop/rails-style-guide)
- [Better Specs](https://www.betterspecs.org)

## Ruby Style Guide

### Layout & Formatting
- **2 spaces** for indentation (no tabs)
- **Max 120 characters** per line
- No trailing whitespace
- End files with newline
- One empty line between method definitions
- No empty lines around method/class/module body

### Naming Conventions
- **snake_case** for methods and variables
- **CamelCase** for classes and modules
- **SCREAMING_SNAKE_CASE** for constants
- Predicate methods end with `?` (return boolean)
- Dangerous methods end with `!` (modify self or raise)
- Avoid single letter variables except counters

### Syntax Rules
```ruby
# Good
def some_method
  # body
end

# Bad
def some_method; body; end

# Use keyword arguments for 3+ parameters
def complex_method(required_arg, optional: 'default', keyword:)
  # body
end

# Prefer symbol to proc
users.map(&:name)  # Good
users.map { |u| u.name }  # Bad

# String interpolation over concatenation
"Hello, #{name}!"  # Good
"Hello, " + name + "!"  # Bad

# Frozen string literal on every file
# frozen_string_literal: true

# Guard clauses over nested conditionals
return unless valid?  # Good
```

### Collections & Enumerables
```ruby
# Prefer literal syntax
array = []  # Good
hash = {}   # Good

# Multi-line arrays/hashes
users = [
  alice,
  bob,
  charlie
]

# Use %w for word arrays
STATES = %w[pending active completed]

# Prefer select/reject over select!/reject!
users.select(&:active?)  # Good
```

## Rails Style Guide

### Models
```ruby
class User < ApplicationRecord
  # Constants
  ROLES = %w[admin user guest].freeze

  # Includes and extends
  include Tokenable
  extend FriendlyId

  # Attributes
  attr_accessor :login

  # Associations (belongs_to, has_one, has_many)
  belongs_to :account
  has_many :posts, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :age, numericality: { greater_than: 0 }

  # Callbacks (in lifecycle order)
  before_validation :normalize_email
  after_create :send_welcome_email

  # Scopes
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.find_by_email(email)
    find_by(email: email.downcase)
  end

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def normalize_email
    self.email = email.downcase.strip
  end
end
```

### Controllers
```ruby
class UsersController < ApplicationController
  # Callbacks in order
  before_action :authenticate_user!
  before_action :set_user, only: %i[show edit update destroy]

  # RESTful actions in order
  def index
    @users = User.page(params[:page])
  end

  def show
    # Implicit render
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to @user, notice: 'User created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Implicit render
  end

  def update
    if @user.update(user_params)
      redirect_to @user, notice: 'User updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    redirect_to users_url, notice: 'User deleted.'
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
```

### Service Objects
```ruby
module Users
  class ProfileService
    def self.call(user, params)
      new(user, params).call
    end

    def initialize(user, params)
      @user = user
      @params = params
    end

    def call
      return failure('Invalid params') unless valid?

      if @user.update(@params)
        success(@user)
      else
        failure(@user.errors.full_messages)
      end
    end

    private

    def valid?
      @params.present?
    end

    def success(data)
      Result.new(success: true, data: data)
    end

    def failure(errors)
      Result.new(success: false, errors: Array(errors))
    end

    Result = Struct.new(:success, :data, :errors, keyword_init: true) do
      alias success? success
      def failure? = !success
    end
  end
end
```

### Migrations
```ruby
class AddEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email, :string, null: false
    add_index :users, :email, unique: true
  end
end
```

### ActiveRecord Queries
```ruby
# Use query methods over raw SQL
User.where(active: true)  # Good
User.where('active = ?', true)  # Avoid

# Use pluck for single attributes
User.pluck(:email)  # Good
User.map(&:email)  # Bad for DB queries

# Batch processing for large datasets
User.find_each do |user|
  user.process!
end

# Eager loading to avoid N+1
User.includes(:posts).where(posts: { published: true })
```

## RSpec Best Practices

### Test Structure
```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User do
  # Use described_class
  subject { described_class.new(params) }

  # Group tests logically
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:posts).dependent(:destroy) }
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns the full name' do
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe '.active' do
    let!(:active_user) { create(:user, active: true) }
    let!(:inactive_user) { create(:user, active: false) }

    it 'returns only active users' do
      expect(described_class.active).to contain_exactly(active_user)
    end
  end
end
```

### Request Specs
```ruby
# spec/requests/users_spec.rb
require 'rails_helper'

RSpec.describe 'Users API' do
  let(:user) { create(:user) }
  let(:valid_params) { { user: attributes_for(:user) } }
  let(:invalid_params) { { user: { email: '' } } }

  describe 'GET /users/:id' do
    before { get user_path(user) }

    it 'returns success' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns the user' do
      expect(response.parsed_body['id']).to eq(user.id)
    end
  end

  describe 'POST /users' do
    context 'with valid params' do
      it 'creates a new user' do
        expect do
          post users_path, params: valid_params
        end.to change(User, :count).by(1)
      end

      it 'returns created status' do
        post users_path, params: valid_params
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      before { post users_path, params: invalid_params }

      it 'returns unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns errors' do
        expect(response.parsed_body['errors']).to be_present
      end
    end
  end
end
```

### RSpec Guidelines
- **Describe methods** with `#instance_method` or `.class_method`
- **One expectation** per test when possible
- **Use contexts** to group conditions (with/without, when/if)
- **Use let/let!** over instance variables
- **Use factories** over fixtures
- **Test behavior**, not implementation
- **Avoid stubbing** the system under test
- **Use shared examples** for common behavior

```ruby
# Good test descriptions
it 'returns the user name'  # Good
it 'should return name'  # Bad (avoid 'should')
it 'works'  # Bad (too vague)

# Use factory_bot
let(:user) { create(:user) }  # Good
let(:user) { User.create!(name: 'Test') }  # Avoid

# Test the behavior
it 'sends an email' do
  expect { service.call }.to have_enqueued_mail(UserMailer, :welcome)
end
```

## API Specific Conventions

### JSON Responses
```ruby
# Consistent response structure
def render_json_response(success:, message: nil, data: nil, errors: nil)
  render json: {
    success: success,
    message: message,
    data: data,
    errors: errors
  }.compact
end

def render_error_response(message:, errors: nil, status: :unprocessable_entity)
  render_json_response(
    success: false,
    message: message,
    errors: errors
  ), status: status
end
```

### Strong Parameters
```ruby
private

def user_params
  params.require(:user).permit(
    :email,
    :first_name,
    :last_name,
    profile_attributes: [:bio, :avatar]
  )
end
```

## Commands to Run

Before committing:
```bash
# Run tests
make test

# Run linter
make lint

# Auto-fix linting issues
make lint-fix

# Run specific tests
make test-users
make test-auth
make test-verification
```

## Quality Assurance & Pre-commit

### Pre-commit Hook
The project includes a comprehensive pre-commit hook that ensures code quality:

1. **Installation**: `make hooks-install`
2. **Manual Test**: `make hooks-test`

#### Checks Performed:
- ✅ **Debugging statements** - No `binding.pry`, `byebug`, `debugger`
- ✅ **Code style** - RuboCop linting and formatting
- ✅ **Security** - Brakeman security scanning (if installed)
- ✅ **Schema consistency** - Migration/schema.rb alignment
- ✅ **Tests** - Run specs for changed files
- ✅ **File size** - Prevent large files (>1MB)
- ✅ **Merge conflicts** - Detect conflict markers
- ✅ **YAML validation** - Ensure valid YAML syntax

#### Bypassing Hooks (Emergency Only):
```bash
git commit --no-verify -m "Emergency fix"
```

### Continuous Quality Checks:
```bash
make lint          # Run RuboCop
make lint-fix      # Auto-fix RuboCop issues
make test          # Run all tests
make test-fast     # Run tests with fail-fast
make quality-check # Full quality suite
```

## Project Structure
```
app/
├── controllers/
│   ├── api/v1/          # Versioned API controllers
│   └── concerns/         # Shared controller modules
├── models/
│   └── concerns/         # Shared model modules
├── services/             # Business logic
│   ├── authentication/   # Auth services
│   └── users/           # User services
├── serializers/          # JSON serialization
└── mailers/             # Email handlers

spec/
├── models/              # Model tests
├── requests/            # API endpoint tests
├── services/            # Service object tests
└── support/             # Test helpers
```

## Key Principles
1. **Skinny Controllers, Fat Models** (but use Service Objects for complex logic)
2. **RESTful routes** and conventional action names
3. **Fail fast** with guard clauses
4. **Explicit is better than implicit**
5. **DRY** but not at the expense of readability
6. **Test behavior, not implementation**
7. **Separate concerns** using modules and services
8. **Follow Rails conventions** unless there's a good reason not to

## Remember
- Always add `# frozen_string_literal: true` to Ruby files
- Run `make lint` before committing
- Keep methods under 20 lines
- Keep classes under 150 lines
- Use meaningful variable and method names
- Write tests for all new code
- Document complex logic with comments