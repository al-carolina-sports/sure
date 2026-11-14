# One family's classification of a shared security. The row is the whole
# override: allocation reads it before the security's own columns, and a
# provider sync never writes here, so it cannot replace the choice.
#
# `category` is the net-worth slice. Crypto is one of those slices and is
# not a Security asset class (the column's check constraint has no crypto
# value), so a crypto choice leaves asset_class empty and records the
# cryptocurrency sub-class.
class FamilySecurityClassification < ApplicationRecord
  CATEGORIES = %w[equity fixed_income cash crypto real_estate private_equity other].freeze

  # Private equity uses the alternative_investment class the securities
  # table already allows, plus the private_equity sub-class. Other has no
  # class of its own; storing it as alternative_investment would make the
  # next read treat it as private equity.
  CATEGORY_ASSET_CLASS = {
    "equity" => "equity",
    "fixed_income" => "fixed_income",
    "cash" => "liquidity",
    "real_estate" => "real_estate",
    "private_equity" => "alternative_investment"
  }.freeze

  belongs_to :family
  belongs_to :security

  validates :security_id, uniqueness: { scope: :family_id }
  validates :category, inclusion: { in: CATEGORIES }
  validates :asset_class, inclusion: { in: Security::ASSET_CLASSES }, allow_nil: true
  validates :asset_sub_class, inclusion: { in: Security::ASSET_SUB_CLASSES }, allow_nil: true

  normalizes :asset_sub_class, :sector, :region, with: ->(value) { value.presence }

  before_validation :apply_category_columns

  private
    # The form asks for a slice. The taxonomy columns are filled from that
    # slice unless the household already picked a sub-class.
    def apply_category_columns
      if category == "crypto"
        self.asset_class = nil
        self.asset_sub_class = "cryptocurrency" if asset_sub_class.blank?
      elsif category == "private_equity"
        self.asset_class = "alternative_investment"
        self.asset_sub_class = "private_equity" if asset_sub_class.blank?
      elsif category == "other"
        self.asset_class = nil
      else
        self.asset_class = CATEGORY_ASSET_CLASS[category]
        self.asset_sub_class = "cash" if category == "cash" && asset_sub_class.blank?
      end
    end
end
