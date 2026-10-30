# Elementy maili (style wpisane w HTML – programy pocztowe nie czytają arkuszy CSS). Kolory jak na stronie,
# kontrast tekstu ≥ 4,5:1.
module MailerHelper
  STATUS_COLORS = {
    ok: [ "#E8F5EC", "#14532D" ],    # zaakceptowane, wynik pozytywny
    bad: [ "#FDECEA", "#7A1A12" ],   # odrzucone, zamknięte, wynik negatywny
    warn: [ "#FFF4E0", "#7A4100" ],  # anulowane, zmiana terminu, nieobecność
    info: [ "#EEF1F7", "#1B3C8F" ]
  }.freeze

  # Słowo statusu (treść bez zmian) jako plakietka.
  def mail_status(word, kind)
    background, color = STATUS_COLORS.fetch(kind)
    tag.strong(word, style: "display: inline-block; padding: 2px 10px; border-radius: 999px; background: #{background}; " \
                            "color: #{color}; font-size: 13px; letter-spacing: .03em;")
  end

  # Sesja egzaminacyjna w wyróżnionej ramce.
  def mail_box(text)
    tag.p(text, style: "margin: 8px 0 16px; padding: 12px 16px; background: #F3F5F9; border-left: 4px solid #1B3C8F; " \
                       "border-radius: 6px; font-weight: 600;")
  end
end
