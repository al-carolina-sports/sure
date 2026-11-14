class PortfolioAccountClassificationsController < ApplicationController
  before_action :require_preview_features!
  before_action :set_account

  def edit
  end

  def update
    if @account.update(allocation_category: category_param)
      redirect_to portfolio_path(scope: "net_worth"), notice: t(".saved")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def category_param
      params.require(:account).permit(:allocation_category)[:allocation_category].presence
    end
end
