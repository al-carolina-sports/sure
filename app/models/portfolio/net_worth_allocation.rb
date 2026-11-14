# Allocation of everything the family counts as an asset, in the family's
# currency. Investment and crypto accounts contribute their holdings, plus
# only the residual of the account balance above those holdings, so a
# balance is never added on top of the positions it already contains. A
# negative residual (margin, or a balance that lags the holdings) is left
# out rather than subtracted from another category.
#
# Gross is the default: liabilities are not slices. Net subtracts debts
# from the asset they sit against — mortgages and home-equity loans from
# real estate, credit cards from cash, every other liability from other.
# A debt larger than that category is not drawn; #uncovered_debt reports
# it. Drill-down lists the gross pieces of a category. A mortgage is not
# one of the properties.
class Portfolio::NetWorthAllocation
  CATEGORIES = %w[equity fixed_income cash crypto real_estate other unclassified].freeze
  BASES = %w[gross net].freeze

  ASSET_CLASS_CATEGORY = {
    "equity" => "equity",
    "fixed_income" => "fixed_income",
    "liquidity" => "cash",
    "real_estate" => "real_estate",
    "commodity" => "other",
    "alternative_investment" => "other"
  }.freeze

  COLORS = {
    "equity" => "var(--color-blue-600)",
    "fixed_income" => "var(--color-green-600)",
    "cash" => "var(--color-cyan-600)",
    "crypto" => "var(--color-orange-600)",
    "real_estate" => "var(--color-violet-600)",
    "other" => "var(--color-yellow-600)",
    "unclassified" => "var(--color-gray-400)"
  }.freeze

  PALETTE = %w[
    var(--color-blue-600)
    var(--color-green-600)
    var(--color-orange-600)
    var(--color-violet-600)
    var(--color-cyan-600)
    var(--color-pink-600)
    var(--color-indigo-600)
    var(--color-yellow-600)
  ].freeze

  Slice = Data.define(:id, :name, :amount, :weight, :color, :link_params)
  Crumb = Data.define(:label, :params)
  Line = Data.define(:category, :amount, :group_id, :group_name, :leaf_id, :leaf_name)

  attr_reader :basis, :bucket, :child

  def initialize(family:, user: nil, basis: nil, bucket: nil, child: nil)
    @family = family
    @user = user
    @basis = BASES.include?(basis.to_s) ? basis.to_s : "gross"
    @bucket = CATEGORIES.include?(bucket.to_s) ? bucket.to_s : nil
    @child = @bucket.present? ? child.to_s.presence : nil
    @child = nil unless %w[equity fixed_income].include?(@bucket)
  end

  def net_worth?
    true
  end

  def segments
    @segments ||= build_segments
  end

  def empty?
    segments.empty?
  end

  def drilled?
    bucket.present?
  end

  def total_money
    Money.new(segments.sum { |slice| slice.amount.amount }, currency)
  end

  # Debt that was larger than the asset category it was netted against.
  # Zero in the gross view.
  def uncovered_debt
    return Money.new(0, currency) unless basis == "net"

    amount = category_totals.sum { |_, value| value.negative? ? -value : 0 }
    Money.new(amount, currency)
  end

  def crumbs
    return [] unless drilled?

    root = Crumb.new(label: I18n.t("portfolios.allocation.scopes.net_worth"), params: scope_params)
    if child.present?
      [
        root,
        Crumb.new(label: category_label(bucket), params: scope_params.merge(bucket: bucket)),
        Crumb.new(label: subgroup_label(child), params: nil)
      ]
    else
      [ root, Crumb.new(label: category_label(bucket), params: nil) ]
    end
  end

  private
    def build_segments
      grouped = if bucket.blank?
        category_slices
      else
        drill_slices
      end
      total = grouped.sum { |_, amount,| amount }
      return [] if total.zero?

      grouped
        .sort_by { |row| -row[1] }
        .map do |id, amount, name, link|
          Slice.new(
            id: id.to_s,
            name: name,
            amount: Money.new(amount, currency),
            weight: (amount / total * 100).round(2),
            color: COLORS[id.to_s] || PALETTE[id.to_s.each_byte.sum % PALETTE.size],
            link_params: link
          )
        end
    end

    def category_slices
      category_totals.filter_map do |category, amount|
        next unless amount.positive?

        [ category, amount, category_label(category), scope_params.merge(bucket: category) ]
      end
    end

    # Constituents of one category, before the netting applied to the top
    # slice. Equity and fixed income open onto a sub-class, then holdings.
    # Crypto opens onto coins. The other categories open onto accounts.
    def drill_slices
      selected = lines.select { |line| line.category == bucket }
      selected = selected.select { |line| line.group_id == child } if child.present?
      key = child.present? ? :leaf_id : :group_id
      label = child.present? ? :leaf_name : :group_name

      selected.group_by(&key).map do |id, group|
        name = nested_level? ? subgroup_label(id) : group.first.public_send(label)
        link = nested_level? ? scope_params.merge(bucket: bucket, child: id) : nil
        [ id, group.sum(&:amount), name, link ]
      end
    end

    def nested_level?
      child.blank? && %w[equity fixed_income].include?(bucket)
    end

    def category_totals
      @category_totals ||= begin
        totals = Hash.new(0.to_d)
        lines.each { |line| totals[line.category] += line.amount }
        if basis == "net"
          reductions.each { |category, amount| totals[category] -= amount }
        end
        totals
      end
    end

    def reductions
      @reductions ||= Hash.new(0.to_d).tap do |totals|
        next unless basis == "net"

        accounts.each do |account|
          next unless account.liability?

          amount = convert(account.balance, account.currency)
          totals[liability_category(account)] += amount if amount.positive?
        end
      end
    end

    def liability_category(account)
      case account.accountable_type
      when "CreditCard" then "cash"
      when "Loan" then (%w[mortgage home_equity].include?(account.subtype) ? "real_estate" : "other")
      else "other"
      end
    end

    def lines
      @lines ||= accounts.flat_map { |account| lines_for(account) }
    end

    def lines_for(account)
      return [] unless account.asset?

      case account.accountable_type
      when "Investment" then security_lines(account, force_crypto: false)
      when "Crypto" then security_lines(account, force_crypto: true)
      when "Depository" then balance_line(account, "cash")
      when "Property" then balance_line(account, "real_estate")
      else balance_line(account, "other")
      end
    end

    # Holdings first. The account balance contributes only what the holdings
    # do not already explain.
    def security_lines(account, force_crypto:)
      rows = []
      held = 0.to_d
      holdings_by_account.fetch(account.id, []).each do |holding|
        amount = convert(holding.amount, holding.currency)
        next unless amount.positive?

        held += amount
        category = force_crypto ? "crypto" : category_for(holding.security)
        rows << security_line(holding, category, amount)
      end

      residual = convert(account.balance, account.currency) - held
      rows << residual_line(account, force_crypto ? "crypto" : "cash", residual) if residual.positive?
      rows
    end

    def security_line(holding, category, amount)
      security = holding.security
      name = security.name.presence || security.ticker
      if %w[equity fixed_income].include?(category)
        sub = security.asset_sub_class.presence || InvestmentStatement::UNCLASSIFIED
        Line.new(category:, amount:, group_id: sub, group_name: sub, leaf_id: security.id.to_s, leaf_name: name)
      else
        Line.new(category:, amount:, group_id: security.id.to_s, group_name: name, leaf_id: security.id.to_s, leaf_name: name)
      end
    end

    def residual_line(account, category, amount)
      id = "#{category}-#{account.id}"
      Line.new(category:, amount:, group_id: id, group_name: account.name, leaf_id: id, leaf_name: account.name)
    end

    def balance_line(account, category)
      amount = convert(account.balance, account.currency)
      return [] unless amount.positive?

      id = account.id.to_s
      [ Line.new(category:, amount:, group_id: id, group_name: account.name, leaf_id: id, leaf_name: account.name) ]
    end

    def category_for(security)
      return "cash" if security.cash?
      return "crypto" if security.crypto?

      ASSET_CLASS_CATEGORY[security.asset_class] || "unclassified"
    end

    def holdings_by_account
      @holdings_by_account ||= begin
        ids = accounts.select { |account| account.investment? || account.crypto? }.map(&:id)
        Holding::CurrentForInvestmentAccounts.new(ids).relation.includes(:security).to_a.group_by(&:account_id)
      end
    end

    def accounts
      @accounts ||= begin
        scope = @family.accounts.visible.included_in_reports.includes(:accountable)
        scope = scope.included_in_finances_for(@user) if @user
        scope.to_a
      end
    end

    def convert(amount, from_currency)
      numeric = amount.is_a?(Money) ? amount.amount.to_d : amount.to_d
      return numeric if from_currency.to_s == currency

      numeric * (exchange_rates[from_currency.to_s] || 1)
    end

    def exchange_rates
      @exchange_rates ||= begin
        foreign = accounts.map(&:currency).uniq.reject { |code| code.to_s == currency }
        ExchangeRate.rates_for(foreign, to: currency, date: Date.current)
      end
    end

    def currency
      @currency ||= @family.currency.presence || Money.default_currency.iso_code
    end

    def scope_params
      { scope: "net_worth", basis: basis }
    end

    def category_label(id)
      I18n.t("portfolios.allocation.categories.#{id}")
    end

    def subgroup_label(id)
      return I18n.t("portfolios.allocation.buckets.unclassified") if id == InvestmentStatement::UNCLASSIFIED
      return id.to_s.humanize unless id.match?(/\A[a-z0-9_]+\z/)

      I18n.t("portfolios.allocation.buckets.#{id}", default: id.to_s.humanize)
    end
end
