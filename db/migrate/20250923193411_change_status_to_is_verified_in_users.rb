class ChangeStatusToIsVerifiedInUsers < ActiveRecord::Migration[7.0]
  def up
    # Add isVerified boolean column first
    add_column :users, :isVerified, :boolean, default: false, null: false

    # Migrate data: verified (1) -> true, unverified (2) -> false, closed (3) -> false
    User.find_each do |user|
      user.update_column(:isVerified, user.status == 1)
    end

    # Remove the old status column
    remove_column :users, :status
  end

  def down
    # Add status column back
    add_column :users, :status, :integer, default: 2, null: false

    # Migrate data back: true -> verified (1), false -> unverified (2)
    User.find_each do |user|
      user.update_column(:status, user.isVerified? ? 1 : 2)
    end

    # Remove isVerified column
    remove_column :users, :isVerified
  end
end
