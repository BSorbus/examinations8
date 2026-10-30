import { Controller } from "@hotwired/stimulus"

// Egzamin online (TestPortal): test otwiera się w ramce na stronie; podczas testu pozostałe przyciski są
// zablokowane. Ramka zgłasza koniec testu komunikatem "test-end" (jak w poprzedniej wersji).
export default class extends Controller {
  static targets = ["button", "frame", "message"]
  static values = { nextTest: String, allDone: String }

  connect() {
    this.remaining = this.buttonTargets.length
    this.onMessage = (event) => { if (event.data === "test-end") this.finished() }
    window.addEventListener("message", this.onMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.onMessage)
  }

  start(event) {
    this.buttonTargets.forEach((button) => { button.disabled = button !== event.currentTarget })
    this.frameTarget.hidden = false
  }

  finished() {
    this.buttonTargets.forEach((button) => { button.disabled = false })
    this.remaining -= 1
    this.messageTarget.textContent = this.remaining > 0 ? this.nextTestValue : this.allDoneValue
    this.messageTarget.focus()
  }
}
