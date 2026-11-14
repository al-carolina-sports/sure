# Presents one level of InvestmentStatement allocation for the portfolio
# donut. It does not recompute weights: every slice is an AllocationSegment
# from allocation_by or allocation_children.
#
# Cash is not a leftover. The statement files it under liquidity (asset
# class), cash (sub-class), the account or its currency, and unclassified
# where a grouping has no cash bucket (sector and region).
class Portfolio::AllocationView
  # Switcher options. A subset of InvestmentStatement::ALLOCATION_GROUPINGS:
  # kind stays on the statement and is not a control on this page.
  GROUPINGS = %w[asset_class asset_sub_class sector region account currency].freeze

  # Known buckets keep a stable fill. Anything else cycles the same tokens.
  # They are slice fills, so the same values stay visible on the light and
  # dark container colours.
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

  KNOWN_COLORS = {
    "alternative_investment" => "var(--color-violet-600)",
    "cash" => "var(--color-cyan-600)",
    "commodity" => "var(--color-yellow-600)",
    "equity" => "var(--color-blue-600)",
    "fixed_income" => "var(--color-green-600)",
    "liquidity" => "var(--color-cyan-600)",
    "real_estate" => "var(--color-orange-600)",
    "unclassified" => "var(--color-gray-400)"
  }.freeze

  Slice = Data.define(:id, :name, :amount, :weight, :color, :link_params)
  Crumb = Data.define(:label, :params)

  attr_reader :grouping, :bucket, :child

  def initialize(statement:, grouping: nil, bucket: nil, child: nil)
    @statement = statement
    requested = grouping.to_s.presence || "asset_class"
    @grouping = GROUPINGS.include?(requested) ? requested : "asset_class"
    # A rejected grouping drops the drill that came with it. A grouping
    # that does not nest, or a child without its parent, stays at the top,
    # so a stale query string cannot blank the chart.
    if @grouping == requested
      @bucket = bucket.to_s.presence
      @child = child.to_s.presence
      unless %w[asset_class asset_sub_class].include?(@grouping)
        @bucket = nil
        @child = nil
      end
      @child = nil unless @grouping == "asset_class" && @bucket.present?
    end
  end

  def segments
    @segments ||= raw_segments.map { |segment| present(segment) }
  end

  def empty?
    segments.empty?
  end

  def drilled?
    bucket.present?
  end

  def total_money
    currency = segments.first&.amount&.currency || @statement.family.currency
    segments.map(&:amount).reduce(Money.new(0, currency), :+)
  end

  def crumbs
    return [] unless drilled?

    root = Crumb.new(label: grouping_label, params: { by: grouping })
    if child.present?
      [
        root,
        Crumb.new(label: bucket_label(bucket), params: { by: grouping, bucket: bucket }),
        Crumb.new(label: bucket_label(child), params: nil)
      ]
    else
      [ root, Crumb.new(label: bucket_label(bucket), params: nil) ]
    end
  end

  def grouping_label
    I18n.t("portfolios.allocation.groupings.#{grouping}")
  end

  private
    def level
      if grouping == "asset_class" && bucket.present? && child.present?
        :holdings
      elsif bucket.present? && grouping == "asset_class"
        :sub_classes
      elsif bucket.present?
        :holdings
      else
        :top
      end
    end

    def raw_segments
      case level
      when :sub_classes
        @statement.allocation_children("asset_class", bucket)
      when :holdings
        parent = (grouping == "asset_class") ? bucket : nil
        id = (grouping == "asset_class") ? child : bucket
        @statement.allocation_children("asset_sub_class", id, parent: parent)
      else
        @statement.allocation_by(grouping)
      end
    end

    def present(segment)
      Slice.new(
        id: segment.id,
        name: label_for(segment),
        amount: segment.amount,
        weight: segment.weight,
        color: color_for(segment.id),
        link_params: link_params_for(segment)
      )
    end

    # Asset class opens onto sub-classes; a sub-class opens onto holdings.
    # Sector, region, account and currency do not nest.
    def link_params_for(segment)
      case level
      when :top
        { by: grouping, bucket: segment.id } if %w[asset_class asset_sub_class].include?(grouping)
      when :sub_classes
        { by: grouping, bucket: bucket, child: segment.id }
      end
    end

    def label_for(segment)
      if segment.id == InvestmentStatement::UNCLASSIFIED || segment.id == InvestmentStatement::CASH_SUB_CLASS
        return bucket_label(segment.id)
      end
      return segment.name if level == :holdings || %w[account currency].include?(grouping)

      bucket_label(segment.id, fallback: segment.name.to_s.humanize)
    end

    def bucket_label(id, fallback: nil)
      if id == InvestmentStatement::UNCLASSIFIED
        return I18n.t("portfolios.allocation.buckets.unclassified")
      end
      if id == InvestmentStatement::CASH_SUB_CLASS
        return I18n.t("portfolios.allocation.buckets.cash")
      end

      fallback ||= id.to_s.humanize
      return fallback unless id.match?(/\A[a-z0-9_]+\z/)

      I18n.t("portfolios.allocation.buckets.#{id}", default: fallback)
    end

    def color_for(id)
      KNOWN_COLORS[id] || PALETTE[id.each_byte.sum % PALETTE.size]
    end
end
