class ProposalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_proposal, only: %i[show destroy annul correction_exam testportal]

  def index
    authorize Proposal
    @proposals = policy_scope(Proposal).newest_first
    @drafts = current_user.proposals.drafts.order(updated_at: :desc)
  end

  # Przy wyniku „Negatywny z prawem do poprawki” – przedmioty do poprawy z NETPAR (bez NETPAR strona bez tej listy).
  def show
    authorize @proposal
    @failed_subjects = @proposal.failed_subject_names(netpar:) if @proposal.can_correction_exam?
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
  end

  # Nowe zgłoszenie – kreator od zakładki 1; dane osobowe zapisuje dopiero „Dalej” na zakładce 2.
  def create
    authorize Proposal
    proposal = current_user.proposals.build(esod_category: Proposal::ESOD_CATEGORY_EGZAMIN)
    proposal.save!(validate: false)
    redirect_to proposal_wizard_path(proposal, Proposal::FORM_STEPS.first)
  end

  # Usunięcie niedokończonego (niewysłanego) zgłoszenia.
  def destroy
    authorize @proposal
    @proposal.destroy!
    back = current_user.proposals.find_by(multi_app_identifier: params[:return_to].to_s) if params[:return_to].present?
    redirect_to back ? proposal_wizard_path(back, Proposal::FORM_STEPS.first) : proposals_path, notice: t("activerecord.successfull.messages.destroyed", data: @proposal.rec_info), status: :see_other
  end

  # Unieważnienie: NETPAR i nasza baza razem. Blokada wiersza na czas operacji; błąd NETPAR wycofuje zmianę
  # u nas, a ponowienie jest bezpieczne (PATCH z tym samym statusem).
  def annul
    authorize @proposal
    @proposal.with_lock do
      raise Pundit::NotAuthorizedError unless @proposal.can_annul?

      @proposal.proposal_status_id = Proposal::PROPOSAL_STATUS_ANNULLED
      unless netpar.update_proposal(@proposal.multi_app_identifier, @proposal.netpar_attributes)
        raise Netpar::Unavailable, "NETPAR: brak zgłoszenia #{@proposal.multi_app_identifier}"
      end
      @proposal.save!(validate: false)
      @proposal.log_event("annulled")
    end
    redirect_to proposal_path(@proposal), notice: t("activerecord.successfull.messages.annulled", data: @proposal.rec_info), status: :see_other
  rescue Netpar::Unavailable, Netpar::Rejected => e
    Rails.logger.error("[NETPAR] #{e.message}")
    redirect_to proposal_path(@proposal), alert: t("netpar.unavailable"), status: :see_other
  end

  # Zgłoszenie na egzamin poprawkowy: adres i rodzaj świadectwa z poprzedniego zgłoszenia.
  def correction_exam
    authorize @proposal
    copied = @proposal.slice(*%w[lives_in_poland address_combine_id city_name street_name c_address_house
                                c_address_number c_address_postal_code category division_id division_fullname
                                division_short_name division_min_years_old division_face_image_required])
    proposal = current_user.proposals.build(esod_category: Proposal::ESOD_CATEGORY_POPRAWKOWY, **copied.symbolize_keys)
    proposal.save!(validate: false)
    redirect_to proposal_wizard_path(proposal, Proposal::FORM_STEPS.first), status: :see_other
  end

  # Egzamin online: testy z TestPortal (kody dostępu z NETPAR).
  def testportal
    authorize @proposal
    @grades = netpar.grades(@proposal.multi_app_identifier)
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
    redirect_to proposal_path(@proposal), alert: t("netpar.unavailable")
  end

  private
    def set_proposal
      @proposal = Proposal.find_by!(multi_app_identifier: params[:multi_app_identifier])
    end
end
