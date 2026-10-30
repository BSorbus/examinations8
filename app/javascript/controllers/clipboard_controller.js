import { Controller } from "@hotwired/stimulus"

// Przycisk „Kopiuj” przy danych do przelewu.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copied: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
      const label = this.buttonTarget.textContent
      this.buttonTarget.textContent = this.copiedValue
      setTimeout(() => { this.buttonTarget.textContent = label }, 2000)
    } catch (e) {
      // Bez dostępu do schowka – tekst można zaznaczyć i skopiować ręcznie.
    }
  }
}
