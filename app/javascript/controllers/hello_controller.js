import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = [ "output", "hide", "show", "color" ]

  connect() {
    this.showTarget.hidden = true
  }

  hide() {
    this.outputTarget.hidden = true
    this.hideTarget.hidden = true
    this.showTarget.hidden = false
  }

  show() {
    this.outputTarget.hidden = false
    this.hideTarget.hidden = false
    this.showTarget.hidden = true
  }

  color() {
    this.outputTarget.style.backgroundColor = this.element.querySelector('#color').checked ? "yellow" : ""; 
  }

}
