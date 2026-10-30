import { Controller } from "@hotwired/stimulus"

// Wyszukiwarka adresów TERYT – combobox (ARIA 1.2): pole tekstowe + lista podpowiedzi, obsługa klawiaturą
// (strzałki, Enter, Escape). Wybrany adres zapisywany w ukrytym polu address_combine_id.
export default class extends Controller {
  static targets = ["input", "list", "value", "status", "selected"]
  static values = { url: String, typeMore: String, noResults: String, numbers: String }

  connect() {
    this.items = []
    this.active = -1
  }

  search() {
    clearTimeout(this.timer)
    const query = this.inputTarget.value.trim()
    if (query.length < 3) {
      this.close()
      this.statusTarget.textContent = this.typeMoreValue
      return
    }
    this.timer = setTimeout(() => this.fetch(query), 250)
  }

  async fetch(query) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error)
      this.items = data.items || []
      this.render()
    } catch (error) {
      this.close()
      this.statusTarget.textContent = error.message || ""
    }
  }

  render() {
    this.listTarget.innerHTML = ""
    this.active = -1
    this.items.forEach((item, index) => {
      const option = document.createElement("li")
      option.id = `${this.listTarget.id}-${index}`
      option.className = "combobox__option"
      option.setAttribute("role", "option")
      option.setAttribute("aria-selected", "false")
      option.dataset.index = index
      option.append(this.label(item))
      const details = document.createElement("small")
      details.textContent = ` – ${[item.postCode, item.communeName, item.districtName, item.provinceName].filter(Boolean).join(", ")}`
      option.append(details)
      // Zakres numerów domów dla kodu pocztowego (jak w poprzedniej wersji) – pomaga wybrać właściwy kod.
      if (item.postCodeNumbers) {
        const numbers = document.createElement("small")
        numbers.className = "combobox__numbers"
        numbers.textContent = `${this.numbersValue} ${item.postCodeNumbers}`
        option.append(document.createElement("br"), numbers)
      }
      option.addEventListener("mousedown", (event) => { event.preventDefault(); this.choose(index) })
      this.listTarget.append(option)
    })
    this.listTarget.hidden = this.items.length === 0
    this.inputTarget.setAttribute("aria-expanded", String(this.items.length > 0))
    this.statusTarget.textContent = this.items.length === 0 ? this.noResultsValue : `${this.items.length}`
  }

  label(item) {
    let city = item.cityName
    if (item.parentCityName && item.parentCityName !== item.cityName) city += ` (${item.parentCityName})`
    return item.streetName ? `${city}, ${item.streetAttribute || ""} ${item.streetName}`.replace(/\s+/g, " ") : city
  }

  keydown(event) {
    if (this.listTarget.hidden) return
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.highlight((this.active + step + this.items.length) % this.items.length)
    } else if (event.key === "Enter" && this.active >= 0) {
      event.preventDefault()
      this.choose(this.active)
    } else if (event.key === "Escape") {
      this.close()
    }
  }

  highlight(index) {
    this.active = index
    this.listTarget.querySelectorAll("[role=option]").forEach((option, i) => {
      option.setAttribute("aria-selected", String(i === index))
      if (i === index) option.scrollIntoView({ block: "nearest" })
    })
    this.inputTarget.setAttribute("aria-activedescendant", `${this.listTarget.id}-${index}`)
  }

  choose(index) {
    const item = this.items[index]
    this.valueTarget.value = item.combineId
    const numbers = item.postCodeNumbers ? ` (${this.numbersValue} ${item.postCodeNumbers})` : ""
    this.selectedTarget.textContent = `${this.label(item)}, ${item.postCode}${numbers} – ${[item.communeName, item.districtName, item.provinceName].join(", ")}`
    this.inputTarget.value = ""
    this.close()
  }

  close() {
    this.listTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }
}
