class AddBackStatusToUsers < ActiveRecord::Migration[7.0]
  def up
    # Add status column back for Rodauth compatibility
    add_column :users, :status, :integer, default: 2, null: false

    # Sync data: isVerified true -> status 1 (verified), isVerified false -> status 2 (unverified)
    User.find_each do |user|
      user.update_column(:status, user.isVerified? ? 1 : 2)
    end
  end

  def down
    # Remove status column
    remove_column :users, :status
  end
end
