class AddNameOnlyAuthenticationToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :name_only, :boolean, default: false, null: false
    add_column :identities, :recovery_token_digest, :string
    add_index :identities, :recovery_token_digest, unique: true
  end
end
