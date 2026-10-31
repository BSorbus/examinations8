# Zgłoszenia dla NETPAR:
#   GET   /api/v1/proposals/:multi_app_identifier – zgłoszenie (komplet pól), a do tego zgody RODO zgłaszającego
#         i historia zgłoszenia po stronie Egzaminów,
#   PATCH /api/v1/proposals/:multi_app_identifier – zmiana: status (z komentarzem), sesja, odblokowanie testu online;
#         każda zmiana statusu wysyła mail do użytkownika (Proposal#send_notification) i trafia do historii zgłoszenia.
class Api::V1::ProposalsController < Api::V1::BaseController
  PERMITTED = %w[proposal_status_id not_approved_comment exam_id exam_fullname exam_date_exam test_unlocked].freeze

  before_action :set_proposal

  # Zgłoszenie jak w danych dla NETPAR (wszystkie kolumny) oraz dodatki: opis, zgody RODO (valid_at_submission – zgoda
  # obowiązująca w chwili wysłania zgłoszenia, ostatnia zaakceptowana przed submitted_at) i historia zgłoszenia.
  def show
    consents = @proposal.creator.privacy_consents.order(:accepted_at, :id).to_a
    at_submission = @proposal.submitted_at && consents.select { it.accepted_at <= @proposal.submitted_at }.last
    render json: @proposal.as_json.merge(
      rec_info: @proposal.rec_info,
      privacy_current_version: PrivacyConsent.current_version,
      privacy_consents: consents.map do |consent|
        { version: consent.version, accepted_at: consent.accepted_at, ip: consent.ip, valid_at_submission: consent == at_submission }
      end,
      events: @proposal.events.order(:created_at, :id).map do |event|
        { kind: event.kind, name: I18n.t("proposals.events.#{event.kind}"), created_at: event.created_at, data: event.data }
      end
    )
  end

  def update
    changes = Netpar::Payload.parse(params.require(:proposal)).slice(*PERMITTED)
    # Zapis i wpis w historii w jednej transakcji (blokada wiersza – np. równoczesne unieważnienie przez
    # użytkownika). Mail – dopiero po zatwierdzeniu, więc błąd poczty nie zwraca NETPAR błędu zapisanej zmiany.
    saved = @proposal.with_lock do
      @proposal.assign_attributes(changes)
      next false unless @proposal.save

      changed = @proposal.saved_changes.except("updated_at").transform_values(&:last)
      @proposal.log_event("netpar_update", **changed) if changed.any?
      true
    end

    if saved
      render json: { multi_app_identifier: @proposal.multi_app_identifier, proposal_status_id: @proposal.proposal_status_id }
    else
      render json: { errors: @proposal.errors }, status: :unprocessable_content
    end
  rescue JSON::ParserError, ArgumentError => e
    render json: { error: "Niepoprawne dane zgłoszenia: #{e.message.truncate(100)}" }, status: :unprocessable_content
  end

  private
    def set_proposal
      @proposal = Proposal.find_by(multi_app_identifier: params[:multi_app_identifier])
      render json: { error: "Brak zgłoszenia #{params[:multi_app_identifier]}" }, status: :not_found unless @proposal
    end
end
