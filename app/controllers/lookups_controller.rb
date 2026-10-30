# Podpowiedzi adresów TERYT dla kreatora (krok 3) – tylko dla zalogowanych.
class LookupsController < ApplicationController
  before_action :authenticate_user!
  rate_limit to: 120, within: 1.minute

  def addresses
    query = params[:q].to_s.strip
    return render(json: { total: 0, items: [] }) if query.length < 3

    render json: Teryt::Client.new.addresses(query.first(100), page: params.fetch(:page, 1).to_i.clamp(1, 100))
  rescue Teryt::Unavailable => e
    Rails.logger.error("[TERYT] #{e.message}")
    render json: { error: t("lookups.unavailable") }, status: :service_unavailable
  end
end
