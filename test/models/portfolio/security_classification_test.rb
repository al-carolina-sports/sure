require "test_helper"

class Portfolio::SecurityClassificationTest < ActiveSupport::TestCase
  test "known bond and equity tickers get a default category" do
    assert_equal "fixed_income", Portfolio::SecurityClassification.infer(security("BND"))
    assert_equal "fixed_income", Portfolio::SecurityClassification.infer(security("SHV"))
    assert_equal "equity", Portfolio::SecurityClassification.infer(security("VTI"))
    assert_equal "equity", Portfolio::SecurityClassification.infer(security("SPCX"))
    assert_equal "stock", Portfolio::SecurityClassification.inferred_sub_class(security("SPCX"))
    assert_equal "equity", Portfolio::SecurityClassification.infer(security("vtsax"))
    assert_equal "real_estate", Portfolio::SecurityClassification.infer(security("VNQ"))
  end

  test "a bitcoin fund defaults to crypto and a venture fund defaults to private equity" do
    assert_equal "crypto", Portfolio::SecurityClassification.infer(security("IBIT"))
    assert_equal "private_equity", Portfolio::SecurityClassification.infer(security("ARKVX"))
    assert_nil Portfolio::SecurityClassification.infer(security("AAPL"))
  end

  test "a money market ticker or name defaults to cash" do
    assert_equal "cash", Portfolio::SecurityClassification.infer(security("SPAXX"))
    assert_equal "cash", Portfolio::SecurityClassification.infer(security("CUSTOM", "Treasury Bill Fund"))
  end

  private
    def security(ticker, name = nil)
      Security.new(ticker:, name:, exchange_operating_mic: "XNAS")
    end
end
