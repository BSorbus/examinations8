# Zmiana zgłoszenia przez NETPAR: status (z komentarzem), sesja egzaminacyjna, odblokowanie testu online.
# Każda zmiana statusu wysyła mail do użytkownika (Proposal#send_notification) i trafia do historii zgłoszenia.
class Api::V1::ProposalsController < Api::V1::BaseController
  PERMITTED = %w[proposal_status_id not_approved_comment exam_id exam_fullname exam_date_exam test_unlocked].freeze

  def update
    proposal = Proposal.find_by(multi_app_identifier: params[:multi_app_identifier])
    return render(json: { error: "Brak zgłoszenia #{params[:multi_app_identifier]}" }, status: :not_found) unless proposal

    changes = Netpar::Payload.parse(params.require(:proposal)).slice(*PERMITTED)
    # Zapis i wpis w historii w jednej transakcji (blokada wiersza – np. równoczesne unieważnienie przez
    # użytkownika). Mail – dopiero po zatwierdzeniu, więc błąd poczty nie zwraca NETPAR błędu zapisanej zmiany.
    saved = proposal.with_lock do
      proposal.assign_attributes(changes)
      next false unless proposal.save

      changed = proposal.saved_changes.except("updated_at").transform_values(&:last)
      proposal.log_event("netpar_update", **changed) if changed.any?
      true
    end

    if saved
      render json: { multi_app_identifier: proposal.multi_app_identifier, proposal_status_id: proposal.proposal_status_id }
    else
      render json: { errors: proposal.errors }, status: :unprocessable_content
    end
  rescue JSON::ParserError, ArgumentError => e
    render json: { error: "Niepoprawne dane zgłoszenia: #{e.message.truncate(100)}" }, status: :unprocessable_content
  end
end
