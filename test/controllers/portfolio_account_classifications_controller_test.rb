require "test_helper"

class PortfolioAccountClassificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    @account = accounts(:other_asset)
  end

  test "classifying an account saves the override for that account only" do
    patch portfolio_account_classification_path(@account), params: {
      account: { allocation_category: "private_equity" }
    }

    assert_redirected_to portfolio_path(scope: "net_worth")
    assert_equal "private_equity", @account.reload.allocation_category
  end

  test "a blank choice clears the override" do
    @account.update!(allocation_category: "private_equity")

    patch portfolio_account_classification_path(@account), params: {
      account: { allocation_category: "" }
    }

    assert_nil @account.reload.allocation_category
  end

  test "the dialog offers private equity" do
    get edit_portfolio_account_classification_path(@account)

    assert_response :success
    assert_select "select[name=?]", "account[allocation_category]"
    assert_select "option[value=private_equity]"
  end

  test "another family's account is not editable" do
    other = users(:empty)
    account = other.family.accounts.create!(
      name: "Other fund", balance: 20, currency: "USD", accountable: OtherAsset.new, owner: other
    )

    get edit_portfolio_account_classification_path(account)

    assert_response :not_found
  end

  test "preview features are required" do
    @user.update!(preferences: @user.preferences.merge("preview_features_enabled" => false))

    get edit_portfolio_account_classification_path(@account)

    assert_redirected_to root_path
  end
end
