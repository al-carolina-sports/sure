require "test_helper"

class Portfolio::NetWorthAllocationTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
  end

  test "counts each asset once, with brokerage cash separate from its holding" do
    slices = gross.segments.index_by(&:id)

    # Checking 5,000 + linked checking 5,000 + brokerage residual (10,000 - 2,150).
    assert_equal 17_850, slices["cash"].amount.amount
    # The Apple holding has no asset class.
    assert_equal 2_150, slices["unclassified"].amount.amount
    # The crypto account has a balance and no holdings, so the balance is the slice.
    assert_equal 10_000, slices["crypto"].amount.amount
    assert_equal 550_000, slices["real_estate"].amount.amount
    # Vehicle 18,000 + other asset 550.
    assert_equal 18_550, slices["other"].amount.amount
    assert_not slices.key?("equity")
    assert_in_delta 100, gross.segments.sum(&:weight), 0.05
  end

  test "a crypto holding replaces the account balance instead of adding to it" do
    security = Security.create!(ticker: "BTC#{SecureRandom.hex(2)}", name: "Coin", exchange_operating_mic: "XNAS", offline: true)
    Holding.create!(account: accounts(:crypto), security: security, date: Date.current, qty: 1, price: 4_000, amount: 4_000, currency: "USD")

    crypto = gross.segments.find { |slice| slice.id == "crypto" }
    coins = Portfolio::NetWorthAllocation.new(family: @family, user: @user, bucket: "crypto").segments.index_by(&:name)

    # 4,000 of coin plus 6,000 of account value the holdings do not explain. Not 14,000.
    assert_equal 10_000, crypto.amount.amount
    assert_equal 4_000, coins["Coin"].amount.amount
    assert_equal 6_000, coins[accounts(:crypto).name].amount.amount
    assert_nil coins["Coin"].link_params
  end

  test "equity drills from asset class to sub-class to the holding" do
    security = Security.create!(
      ticker: "BND#{SecureRandom.hex(2)}", name: "Total Bond", exchange_operating_mic: "XNAS",
      offline: true, asset_class: "fixed_income", asset_sub_class: "bond"
    )
    Holding.create!(account: accounts(:investment), security: security, date: Date.current, qty: 1, price: 800, amount: 800, currency: "USD")

    bonds = gross.segments.find { |slice| slice.id == "fixed_income" }
    children = Portfolio::NetWorthAllocation.new(family: @family, user: @user, bucket: "fixed_income").segments
    holdings = Portfolio::NetWorthAllocation.new(family: @family, user: @user, bucket: "fixed_income", child: "bond").segments

    assert_equal 800, bonds.amount.amount
    assert_equal [ "bond" ], children.map(&:id)
    assert_equal [ "Total Bond" ], holdings.map(&:name)
    assert_nil holdings.first.link_params
  end

  test "gross assets leave the mortgage out, and net subtracts it from real estate" do
    loans(:one).update!(subtype: "mortgage")

    assert_equal 550_000, gross.segments.find { |slice| slice.id == "real_estate" }.amount.amount
    assert_not gross.segments.any? { |slice| slice.name.match?(/mortgage/i) }

    net = Portfolio::NetWorthAllocation.new(family: @family, user: @user, basis: "net")
    slices = net.segments.index_by(&:id)

    assert_equal 50_000, slices["real_estate"].amount.amount
    # Credit card 1,000 comes out of cash. The other liability comes out of other.
    assert_equal 16_850, slices["cash"].amount.amount
    assert_equal 18_350, slices["other"].amount.amount
    assert_equal 0, net.uncovered_debt.amount
  end

  test "debt larger than its category is reported and not drawn" do
    accounts(:property).update!(balance: 1_000)
    loans(:one).update!(subtype: "mortgage")

    net = Portfolio::NetWorthAllocation.new(family: @family, user: @user, basis: "net")

    assert_nil net.segments.find { |slice| slice.id == "real_estate" }
    assert_equal 499_000, net.uncovered_debt.amount
  end

  test "an account excluded from reports is left out" do
    accounts(:property).update!(exclude_from_reports: true)

    assert_nil gross.segments.find { |slice| slice.id == "real_estate" }
  end

  private
    def gross
      Portfolio::NetWorthAllocation.new(family: @family, user: @user)
    end
end
