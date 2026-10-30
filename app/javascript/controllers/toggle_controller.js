import { Controller } from "@hotwired/stimulus"

// Pola zależne od pola wyboru (np. „Mieszkam w Polsce”): pokazuje „when-checked” albo „when-unchecked”
// i wyłącza ukryte pola, żeby nie trafiały do formularza.
export default class extends Controller {
  static targets = ["checkbox", "whenChecked", "whenUnchecked"]

  connect() {
    this.update()
  }

  update() {
    const checked = this.checkboxTarget.checked
    this.show(this.whenCheckedTargets, checked)
    this.show(this.whenUncheckedTargets, !checked)
  }

  show(elements, visible) {
    elements.forEach((element) => {
      element.hidden = !visible
      element.querySelectorAll("input, select, textarea").forEach((field) => { field.disabled = !visible })
    })
  }
}
