module ApplicationHelper
  # Pole formularza: etykieta (z gwiazdką dla wymaganych), pole, komunikat błędu i podpowiedź.
  def form_field(form, attribute, required: false, hint: nil, &block)
    record = form.object
    label = form.label(attribute, class: "field__label") do
      safe_join([ record.class.human_attribute_name(attribute), (tag.span(" *", class: "required", aria: { hidden: true }) if required) ])
    end
    hint_tag = tag.span(hint, id: "#{attribute}_hint", class: "field__hint") if hint
    tag.div(class: "field") { safe_join([ label, capture(&block), field_error(record, attribute), hint_tag ]) }
  end

  # Atrybuty dostępności pola: powiązanie z podpowiedzią i komunikatem błędu.
  def field_aria(record, attribute, hint: false)
    ids = []
    ids << "#{attribute}_hint" if hint
    ids << "#{attribute}_error" if record.errors.include?(attribute)
    { invalid: record.errors.include?(attribute) || nil, describedby: ids.join(" ").presence }
  end

  def field_error(record, attribute)
    return unless record.errors.include?(attribute)

    tag.span record.errors.full_messages_for(attribute).first, id: "#{attribute}_error", class: "field-error"
  end

  # Pole daty ze sztywnym formatem RRRR-MM-DD (jak w poprzednich aplikacjach). Bazowo pole tekstowe z maską `pattern`
  # (działa bez JavaScriptu); kontroler Stimulus "date-field" dodaje maskę wpisywania i natywny kalendarz.
  def iso_date_field(f, record, attribute, required: false)
    text = f.text_field attribute, class: "form-control form-control-sm", inputmode: "numeric", autocomplete: "off",
      maxlength: 10, pattern: '\\d{4}-\\d{2}-\\d{2}', placeholder: t("helpers.date_field.format"),
      required: required, aria: field_aria(record, attribute),
      data: { "date-field-target": "text", action: "input->date-field#mask" }
    picker = tag.span class: "date-field__picker" do
      button = tag.button(calendar_icon, type: "button", class: "date-field__button", hidden: true,
        aria: { label: t("helpers.date_field.pick") },
        data: { "date-field-target": "button", action: "date-field#open" })
      native = tag.input(type: "date", class: "date-field__native", tabindex: -1, "aria-hidden": true,
        data: { "date-field-target": "native", action: "change->date-field#sync" })
      safe_join([ button, native ])
    end
    tag.div safe_join([ text, picker ]), class: "date-field", data: { controller: "date-field" }
  end

  def calendar_icon
    <<~SVG.html_safe
      <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
    SVG
  end

  def country_name(code)
    country = ISO3166::Country[code.to_s]
    country ? "#{country.translations['pl'] || country.common_name} (#{code})" : code
  end

  def status_class(proposal)
    case proposal.proposal_status_id
    when Proposal::PROPOSAL_STATUS_APPROVED, Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_P then "status--ok"
    when Proposal::PROPOSAL_STATUS_ANNULLED, Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_Z then "status--warn"
    when Proposal::PROPOSAL_STATUS_CREATED then nil
    else "status--bad"
    end
  end

  # Jak w poprzedniej wersji: „75,00 PLN”.
  def price(value)
    "#{number_with_precision(value, precision: 2, separator: ',', delimiter: ' ', strip_insignificant_zeros: false)} PLN"
  end
end
