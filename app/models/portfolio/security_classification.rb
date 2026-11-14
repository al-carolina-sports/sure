# Defaults for securities a provider never classified. A family's own
# override always wins; these names only fill a blank.
module Portfolio::SecurityClassification
  # sorted
  BOND_TICKERS = %w[AGG BND SCHP SHV TLT VBTLX VGSH VTIP].freeze
  # sorted
  EQUITY_TICKERS = %w[QQQ SCHB SCHE SCHF SPCX VBR VIGAX VTI VTIAX VTSAX VTWO VXUS].freeze
  # sorted
  REAL_ESTATE_TICKERS = %w[VNQ].freeze
  # Bitcoin funds. They are equities legally and crypto economically; the
  # household can still move them.
  # sorted
  CRYPTO_FUND_TICKERS = %w[ARKB BITB FBTC GBTC IBIT].freeze
  # Venture interval funds. Public stock in the same company stays equity.
  # sorted
  PRIVATE_EQUITY_TICKERS = %w[ARKVX].freeze
  # sorted
  CASH_TICKERS = %w[FDRXX FZFXX SPAXX SPRXX SWVXX VMFXX].freeze

  SUBCLASS_CATEGORY = {
    "bond" => "fixed_income",
    "cash" => "cash",
    "commodity" => "other",
    "cryptocurrency" => "crypto",
    "etf" => "equity",
    "mutual_fund" => "equity",
    "precious_metal" => "other",
    "private_equity" => "private_equity",
    "real_estate" => "real_estate",
    "stock" => "equity"
  }.freeze

  def self.infer(security)
    ticker = security.ticker.to_s.upcase
    return "cash" if CASH_TICKERS.include?(ticker)
    return "crypto" if CRYPTO_FUND_TICKERS.include?(ticker)
    return "fixed_income" if BOND_TICKERS.include?(ticker)
    return "real_estate" if REAL_ESTATE_TICKERS.include?(ticker)
    return "private_equity" if PRIVATE_EQUITY_TICKERS.include?(ticker)
    return "equity" if EQUITY_TICKERS.include?(ticker)

    inferred = SUBCLASS_CATEGORY[security.asset_sub_class]
    return inferred if security.asset_class.blank? && inferred

    name = security.name.to_s
    return "cash" if name.match?(/money market|cash equivalent|treasury bill/i)
    return "fixed_income" if security.asset_class.blank? && name.match?(/\bbond\b/i)
    return "equity" if security.asset_class.blank? && name.match?(/\bETF\b/i) && !name.match?(/\bbond\b/i)

    nil
  end

  def self.inferred_sub_class(security)
    ticker = security.ticker.to_s.upcase
    return "cryptocurrency" if CRYPTO_FUND_TICKERS.include?(ticker)
    return "real_estate" if REAL_ESTATE_TICKERS.include?(ticker)
    return "bond" if BOND_TICKERS.include?(ticker)
    return "cash" if CASH_TICKERS.include?(ticker)
    return "private_equity" if PRIVATE_EQUITY_TICKERS.include?(ticker)
    return "stock" if ticker == "SPCX"
    return "etf" if EQUITY_TICKERS.include?(ticker)

    nil
  end
end
