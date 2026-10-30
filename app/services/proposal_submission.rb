# Wysłanie zgłoszenia do NETPAR i zapis u nas – tak, aby obie strony się nie rozjechały.
#
# NETPAR nie pilnuje unikalności multi_app_identifier (ponowny POST = duplikat), a odpowiedź może nie dotrzeć
# (limit czasu) mimo zapisu po stronie NETPAR. Dlatego:
#   1. blokada doradcza PostgreSQL na czas całej operacji – drugie kliknięcie czeka i widzi wysłane zgłoszenie,
#   2. przed wywołaniem NETPAR zapisujemy (od razu, poza transakcją) „wysyłanie w toku” – REQUIRED_PUSH_TO_NETPAR,
#   3. jeśli poprzednia próba mogła dotrzeć do NETPAR – najpierw PATCH (aktualizacja), a POST dopiero przy 404,
#   4. po sukcesie – w jednej transakcji: status SAVED_IN_NETPAR, potwierdzenie danych i wpis w historii;
#      mail wychodzi dopiero po zatwierdzeniu transakcji (Proposal#send_notification, after_commit).
# Błąd NETPAR (Netpar::Rejected / Netpar::Unavailable) zostawia zgłoszenie do ponownego wysłania.
class ProposalSubmission
  LOCK_NAMESPACE = 4201

  # confirmed – zaznaczone przez użytkownika „Dane powyższe są zgodne z prawdą…”.
  def initialize(proposal, confirmed:, netpar: Netpar::Client.new)
    @proposal = proposal
    @confirmed = confirmed
    @netpar = netpar
  end

  # true – wysłane (także gdy już było wysłane wcześniej); false – dane niepoprawne (proposal.errors).
  def call
    with_advisory_lock do
      @proposal.reload
      return true if @proposal.submitted?

      @proposal.confirm_that_the_data_is_correct = @confirmed
      @proposal.form_step = nil
      return false unless @proposal.valid?

      uncertain_previous_attempt = @proposal.status == Proposal::REQUIRED_PUSH_TO_NETPAR
      @proposal.update_columns(status: Proposal::REQUIRED_PUSH_TO_NETPAR, updated_at: Time.current)
      @proposal.update_attachment_paths
      push(uncertain_previous_attempt)
      finish
      true
    end
  end

  private
    # Pola, którymi zarządza NETPAR – ponowienie (PATCH) ich nie wysyła, żeby nie cofnąć np. akceptacji
    # wykonanej w NETPAR po pierwszej, niepotwierdzonej próbie.
    NETPAR_OWNED = %w[proposal_status_id not_approved_comment test_unlocked].freeze

    def push(uncertain_previous_attempt)
      attributes = @proposal.netpar_attributes.merge("status" => Proposal::SAVED_IN_NETPAR)
      if uncertain_previous_attempt && @netpar.update_proposal(@proposal.multi_app_identifier, attributes.except(*NETPAR_OWNED))
        return
      end

      @netpar.create_proposal(attributes)
    end

    def finish
      Proposal.transaction do
        @proposal.status = Proposal::SAVED_IN_NETPAR
        @proposal.save!(validate: false)
        @proposal.log_event("submitted", exam_id: @proposal.exam_id, division_id: @proposal.division_id)
      end
    end

    def with_advisory_lock
      connection = Proposal.connection
      connection.execute("SELECT pg_advisory_lock(#{LOCK_NAMESPACE}, #{@proposal.id.to_i})")
      yield
    ensure
      connection&.execute("SELECT pg_advisory_unlock(#{LOCK_NAMESPACE}, #{@proposal.id.to_i})")
    end
end
