require "test_helper"

class PortfolioClassificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    @security = securities(:aapl)
  end

  test "classifying a holding saves a family override and leaves the shared security alone" do
    patch portfolio_classification_path(@security), params: {
      family_security_classification: { category: "crypto", sector: "", region: "Global" }
    }

    assert_redirected_to portfolio_path(scope: "net_worth", bucket: "unclassified")
    classification = FamilySecurityClassification.find_by!(family: families(:dylan_family), security: @security)
    assert_equal "crypto", classification.category
    assert_equal "cryptocurrency", classification.asset_sub_class
    assert_nil classification.sector
    assert_equal "Global", classification.region

    @security.reload
    assert_nil @security.asset_class
    assert_not @security.classification_locked
  end

  test "the classify dialog renders for a held security" do
    get edit_portfolio_classification_path(@security)

    assert_response :success
    assert_select "select[name=?]", "family_security_classification[category]"
    assert_select "option[value=crypto]"
    assert_select "option[value=private_equity]"
  end

  test "a security the family does not hold is not editable" do
    other = Security.create!(ticker: "NOHOLD", name: "No Holding", exchange_operating_mic: "XNAS")

    get edit_portfolio_classification_path(other)

    assert_response :not_found
  end

  test "preview features are required" do
    @user.update!(preferences: @user.preferences.merge("preview_features_enabled" => false))

    get edit_portfolio_classification_path(@security)

    assert_redirected_to root_path
  end
end
