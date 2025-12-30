class AddDeviseToEmployees < ActiveRecord::Migration[7.1]
  def change
    # Database authenticatable
    add_column :employees, :encrypted_password, :string, null: false, default: ""

    # Recoverable
    add_column :employees, :reset_password_token, :string
    add_column :employees, :reset_password_sent_at, :datetime

    # Rememberable
    add_column :employees, :remember_created_at, :datetime

    # Trackable (optional, commented out by default)
    # add_column :employees, :sign_in_count, :integer, default: 0, null: false
    # add_column :employees, :current_sign_in_at, :datetime
    # add_column :employees, :last_sign_in_at, :datetime
    # add_column :employees, :current_sign_in_ip, :string
    # add_column :employees, :last_sign_in_ip, :string

    add_index :employees, :reset_password_token, unique: true
  end
end
