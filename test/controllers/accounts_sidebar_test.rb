require "test_helper"

class AccountsSidebarTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "sidebar lists an investment account's holdings with value, weight and quantity" do
    get sidebar_account_path(accounts(:investment))

    assert_response :success
    assert_select "turbo-frame#sidebar_holdings"
    assert_match "Apple", response.body
    assert_match "10", response.body
    assert_match I18n.t("accounts.sidebar_holdings.open_account"), response.body
  end

  test "sidebar summarizes an account that has no holdings" do
    get sidebar_account_path(accounts(:depository))

    assert_response :success
    assert_match I18n.t("accounts.sidebar_holdings.balance"), response.body
    assert_match "Checking Account", response.body
    assert_no_match(/Apple/, response.body)
  end

  test "sidebar does not open another family's account" do
    other = users(:empty)
    account = other.family.accounts.create!(
      name: "Other checking", balance: 20, currency: "USD", accountable: Depository.new, owner: other
    )

    get sidebar_account_path(account)

    assert_response :not_found
  end

  test "the account list points at the sidebar frame" do
    get root_path

    assert_response :success
    assert_select "a[data-turbo-frame=sidebar_holdings][href=?]", sidebar_account_path(accounts(:depository))
  end
end
