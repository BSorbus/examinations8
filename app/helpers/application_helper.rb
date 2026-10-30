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
