class ProposalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_proposal, only: %i[show destroy annul correction_exam testportal]

  def index
    authorize Proposal
    @proposals = policy_scope(Proposal).order(created_at: :desc)
    @drafts = current_user.proposals.drafts.order(updated_at: :desc)
  end

  def show
    authorize @proposal
  end

  # Nowe zgłoszenie: dane osobowe z konta UKE, dalej kreator.
  def create
    authorize Proposal
    proposal = current_user.proposals.build(esod_category: Proposal::ESOD_CATEGORY_EGZAMIN, **profile_attributes)
    proposal.save!(validate: false)
    redirect_to proposal_wizard_path(proposal, Proposal::FORM_STEPS.first)
  end

  # Usunięcie niedokończonego (niewysłanego) zgłoszenia.
  def destroy
    authorize @proposal
    @proposal.destroy!
    redirect_to proposals_path, notice: t("activerecord.successfull.messages.destroyed", data: @proposal.rec_info), status: :see_other
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
                                division_short_name division_min_years_old])
    proposal = current_user.proposals.build(esod_category: Proposal::ESOD_CATEGORY_POPRAWKOWY, **profile_attributes, **copied.symbolize_keys)
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

    def profile_attributes
      user = current_user
      { email: user.email, name: user.last_name.to_s, given_names: user.first_name.to_s, pesel: user.pesel.to_s,
        birth_date: user.birth_date || Pesel.new(user.pesel).birth_date, birth_place: user.birth_city.to_s,
        family_name: user.family_name.to_s, phone: user.phone.to_s }
    end
end
