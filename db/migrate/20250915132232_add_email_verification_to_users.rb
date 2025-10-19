class AddEmailVerificationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email_verified, :boolean, default: false
    add_column :users, :email_verified_at, :datetime
    add_column :users, :verification_token, :string
    add_column :users, :verification_token_expires_at, :datetime
    add_column :users, :pending_email, :string
    add_column :users, :email_change_token, :string
    add_column :users, :email_change_token_expires_at, :datetime

    add_index :users, :verification_token, unique: true
    add_index :users, :email_change_token, unique: true
  end
end
