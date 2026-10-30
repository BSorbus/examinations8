import { Controller } from "@hotwired/stimulus"

// Kontrola pliku przed wysłaniem (typ i rozmiar – te same reguły sprawdza serwer) i podgląd zdjęcia.
export default class extends Controller {
  static targets = ["input", "error", "preview"]
  static values = { types: Array, maxSize: Number, typeMessage: String, sizeMessage: String }

  check() {
    const file = this.inputTarget.files[0]
    let message = ""
    if (file && !this.typesValue.includes(file.type)) message = this.typeMessageValue
    else if (file && file.size > this.maxSizeValue) message = this.sizeMessageValue

    this.errorTarget.textContent = message
    this.errorTarget.hidden = message === ""
    this.inputTarget.setAttribute("aria-invalid", String(message !== ""))
    if (message) this.inputTarget.value = ""

    if (this.hasPreviewTarget) {
      this.previewTarget.hidden = !(file && !message)
      if (file && !message) this.previewTarget.src = URL.createObjectURL(file)
    }
  }
}
