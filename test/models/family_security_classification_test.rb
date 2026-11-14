require "test_helper"

class FamilySecurityClassificationTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @security = securities(:aapl)
  end

  test "a crypto choice maps to the crypto slice without an asset class" do
    classification = @family.security_classifications.create!(security: @security, category: "crypto")

    assert_nil classification.asset_class
    assert_equal "cryptocurrency", classification.asset_sub_class
  end

  test "cash stores the liquidity asset class the securities table allows" do
    classification = @family.security_classifications.create!(security: @security, category: "cash")

    assert_equal "liquidity", classification.asset_class
    assert_equal "cash", classification.asset_sub_class
  end

  test "private equity uses the alternative investment class and its sub-class" do
    classification = @family.security_classifications.create!(security: @security, category: "private_equity")

    assert_equal "alternative_investment", classification.asset_class
    assert_equal "private_equity", classification.asset_sub_class
  end

  test "other does not take the alternative investment class" do
    classification = @family.security_classifications.create!(security: @security, category: "other")

    assert_nil classification.asset_class
  end

  test "a chosen sub-class is kept" do
    classification = @family.security_classifications.create!(
      security: @security,
      category: "equity",
      asset_sub_class: "etf"
    )

    assert_equal "equity", classification.asset_class
    assert_equal "etf", classification.asset_sub_class
  end

  test "one household cannot store two rows for the same security" do
    @family.security_classifications.create!(security: @security, category: "equity")

    duplicate = @family.security_classifications.create(security: @security, category: "other")

    assert_not duplicate.persisted?
  end
end
