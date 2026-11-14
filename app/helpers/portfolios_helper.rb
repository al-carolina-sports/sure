module PortfoliosHelper
  # Keeps period and any other query, and replaces the allocation drill.
  # Allocation does not read the period, so these links leave it off. A
  # link that started with `?period=` would look like the period picker
  # the page deliberately does not offer.
  def portfolio_allocation_path(**extra)
    portfolio_path(extra.transform_keys(&:to_s).compact_blank)
  end

  def allocation_row_attributes(slice)
    actions = [ "mouseenter->allocation-donut#highlight", "mouseleave->allocation-donut#clear" ]
    data = { segment_id: slice.id }
    if slice.link_params
      actions << "click->clickable-row#open"
      data[:controller] = "clickable-row"
    end
    data[:action] = actions.join(" ")
    { data: data }
  end

  def portfolio_allocation_chart_segments(allocation)
    allocation.segments.map do |slice|
      {
        id: slice.id,
        amount: slice.amount.amount.to_f,
        color: slice.color,
        label: slice.name,
        href: (portfolio_allocation_path(**slice.link_params) if slice.link_params)
      }
    end
  end
end
