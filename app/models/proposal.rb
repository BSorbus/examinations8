# Zgłoszenie na egzamin (elektroniczny wniosek), wypełniane w kreatorze w 5 krokach i wysyłane do NETPAR.
# Statusy (proposal_status_id) nadaje NETPAR – przychodzą przez API (Api::V1::ProposalsController).
# Kolumna `status` zapamiętuje ostatni zapisany krok kreatora, a po wysłaniu – SAVED_IN_NETPAR.
class Proposal < ApplicationRecord
  ESOD_CATEGORY_EGZAMIN = 41
  ESOD_CATEGORY_POPRAWKOWY = 42
  ESOD_CATEGORY_NAMES = {
    ESOD_CATEGORY_EGZAMIN => "Wniosek o przeprowadzenie egzaminu",
    ESOD_CATEGORY_POPRAWKOWY => "Wniosek o przeprowadzenie egzaminu poprawkowego"
  }.freeze

  PROPOSAL_STATUS_CREATED = 1
  PROPOSAL_STATUS_APPROVED = 2
  PROPOSAL_STATUS_NOT_APPROVED = 3
  PROPOSAL_STATUS_CLOSED = 4
  PROPOSAL_STATUS_ANNULLED = 5
  PROPOSAL_STATUS_EXAMINATION_RESULT_B = 6  # Negatywny bez prawa do poprawki
  PROPOSAL_STATUS_EXAMINATION_RESULT_N = 7  # Negatywny z prawem do poprawki
  PROPOSAL_STATUS_EXAMINATION_RESULT_O = 8  # Nieobecny
  PROPOSAL_STATUS_EXAMINATION_RESULT_P = 9  # Pozytywny
  PROPOSAL_STATUS_EXAMINATION_RESULT_Z = 10 # Zmiana terminu
  PROPOSAL_STATUSES = (1..10).to_a.freeze

  CATEGORY_NAMES = {
    "M" => "Świadectwo służby morskiej i żeglugi śródlądowej",
    "R" => "Uprawnienia w służbie radioamatorskiej"
  }.freeze

  SAVED_IN_NETPAR = "saved_in_netpar"
  # Wysyłanie do NETPAR rozpoczęte, wynik niepewny (np. limit czasu) – patrz ProposalSubmission.
  REQUIRED_PUSH_TO_NETPAR = "required_push_to_netpar"
  FORM_STEPS = %w[step1 step2 step3 step4 step5].freeze

  PDF_MAX_SIZE = 600_000
  IMAGE_MAX_SIZE = 2_000_000
  IMAGE_TYPES = %w[image/jpg image/jpeg image/png].freeze

  # Krok kreatora, dla którego sprawdzamy dane (nil – wszystkie kroki).
  attr_accessor :form_step, :remove_other_pdf

  belongs_to :creator, class_name: "User", inverse_of: :proposals
  has_one_attached :bank_pdf
  has_one_attached :face_image
  has_one_attached :consent_pdf
  has_one_attached :other_pdf
  has_many :events, class_name: "ProposalEvent", dependent: :delete_all

  scope :submitted, -> { where(confirm_that_the_data_is_correct: true) }
  scope :drafts, -> { where(confirm_that_the_data_is_correct: false).where("status IS NULL OR status <> ?", SAVED_IN_NETPAR) }

  validates :proposal_status_id, presence: true, inclusion: { in: PROPOSAL_STATUSES }
  validates :esod_category, presence: true

  # Kroki kreatora: 1) egzamin, 2) dane osobowe, 3) adres, 4) opłata i załączniki, 5) podsumowanie.
  # Uwaga: warunek kroku łączymy z warunkiem pola w tablicy `if:` – w `with_options` wewnętrzne `if:`
  # zastępowałoby warunek kroku.
  STEP1 = -> { step?(:step1) }
  STEP2 = -> { step?(:step2) }
  STEP3 = -> { step?(:step3) }
  STEP4 = -> { step?(:step4) }

  validates :category, presence: true, inclusion: { in: CATEGORY_NAMES.keys }, if: STEP1
  validates :division_id, presence: true, if: [ STEP1, -> { category.present? } ]
  validates :exam_id, presence: true, if: [ STEP1, -> { division_id.present? } ]
  validate :unique_division_for_creator, if: [ STEP1, -> { division_id.present? } ]

  validates :email, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\z/ }, if: STEP2
  validates :name, presence: true, length: { in: 1..160 }, if: STEP2
  validates :given_names, presence: true, length: { in: 1..50 }, if: STEP2
  validates :citizenship_code, presence: true, length: { in: 1..50 }, if: STEP2
  validates :phone, length: { maximum: 50 }, if: STEP2
  validates :birth_place, presence: true, length: { in: 1..50 }, if: STEP2
  validates :birth_date, presence: true, if: STEP2
  validates :family_name, presence: true, length: { in: 1..50 }, if: STEP2
  validate :pesel_valid, if: [ STEP2, -> { pesel.present? } ]
  # Wiek – po „Dalej” na zakładce 2 (data urodzenia jest na tym formularzu), wymóg rodzaju z NETPAR.
  validate :min_years_old, if: [ STEP2, -> { division_min_years_old.present? && birth_date.present? } ]

  validates :address_combine_id, presence: true, if: [ STEP3, :lives_in_poland? ]
  validates :city_name, presence: true, length: { in: 1..50 }, if: STEP3, unless: :lives_in_poland?
  validates :street_name, length: { maximum: 50 }, if: STEP3, unless: :lives_in_poland?
  validates :c_address_house, presence: true, length: { in: 1..10 }, if: STEP3
  validates :c_address_number, length: { maximum: 10 }, if: STEP3
  validates :c_address_postal_code, presence: true, length: { in: 6..10 }, if: STEP3

  validates :exam_fee_id, :exam_fee_price, presence: true, if: STEP4
  validate :attachments_present, if: STEP4
  validate :attachments_types_and_sizes, if: STEP4

  validates :confirm_that_the_data_is_correct, acceptance: { accept: [ true ] }, if: -> { step?(:step5) }

  after_initialize do
    self.proposal_status_id ||= PROPOSAL_STATUS_CREATED
    self.multi_app_identifier ||= SecureRandom.uuid
  end

  after_commit :send_notification, on: %i[create update]

  def to_param = multi_app_identifier

  def log_event(kind, **data) = events.create!(kind:, data:)

  # Zgłoszenie zaczęte w kreatorze, jeszcze niewysłane do NETPAR.
  def draft? = !submitted?

  def correction_exam? = esod_category == ESOD_CATEGORY_POPRAWKOWY

  # Krok, od którego użytkownik kontynuuje niedokończone zgłoszenie.
  def next_step
    return FORM_STEPS.last if status == REQUIRED_PUSH_TO_NETPAR

    saved = FORM_STEPS.index(status.to_s)
    saved ? FORM_STEPS[[ saved + 1, FORM_STEPS.size - 1 ].min] : FORM_STEPS.first
  end

  def submitted? = status == SAVED_IN_NETPAR

  def category_name = CATEGORY_NAMES[category]

  def esod_category_name = ESOD_CATEGORY_NAMES[esod_category]

  # „Zgłoszenie 2026-10-29 12:00:00 [Uprawnienia w służbie radioamatorskiej][A]” – jak w poprzedniej wersji.
  def rec_info = I18n.t("proposals.proposal.rec_info", data: rec_info_short)

  def rec_info_short = "#{created_at&.strftime('%Y-%m-%d %H:%M:%S')} [#{category_name}][#{division_short_name}]"

  def status_name = I18n.t("proposals.status_id_#{proposal_status_id}_name")

  # --- dane z usług zewnętrznych (wywoływane przez kreator, nie w walidacji) ---

  # Krok 3: adres z TERYT (hash z API /Address/:combine_id).
  def assign_teryt_address(item)
    self.province_code, self.province_name = item["provinceCode"], item["provinceName"]
    self.district_code, self.district_name = item["districtCode"], item["districtName"]
    self.commune_code, self.commune_name = item["communeCode"], item["communeName"]
    self.city_code, self.city_name = item["cityCode"], item["cityName"]
    self.city_parent_code = item["parentCityCode"].presence || ""
    self.city_parent_name = item["parentCityName"].presence || ""
    self.street_code = item["streetCode"].presence || ""
    self.street_name = item["streetName"].presence || ""
    self.street_attribute = item["streetAttribute"].presence || ""
  end

  # Krok 3: adres poza Polską – bez kodów TERYT (miejscowość i ulicę wpisuje użytkownik).
  def clear_teryt_address
    self.address_combine_id = nil
    self.province_code = self.province_name = self.district_code = self.district_name = ""
    self.commune_code = self.commune_name = self.city_code = ""
    self.city_parent_code = self.city_parent_name = self.street_code = self.street_attribute = ""
  end

  # Krok 1: rodzaj świadectwa i sesja z NETPAR (hashe z API /divisions/:id i /exams/:id).
  def assign_division(division)
    self.division_id = division["id"]
    self.division_fullname = division["fullname"]
    self.division_short_name = division["short_name"]
    self.division_min_years_old = division["min_years_old"]
    self.division_face_image_required = division["face_image_required"] == true
  end

  def assign_exam(exam)
    self.exam_id = exam["id"]
    self.exam_fullname = exam["fullname"]
    self.exam_date_exam = exam["date_exam"]
    self.exam_online = exam["online"] == true
  end

  # Krok 4: opłata z NETPAR (cena ulgowa dla osób, które nie ukończyły 18 lat).
  def assign_exam_fee(fee)
    self.exam_fee_id = fee["id"]
    self.exam_fee_price = under_18? ? fee["price_under18"] : fee["price"]
  end

  def clear_exam_fee
    self.exam_fee_id = nil
    self.exam_fee_price = nil
  end

  # Krok 1: zmiana kategorii lub rodzaju zeruje dalsze wybory.
  def reset_division
    self.division_id = self.division_fullname = self.division_short_name = self.division_min_years_old = nil
    self.division_face_image_required = false
    reset_exam
  end

  def reset_exam
    self.exam_id = self.exam_fullname = self.exam_date_exam = nil
    self.exam_online = false
    clear_exam_fee
  end

  # Dane wysyłane do NETPAR (wszystkie kolumny zgłoszenia oprócz pustych).
  def netpar_attributes
    as_json.compact
  end

  # --- reguły dostępne dla użytkownika ---

  def can_annul?
    exam_date_exam.present? && exam_date_exam - 14.days > Time.zone.today &&
      [ PROPOSAL_STATUS_CREATED, PROPOSAL_STATUS_APPROVED ].include?(proposal_status_id)
  end

  def can_correction_exam? = proposal_status_id == PROPOSAL_STATUS_EXAMINATION_RESULT_N

  def test_unlocked_for_user?
    Rails.configuration.x.examinations[:test_for_all_unlocked] || test_unlocked?
  end

  def can_take_tests?
    exam_online? && proposal_status_id == PROPOSAL_STATUS_APPROVED && test_unlocked_for_user?
  end

  # Wymóg zdjęcia – z NETPAR (ustawienie rodzaju świadectwa „Wymagane zdjęcie”).
  def face_image_required? = division_face_image_required?

  # Dane osobowe z konta UKE (WSO2). Imię, nazwisko i e-mail – zawsze z konta (na formularzu niezmienialne);
  # pozostałe – tylko puste, żeby powrót na zakładkę 1 nie nadpisał danych poprawionych na zakładce 2.
  def fill_from_profile(user)
    self.email, self.name, self.given_names = user.email, user.last_name.to_s, user.first_name.to_s
    { pesel: user.pesel.to_s, birth_date: user.birth_date || Pesel.new(user.pesel).birth_date, birth_place: user.birth_city.to_s,
      family_name: user.family_name.to_s, phone: user.phone.to_s }.each { |attribute, value| self[attribute] = value if self[attribute].blank? }
  end

  def consent_pdf_required? = birth_date.present? && birth_date >= Time.zone.today - 18.years

  def under_18? = birth_date.present? && birth_date >= 18.years.ago.to_date

  # Linki do załączników dla NETPAR (urzędnik otwiera je z poziomu NETPAR).
  def update_attachment_paths
    helpers = Rails.application.routes.url_helpers
    %i[bank_pdf face_image consent_pdf other_pdf].each do |name|
      attachment = public_send(name)
      self["#{name}_blob_path"] = attachment.attached? ? helpers.rails_blob_path(attachment, only_path: true) : nil
    end
  end

  # Załączniki, które przestały być wymagane (zmiana kategorii lub wieku), i „inny załącznik” do usunięcia.
  def purge_unneeded_attachments
    face_image.purge_later if face_image.attached? && !face_image_required?
    consent_pdf.purge_later if consent_pdf.attached? && !consent_pdf_required?
    other_pdf.purge_later if other_pdf.attached? && remove_other_pdf == "1"
  end

  # --- zadania cykliczne ---

  # Przypomnienie 3 dni przed egzaminem (zgłoszenia zaakceptowane).
  # Zwraca liczbę wysłanych przypomnień.
  def self.send_reminders(date: Time.zone.today + 3.days)
    where(proposal_status_id: PROPOSAL_STATUS_APPROVED, exam_date_exam: date).find_each.count do |proposal|
      ProposalMailer.with(proposal:).reminder.deliver_now
    rescue StandardError => e # błąd jednego maila nie zatrzymuje pozostałych
      Rails.logger.error("[reminder] zgłoszenie #{proposal.id}: #{e.class}: #{e.message}")
      false
    end
  end

  # Niedokończone zgłoszenia (nie wysłane do NETPAR), nieruszane od 30 dni – razem z załącznikami.
  # Poprzednia wersja pomijała zgłoszenia bez zapisanego kroku (status NULL) – tu są usuwane również.
  # Nie usuwamy zgłoszeń z niepewnym wynikiem wysyłania (REQUIRED_PUSH_TO_NETPAR) – mogą być już w NETPAR.
  def self.clean_unsaved(before: Time.zone.today - 30.days)
    where(proposal_status_id: PROPOSAL_STATUS_CREATED, confirm_that_the_data_is_correct: false)
      .where(updated_at: ..before.beginning_of_day)
      .where("status IS NULL OR status NOT IN (?)", [ SAVED_IN_NETPAR, REQUIRED_PUSH_TO_NETPAR ])
      .find_each.count(&:destroy)
  end

  private
    # Jak w poprzedniej wersji: po wysłaniu do NETPAR dane kroków nie są ponownie sprawdzane
    # (np. przy zmianie statusu przez API NETPAR).
    def step?(step)
      return false if submitted?

      form_step.nil? || FORM_STEPS.index(step.to_s) <= FORM_STEPS.index(form_step.to_s)
    end

    def pesel_valid
      parsed = Pesel.new(pesel)
      if !parsed.valid?
        errors.add(:pesel, "jest niepoprawny")
      elsif birth_date.present? && parsed.birth_date != birth_date
        errors.add(:birth_date, "niezgodność danych z danymi PESEL")
      end
    end

    def unique_division_for_creator
      duplicate = Proposal.where(division_id:, creator_id:, confirm_that_the_data_is_correct: true,
                                 proposal_status_id: [ PROPOSAL_STATUS_CREATED, PROPOSAL_STATUS_APPROVED ])
                          .where.not(id:).where.not(exam_id: nil)
      errors.add(:division_id, "Jest aktualnie procedowane Twoje zgłoszenie dla tego typu świadectwa") if duplicate.exists?
    end

    def min_years_old
      if birth_date + division_min_years_old.years > Time.zone.today
        errors.add(:birth_date, "- Przystąpienie do egzaminu wymaga ukończenia #{division_min_years_old} lat")
      end
    end

    def attachments_present
      errors.add(:bank_pdf, "wymaga dodania pliku typu PDF") unless bank_pdf.attached?
      errors.add(:face_image, "wymaga dodania pliku typu JPG/JPEG/PNG") if face_image_required? && !face_image.attached?
      errors.add(:consent_pdf, "wymaga dodania pliku typu PDF") if consent_pdf_required? && !consent_pdf.attached?
    end

    def attachments_types_and_sizes
      %i[bank_pdf consent_pdf other_pdf].each { check_attachment(it, %w[application/pdf], PDF_MAX_SIZE, "PDF", "600kB") }
      check_attachment(:face_image, IMAGE_TYPES, IMAGE_MAX_SIZE, "JPG/JPEG/PNG", "2MB")
    end

    def check_attachment(name, types, max_size, type_label, size_label)
      attachment = public_send(name)
      return unless attachment.attached?

      if types.exclude?(attachment.blob.content_type)
        errors.add(name, "nieprawidłowy typ pliku (wymagany typ #{type_label})")
      elsif attachment.blob.byte_size > max_size
        errors.add(name, "plik jest za duży (max #{size_label})")
      end
    end

    # Mail przy każdej zmianie statusu wysłanego zgłoszenia (i przy samym wysłaniu – status „utworzone”).
    def send_notification
      return unless submitted?
      return unless saved_change_to_proposal_status_id? || saved_change_to_status?

      ProposalMailer.for_status(self)&.deliver_later
    end
end
