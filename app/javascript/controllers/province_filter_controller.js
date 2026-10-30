import { Controller } from "@hotwired/stimulus"

// Zawęża listę sesji do wybranego województwa (sesje online widoczne zawsze).
export default class extends Controller {
  static targets = ["select", "item"]

  filter() {
    const province = this.selectTarget.value
    this.itemTargets.forEach((item) => {
      item.hidden = province !== "" && item.dataset.province !== province && item.dataset.online !== "true"
    })
  }
}
