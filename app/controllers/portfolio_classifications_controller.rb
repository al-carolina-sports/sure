class PortfolioClassificationsController < ApplicationController
  before_action :require_preview_features!
  before_action :set_security

  def edit
    @classification = classification_for(@security)
    @classification.category ||= Portfolio::SecurityClassification.infer(@security)
  end

  def update
    @classification = classification_for(@security)
    if @classification.update(classification_params)
      redirect_to portfolio_path(scope: "net_worth", bucket: "unclassified"), notice: t(".saved")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    # Only a security this family holds. The id is otherwise a guess at a
    # shared row the household has no stake in.
    def set_security
      @security = Security.where(id: Current.family.holdings.select(:security_id)).find(params[:security_id])
    end

    def classification_for(security)
      Current.family.security_classifications.find_or_initialize_by(security: security)
    end

    def classification_params
      params.require(:family_security_classification).permit(:category, :asset_sub_class, :sector, :region)
    end
end
