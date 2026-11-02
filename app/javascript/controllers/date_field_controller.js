import { Controller } from "@hotwired/stimulus"

// Pole daty ze sztywnym formatem RRRR-MM-DD. Działa też bez JavaScriptu (zwykłe pole tekstowe z maską `pattern`);
// JS dodaje maskę wpisywania (tylko cyfry, automatyczne myślniki) i przycisk otwierający natywny kalendarz
// (showPicker na ukrytym polu type="date"), zawsze zapisując wartość w formacie ISO RRRR-MM-DD.
export default class extends Controller {
  static targets = ["text", "button", "native"]

  connect() {
    // Kalendarz pokazujemy tylko tam, gdzie przeglądarka wspiera showPicker(); inaczej zostaje samo pole tekstowe.
    if (this.hasButtonTarget && this.hasNativeTarget && typeof this.nativeTarget.showPicker === "function") {
      this.buttonTarget.hidden = false
    }
  }

  // Maska: tylko cyfry, układ RRRR-MM-DD, maksymalnie 8 cyfr.
  mask() {
    const digits = this.textTarget.value.replace(/\D/g, "").slice(0, 8)
    let out = digits.slice(0, 4)
    if (digits.length > 4) out += "-" + digits.slice(4, 6)
    if (digits.length > 6) out += "-" + digits.slice(6, 8)
    this.textTarget.value = out
  }

  open() {
    if (this.textTarget.disabled) return
    this.nativeTarget.value = this.isoOrEmpty(this.textTarget.value)
    this.nativeTarget.showPicker()
  }

  // Po wyborze w natywnym kalendarzu – wartość (ISO) trafia do pola tekstowego.
  sync() {
    if (!this.nativeTarget.value) return
    this.textTarget.value = this.nativeTarget.value
    this.textTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  isoOrEmpty(value) {
    return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : ""
  }
}
