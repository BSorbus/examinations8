# Pola z błędem oznaczamy sami (aria-invalid, komunikat pod polem) – bez domyślnego <div class="field_with_errors">,
# który rozbija układ pola numeru (lista + prefiks + cyfry).
Rails.application.config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }
