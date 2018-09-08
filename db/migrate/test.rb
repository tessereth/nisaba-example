class DropSecretSauceFromMagic < ActiveRecord::Migration[5.2]
  def change
    remove_column :magics, :secret_sauce, :string
  end
end
