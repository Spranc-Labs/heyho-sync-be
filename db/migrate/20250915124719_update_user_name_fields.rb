class UpdateUserNameFields < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string

    # Migrate existing data (split name into first and last)
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          if user.name.present?
            parts = user.name.split(' ', 2)
            user.update_columns(
              first_name: parts[0],
              last_name: parts[1] || ''
            )
          end
        end
      end
    end

    remove_column :users, :name, :string
  end
end