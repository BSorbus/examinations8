# Maile o zgłoszeniu – treści 1:1 z poprzedniej wersji (app/views/proposal_mailer). Każdy wysłany mail
# trafia do historii zgłoszenia.
class ProposalMailer < ApplicationMailer
  UKE_SESSIONS_URLS = {
    "R" => "https://bip.uke.gov.pl/egzaminy-tresc/egzaminy-w-sluzbie-radiokomunikacyjnej-amatorskiej,1.html",
    "M" => "http://bip.uke.gov.pl/swiadectwa-operatora-urzadzen-radiowych-tresci/swiadectwa-morskie-i-zeglugi-srodladowej,4.html"
  }.freeze

  STATUS_MAILS = {
    Proposal::PROPOSAL_STATUS_CREATED => :created,
    Proposal::PROPOSAL_STATUS_APPROVED => :approved,
    Proposal::PROPOSAL_STATUS_NOT_APPROVED => :not_approved,
    Proposal::PROPOSAL_STATUS_CLOSED => :closed,
    Proposal::PROPOSAL_STATUS_ANNULLED => :annulled,
    Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_B => :examination_result_b,
    Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N => :examination_result_n,
    Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_O => :examination_result_o,
    Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_P => :examination_result_p,
    Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_Z => :examination_result_z
  }.freeze

  before_action :prepare
  after_deliver { @proposal.log_event("mail", template: action_name, to: message.to&.first) }

  # Mail dla bieżącego statusu zgłoszenia (nil – brak maila dla statusu).
  def self.for_status(proposal)
    mail_name = STATUS_MAILS[proposal.proposal_status_id]
    with(proposal:).public_send(mail_name) if mail_name
  end

  STATUS_MAILS.values.without(:approved, :examination_result_n).each do |name|
    define_method(name) { deliver_mail }
  end

  def approved
    deliver_mail(template_name: @proposal.exam_online? ? "approved_online" : "approved")
  end

  def examination_result_n
    # Przedmioty do poprawki – z NETPAR (podgląd maili podaje je w parametrze need_corrections).
    @proposal_need_corrections = params[:need_corrections] || @proposal.failed_subject_names
    deliver_mail
  end

  def reminder = deliver_mail

  private
    def prepare
      @proposal = params.fetch(:proposal)
      @proposal_fullname = @proposal.rec_info
      @proposal_url_uuid = proposal_url(@proposal)
      @uke_sessions_url = UKE_SESSIONS_URLS.fetch(@proposal.category, UKE_SESSIONS_URLS["M"])
      attachments.inline["logo_uke.png"] = Rails.root.join("app/assets/images/logo_uke_pl_do_lewej_small.png").binread
    end

    def deliver_mail(**options)
      mail(to: @proposal.creator.email, subject: "#{t('title')} - #{@proposal_fullname}", **options)
    end
end
