import { Controller } from "@hotwired/stimulus"

// Wygląd strony: jasny / ciemny / wysoki kontrast. Tryb to atrybuty na <html>:
// data-theme (nasze style) i data-bs-theme (Bootstrap: kontrast korzysta z jego trybu ciemnego).
// Ustawiane już w <head>, przed narysowaniem strony; wybór zapamiętujemy w przeglądarce.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.sync()
  }

  select(event) {
    const theme = event.currentTarget.dataset.themeValue
    const root = document.documentElement
    root.setAttribute("data-theme", theme)
    root.setAttribute("data-bs-theme", theme === "light" ? "light" : "dark")
    try { localStorage.setItem("theme", theme) } catch (e) {}
    this.sync()
  }

  sync() {
    const current = document.documentElement.getAttribute("data-theme")
    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", button.dataset.themeValue === current ? "true" : "false")
    })
  }
}
