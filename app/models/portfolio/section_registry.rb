# The list of sections the portfolio hub renders, in the order the user last
# left them.
#
# Same shape as ReportsController#build_reports_sections -- a hash per section
# with `key`, an i18n `title` key, a `partial`, its `locals`, and the `visible`
# / `collapsible` flags -- so the Reports section chrome (drag to reorder,
# chevron to collapse) renders it unchanged. It lives here rather than in the
# controller because the ordering rule and the section list are domain
# decisions the controller only renders, and because a PORO can be unit-tested
# without a request.
#
# Every local a partial needs is passed in. Nothing here (and nothing in the
# partials) reads Date.current or Current.family: the controller captures one
# `as_of` and one statement per request and hands them down, so the sections
# that take a date all read the same one.
class Portfolio::SectionRegistry
  # The built-in section keys, in declaration order. The preferences
  # endpoint accepts only these, so a saved order or collapsed set cannot
  # carry arbitrary strings into the user's preferences.
  KEYS = %w[accounts allocation].freeze

  attr_reader :statement, :period, :as_of, :user, :extra_sections

  # `extra_sections` are appended after the built-ins, in the order given. It
  # is the seam that keeps this list open: a section can be added (or a test
  # can add one) without editing the built-in list.
  #
  # `allocation_params` are the page's by / bucket / child query, the drill
  # state of the allocation section. Anything else is ignored.
  def initialize(statement:, period:, as_of:, user:, extra_sections: [], allocation_params: {})
    @statement = statement
    @period = period
    @as_of = as_of
    @user = user
    @extra_sections = extra_sections || []
    @allocation_params = allocation_params || {}
  end

  # The page's empty state is for a family with nothing to allocate: no
  # investment account and no other counted asset. A house or a checking
  # account is enough to show the allocation section on its own.
  def empty?
    accounts_for_cards.empty? && gross_net_worth.empty?
  end

  def sections
    all = built_in_sections + extra_sections

    # Order by the user's saved order; anything the saved order doesn't
    # mention (a section added since they last dragged one) is appended in
    # declaration order, so a new section always appears rather than
    # disappearing until the next drag. Same rule as Reports.
    # `uniq` before the lookup: a saved order that repeats a key would
    # otherwise render that section once per occurrence. The endpoint
    # deduplicates what it writes, but an order written by anything else
    # still has to render once.
    ordered = Array(user&.section_order("portfolio")).uniq.filter_map do |key|
      all.find { |section| section[:key] == key }
    end

    # Matched by key, never by comparing whole section hashes: a section's
    # locals carry the statement and whatever it has memoised, and the order
    # must not depend on how those compare.
    placed = ordered.map { |section| section[:key] }
    ordered + all.reject { |section| placed.include?(section[:key]) }
  end

  private
    def built_in_sections
      [
        {
          key: "accounts",
          title: "portfolios.sections.accounts",
          partial: "portfolios/accounts",
          locals: shared_locals.merge(accounts: accounts_for_cards),
          visible: accounts_for_cards.any?,
          collapsible: true
        },
        {
          key: "allocation",
          title: "portfolios.sections.allocation",
          partial: "portfolios/allocation",
          locals: shared_locals.merge(allocation: allocation_view),
          visible: accounts_for_cards.any? || !gross_net_worth.empty?,
          collapsible: true
        }
      ]
    end

    # Whole net worth is the section's default. `scope=investments` keeps the
    # investment groupings (asset class, sector, and the rest).
    def allocation_view
      @allocation_view ||= if allocation_param(:scope) == "investments"
        Portfolio::AllocationView.new(
          statement: statement,
          grouping: allocation_param(:by),
          bucket: allocation_param(:bucket),
          child: allocation_param(:child)
        )
      elsif allocation_param(:bucket).blank? && allocation_param(:basis).blank?
        gross_net_worth
      else
        net_worth_allocation
      end
    end

    def gross_net_worth
      @gross_net_worth ||= Portfolio::NetWorthAllocation.new(family: statement.family, user: user)
    end

    def net_worth_allocation
      @net_worth_allocation ||= Portfolio::NetWorthAllocation.new(
        family: statement.family,
        user: user,
        basis: allocation_param(:basis),
        bucket: allocation_param(:scope) == "investments" ? nil : allocation_param(:bucket),
        child: allocation_param(:scope) == "investments" ? nil : allocation_param(:child)
      )
    end

    def allocation_param(key)
      @allocation_params[key] || @allocation_params[key.to_s]
    end

    # The accounts the cards show, in name order (id breaks ties, so
    # same-named cards keep their places), with every record the logo reads
    # (the attachment, the accountable's colour, the provider links and the
    # provider each falls back to) loaded here rather than once per card.
    def accounts_for_cards
      @accounts_for_cards ||= statement.investment_accounts.with_attached_logo
        .includes(:accountable, :plaid_account, :simplefin_account, account_providers: :provider)
        .alphabetically.order(:id).to_a
    end

    def shared_locals
      { statement: statement, period: period, as_of: as_of }
    end
end
