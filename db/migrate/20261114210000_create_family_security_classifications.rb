# frozen_string_literal: true

# A household's own classification for a security. Securities are shared
# across families, so writing asset_class on the security and locking it
# would decide the slice for every household and would stop a provider from
# filling the shared row later. This table is the override one family chose.
class CreateFamilySecurityClassifications < ActiveRecord::Migration[8.1]
  def change
    create_table :family_security_classifications, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :security, null: false, foreign_key: true, type: :uuid
      t.string :category, null: false
      t.string :asset_class
      t.string :asset_sub_class
      t.string :sector
      t.string :region
      t.timestamps
    end

    add_index :family_security_classifications, [ :family_id, :security_id ],
      unique: true,
      name: "index_family_security_classifications_on_family_and_security"
  end
end
