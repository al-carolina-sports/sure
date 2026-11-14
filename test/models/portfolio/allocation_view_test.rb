require "test_helper"

class Portfolio::AllocationViewTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @statement = InvestmentStatement.new(@family, user: @user)
  end

  test "defaults to asset class and shows cash and unclassified holdings as slices" do
    slices = view.segments.index_by(&:id)

    assert_equal "asset_class", view.grouping
    assert_equal 17_850, slices["liquidity"].amount.amount
    assert_equal 2_150, slices[InvestmentStatement::UNCLASSIFIED].amount.amount
    assert_equal I18n.t("portfolios.allocation.buckets.liquidity"), slices["liquidity"].name
    assert_equal I18n.t("portfolios.allocation.buckets.unclassified"), slices[InvestmentStatement::UNCLASSIFIED].name
    assert_equal({ by: "asset_class", bucket: "liquidity" }, slices["liquidity"].link_params)
    assert_in_delta 100, view.segments.sum(&:weight), 0.02
  end

  test "reads the statement's segments rather than recomputing them" do
    expected = @statement.allocation_by("sector")
    slices = view(grouping: "sector").segments

    assert_equal expected.map(&:id), slices.map(&:id)
    assert_equal expected.map { |segment| segment.amount.amount }, slices.map { |slice| slice.amount.amount }
    assert slices.all? { |slice| slice.link_params.nil? }, "sector does not nest"
  end

  test "cash is its own slice when grouped by sub-class" do
    cash = view(grouping: "asset_sub_class").segments.find { |slice| slice.id == "cash" }

    assert_equal I18n.t("portfolios.allocation.buckets.cash"), cash.name
    assert_equal 17_850, cash.amount.amount
    assert_equal "var(--color-cyan-600)", cash.color
  end

  test "an unknown grouping falls back to asset class and does not drill" do
    fallback = view(grouping: "kind", bucket: "cash")

    assert_equal "asset_class", fallback.grouping
    assert_not fallback.drilled?
    assert_equal view.segments.map(&:id), fallback.segments.map(&:id)
  end

  test "drilling an asset class lists its children and then their holdings" do
    security = Security.create!(
      ticker: "T#{SecureRandom.hex(4)}", name: "Wide Market", exchange_operating_mic: "XNAS",
      offline: true, asset_class: "equity", asset_sub_class: "etf"
    )
    Holding.create!(account: accounts(:investment), security: security, date: Date.current, qty: 1, price: 500, amount: 500, currency: "USD")

    children = view(bucket: "equity")

    assert children.drilled?
    assert_equal [ "etf" ], children.segments.map(&:id)
    assert_equal({ by: "asset_class", bucket: "equity", child: "etf" }, children.segments.first.link_params)
    assert_equal [
      I18n.t("portfolios.allocation.groupings.asset_class"),
      I18n.t("portfolios.allocation.buckets.equity")
    ], children.crumbs.map(&:label)

    holdings = view(bucket: "equity", child: "etf")

    assert_equal [ "Wide Market" ], holdings.segments.map(&:name)
    assert_nil holdings.segments.first.link_params
    assert_nil holdings.crumbs.last.params
  end

  test "liquidity drills into the cash it is made of" do
    cash = view(bucket: "liquidity").segments.sole

    assert_equal "cash", cash.id
    assert_equal I18n.t("portfolios.allocation.buckets.cash"), cash.name
    assert_equal 17_850, cash.amount.amount
  end

  test "a portfolio with no holdings and no cash is empty" do
    user = users(:empty)
    user.family.accounts.create!(
      name: "Empty brokerage", balance: 0, currency: "USD", accountable: Investment.new, owner: user
    )
    statement = InvestmentStatement.new(user.family, user: user)

    allocation = Portfolio::AllocationView.new(statement: statement)

    assert allocation.empty?
    assert_equal Money.new(0, user.family.currency), allocation.total_money
  end

  private
    def view(**params)
      Portfolio::AllocationView.new(statement: @statement, **params)
    end
end
