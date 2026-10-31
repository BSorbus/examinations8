# Kreator zgłoszenia: 1) egzamin, 2) dane osobowe, 3) adres, 4) opłata i załączniki, 5) podsumowanie i wysłanie.
# Rodzaje, sesje i opłaty pobieramy z NETPAR na żywo; dane rodzaju i sesji zapisujemy z odpowiedzi NETPAR
# (nie z formularza), a adres – z TERYT.
class Proposals::StepsController < ApplicationController
  STEP_PARAMS = {
    "step1" => %i[category division_id exam_id],
    "step2" => %i[pesel citizenship_code birth_place birth_date family_name phone],
    "step3" => %i[lives_in_poland address_combine_id city_name street_name c_address_house c_address_number c_address_postal_code],
    "step4" => %i[bank_pdf face_image consent_pdf other_pdf remove_other_pdf],
    "step5" => %i[confirm_that_the_data_is_correct]
  }.freeze

  before_action :authenticate_user!
  before_action :set_proposal_and_step
  before_action :require_previous_steps

  rescue_from Netpar::Unavailable, Teryt::Unavailable do |e|
    Rails.logger.error("[#{e.class.module_parent.name.upcase}] #{e.message}")
    @service_error = t(e.is_a?(Teryt::Unavailable) ? "teryt.unavailable" : "netpar.unavailable")
    prepare_step rescue nil # lista sesji itp. – na ile się da
    render :show, status: :service_unavailable
  end

  def show
    prepare_step
  end

  def update
    @proposal.form_step = @step
    @proposal.assign_attributes(step_params)
    send("apply_#{@step}")

    if @step == "step5"
      submit
    elsif @proposal.valid?
      @proposal.status = @step if Proposal::FORM_STEPS.index(@step) >= Proposal::FORM_STEPS.index(@proposal.status.to_s).to_i
      @proposal.save!(validate: false)
      redirect_to proposal_wizard_path(@proposal, params[:return_to_summary].present? ? "step5" : next_step), status: :see_other
    else
      prepare_step
      render :show, status: :unprocessable_content
    end
  end

  private
    def set_proposal_and_step
      @proposal = Proposal.find_by!(multi_app_identifier: params[:proposal_multi_app_identifier])
      authorize @proposal, :edit?
      @step = params[:id].to_s
      raise ActionController::RoutingError, "Nieznany krok" unless Proposal::FORM_STEPS.include?(@step)
    end

    # Kroki po kolei – bez przeskakiwania niewypełnionych.
    def require_previous_steps
      allowed = Proposal::FORM_STEPS.index(@proposal.next_step)
      redirect_to proposal_wizard_path(@proposal, @proposal.next_step) if Proposal::FORM_STEPS.index(@step) > allowed
    end

    def next_step = Proposal::FORM_STEPS[Proposal::FORM_STEPS.index(@step) + 1]

    def step_params
      params.fetch(:proposal, {}).permit(STEP_PARAMS.fetch(@step))
    end

    def prepare_step
      case @step
      when "step1"
        @divisions, @exams = [], [] # gdy NETPAR nie odpowie – puste listy i komunikat
        @category = params[:category].presence_in(Proposal::CATEGORY_NAMES.keys) || @proposal.category
        @category = @proposal.category if @proposal.correction_exam?
        @division_id = (@proposal.correction_exam? ? @proposal.division_id : (params[:division_id].presence || @proposal.division_id)).to_i
        @divisions = @category.present? ? available_divisions(@category) : []
        @division_id = nil unless @divisions.any? { it["id"] == @division_id }
        @exams = @division_id ? available_exams(@category, @division_id) : []
      when "step4"
        assign_exam_fee if @proposal.exam_fee_id.blank?
      end
    end

    def available_divisions(category = @proposal.category)
      @available_divisions ||= {}
      @available_divisions[category] ||= netpar.divisions(category:)
    end

    def available_exams(category = @proposal.category, division_id = @proposal.division_id)
      @available_exams ||= {}
      @available_exams[[ category, division_id ]] ||= netpar.exams(category:, division_id:)
    end

    def assign_exam_fee
      fee = netpar.exam_fee(division_id: @proposal.division_id, esod_category: @proposal.esod_category,
                            for_date: @proposal.exam_date_exam)
      fee ? @proposal.assign_exam_fee(fee) : @proposal.clear_exam_fee
    end

    # --- dane z NETPAR / TERYT dla poszczególnych kroków (wywoływane w update) ---

    def apply_step1
      if @proposal.correction_exam?
        # W zgłoszeniu poprawkowym służba i rodzaj są takie jak w poprzednim zgłoszeniu.
        @proposal.category, @proposal.division_id = @proposal.category_was, @proposal.division_id_was
      end
      division = @proposal.division_id.present? && available_divisions.find { it["id"] == @proposal.division_id }
      exam = division && @proposal.exam_id.present? && available_exams.find { it["id"] == @proposal.exam_id }
      division ? @proposal.assign_division(netpar.division(division["id"]) || division) : @proposal.reset_division
      exam ? @proposal.assign_exam(netpar.exam(exam["id"]) || exam) : @proposal.reset_exam
      @proposal.clear_exam_fee
      # Dane osobowe z konta UKE trafiają na formularz zakładki 2 dopiero teraz (po „Dalej” na zakładce 1).
      @proposal.fill_from_profile(current_user)
    end

    def apply_step2; end

    def apply_step3
      return @proposal.clear_teryt_address unless @proposal.lives_in_poland?

      address = Teryt::Client.new.address(@proposal.address_combine_id)
      address ? @proposal.assign_teryt_address(address) : (@proposal.address_combine_id = nil)
    end

    def apply_step4
      assign_exam_fee
      @proposal.purge_unneeded_attachments
    end

    def apply_step5; end

    # Krok 5: sprawdzenie wszystkich kroków i wysłanie do NETPAR (ProposalSubmission – bez duplikatów w NETPAR).
    def submit
      if ProposalSubmission.new(@proposal, confirmed: @proposal.confirm_that_the_data_is_correct, netpar:).call
        redirect_to proposals_path, notice: t("activerecord.successfull.messages.created", data: @proposal.rec_info), status: :see_other
      else
        render :show, status: :unprocessable_content
      end
    rescue Netpar::Rejected => e
      Rails.logger.warn("[NETPAR] #{e.message}")
      @service_error = t("netpar.rejected", messages: e.messages.join("; "))
      render :show, status: :unprocessable_content
    end
end
