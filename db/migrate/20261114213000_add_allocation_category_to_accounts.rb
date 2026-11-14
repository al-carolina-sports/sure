# frozen_string_literal: true

# A household's choice for an entire account. Accounts already belong to one
# family, so this column is that family's override and a provider sync does
# not write it. Nil means the account follows the usual type and holding rules.
class AddAllocationCategoryToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :allocation_category, :string

    add_check_constraint :accounts,
      "allocation_category IS NULL OR allocation_category IN ('equity', 'fixed_income', 'cash', 'crypto', 'real_estate', 'private_equity', 'other')",
      name: "chk_accounts_allocation_category"
  end
end
