class CleanupDeviseSchema < ActiveRecord::Migration[7.0]
  def change
    # Drop Devise-related tables (keep jwt_denylists for Rodauth JWT revocation)
    drop_table :refresh_tokens if table_exists?(:refresh_tokens)
    
    # Remove Devise columns from users table  
    remove_column :users, :encrypted_password, :string if column_exists?(:users, :encrypted_password)
    remove_column :users, :reset_password_token, :string if column_exists?(:users, :reset_password_token)
    remove_column :users, :reset_password_sent_at, :datetime if column_exists?(:users, :reset_password_sent_at)
    remove_column :users, :remember_created_at, :datetime if column_exists?(:users, :remember_created_at)
    remove_column :users, :email_verified, :boolean if column_exists?(:users, :email_verified)
    remove_column :users, :email_verified_at, :datetime if column_exists?(:users, :email_verified_at)
    remove_column :users, :verification_token, :string if column_exists?(:users, :verification_token)
    remove_column :users, :verification_token_expires_at, :datetime if column_exists?(:users, :verification_token_expires_at)
    remove_column :users, :pending_email, :string if column_exists?(:users, :pending_email)
    remove_column :users, :email_change_token, :string if column_exists?(:users, :email_change_token)
    remove_column :users, :email_change_token_expires_at, :datetime if column_exists?(:users, :email_change_token_expires_at)
    
    # Add columns for Rodauth compatibility
    add_column :users, :password_hash, :string unless column_exists?(:users, :password_hash)
    add_column :users, :status, :integer, null: false, default: 2 unless column_exists?(:users, :status) # verified status
    
    # Enable citext extension if not already enabled
    enable_extension "citext" unless extension_enabled?("citext")
    
    # Change email column to citext for case-insensitive uniqueness
    change_column :users, :email, :citext
  end
end
