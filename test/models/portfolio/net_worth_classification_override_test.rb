require "test_helper"

class Portfolio::NetWorthClassificationOverrideTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @account = Account.create!(
      family: @family, name: "Brokerage", balance: 100, cash_balance: 0, currency: "USD",
      accountable: Investment.new
    )
  end

  test "a family override beats the ticker default and a blank asset class" do
    security = Security.create!(ticker: "VTI", name: "", exchange_operating_mic: "XNAS")
    Holding.create!(account: @account, security: security, date: Date.current, qty: 1, price: 100, amount: 100, currency: "USD")
    FamilySecurityClassification.create!(family: @family, security: security, category: "crypto")

    allocation = Portfolio::NetWorthAllocation.new(family: @family)

    assert_equal [ "crypto" ], allocation.segments.map(&:id)
    assert_not security.reload.classification_locked
    assert_nil security.asset_class
  end

  test "an unrecognised manual ticker stays unclassified and a known fund does not" do
    custom = Security.create!(ticker: "PRIV", name: "", exchange_operating_mic: "XNAS")
    fund = Security.create!(ticker: "BND", name: "", exchange_operating_mic: "XNAS")
    Holding.create!(account: @account, security: custom, date: Date.current, qty: 1, price: 40, amount: 40, currency: "USD")
    Holding.create!(account: @account, security: fund, date: Date.current, qty: 1, price: 60, amount: 60, currency: "USD")

    allocation = Portfolio::NetWorthAllocation.new(family: @family)
    bonds = allocation.segments.find { |slice| slice.id == "fixed_income" }

    assert_equal "fixed_income", bonds.id
    assert_equal 60.to_d, bonds.amount.amount
    assert_equal 40.to_d, allocation.unclassified_money.amount
    assert allocation.unclassified_money.positive?
  end

  test "private equity is its own slice for the venture fund, the sub-class and the asset class" do
    venture = Security.create!(ticker: "ARKVX", name: "", exchange_operating_mic: "XNAS")
    listed = Security.create!(ticker: "SPCX", name: "", exchange_operating_mic: "XNAS")
    alt = Security.create!(ticker: "ALTFUN", name: "", exchange_operating_mic: "XNAS", asset_class: "alternative_investment")
    subclass = Security.create!(ticker: "PESUB", name: "", exchange_operating_mic: "XNAS", asset_sub_class: "private_equity")
    Holding.create!(account: @account, security: venture, date: Date.current, qty: 1, price: 10, amount: 10, currency: "USD")
    Holding.create!(account: @account, security: listed, date: Date.current, qty: 1, price: 20, amount: 20, currency: "USD")
    Holding.create!(account: @account, security: alt, date: Date.current, qty: 1, price: 30, amount: 30, currency: "USD")
    Holding.create!(account: @account, security: subclass, date: Date.current, qty: 1, price: 40, amount: 40, currency: "USD")
    @account.update!(balance: 100)

    allocation = Portfolio::NetWorthAllocation.new(family: @family)

    assert_equal 80.to_d, allocation.segments.find { |slice| slice.id == "private_equity" }.amount.amount
    assert_equal 20.to_d, allocation.segments.find { |slice| slice.id == "equity" }.amount.amount
  end

  test "an account override files the whole account as private equity and leaves the security alone" do
    security = Security.create!(ticker: "SPCX", name: "", exchange_operating_mic: "XNAS")
    Holding.create!(account: @account, security: security, date: Date.current, qty: 1, price: 70, amount: 70, currency: "USD")
    @account.update!(balance: 100, allocation_category: "private_equity")

    allocation = Portfolio::NetWorthAllocation.new(family: @family)
    drilled = Portfolio::NetWorthAllocation.new(family: @family, bucket: "private_equity")

    assert_equal [ "private_equity" ], allocation.segments.map(&:id)
    assert_equal 100.to_d, allocation.segments.first.amount.amount
    assert_equal [ "security" ], drilled.segments.filter_map { |slice| slice.classify&.first }
    assert_nil security.reload.asset_class
    assert_not security.classification_locked
  end

  test "a security override beats the account override" do
    security = Security.create!(ticker: "SPCX", name: "", exchange_operating_mic: "XNAS")
    Holding.create!(account: @account, security: security, date: Date.current, qty: 1, price: 100, amount: 100, currency: "USD")
    @account.update!(allocation_category: "private_equity")
    FamilySecurityClassification.create!(family: @family, security: security, category: "equity")

    allocation = Portfolio::NetWorthAllocation.new(family: @family)

    assert_equal [ "equity" ], allocation.segments.map(&:id)
  end
end
