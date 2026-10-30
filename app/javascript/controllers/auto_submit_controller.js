import { Controller } from "@hotwired/stimulus"

// Formularz wyboru (np. służba i rodzaj świadectwa) wysyłany od razu po zmianie pola.
// Bez JavaScriptu zostaje widoczny przycisk „Pokaż”.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.buttonTargets.forEach((button) => button.classList.add("visually-hidden"))
  }

  submit() {
    this.element.requestSubmit()
  }
}
