# Podgląd maili (development): http://localhost:3000/rails/mailers/proposal_mailer
# Dane fikcyjne, bez zapisu w bazie i bez wywołań NETPAR.
class ProposalMailerPreview < ActionMailer::Preview
  ProposalMailer::STATUS_MAILS.each_value do |name|
    define_method(name) { mail(name) }
  end

  def approved_online = mail(:approved, exam_online: true)
  def reminder = mail(:reminder)

  private
    def mail(name, **overrides)
      params = { proposal: proposal(**overrides) }
      params[:need_corrections] = [ "Przepisy", "Technika radiowa" ] if name == :examination_result_n
      ProposalMailer.with(**params).public_send(name)
    end

    def proposal(**overrides)
      creator = User.new(email: "jan.kowalski@example.com", first_name: "Jan", last_name: "Kowalski")
      Proposal.new(
        creator:, multi_app_identifier: "00000000-0000-4000-8000-000000000000", created_at: Time.current,
        email: creator.email, name: "Kowalski", given_names: "Jan", category: "R", esod_category: Proposal::ESOD_CATEGORY_EGZAMIN,
        division_short_name: "A", exam_fullname: "R/12/2026, #{Date.current + 30}, Gdynia [POMORSKIE], sala 1",
        exam_date_exam: Date.current + 30, proposal_status_id: Proposal::PROPOSAL_STATUS_NOT_APPROVED,
        not_approved_comment: "Brak potwierdzenia wpłaty.\nProszę złożyć zgłoszenie ponownie.", **overrides
      )
    end
end
