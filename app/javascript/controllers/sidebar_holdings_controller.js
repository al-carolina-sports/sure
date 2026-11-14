import { Controller } from "@hotwired/stimulus";

// Opens the right sidebar on the Holdings tab when an account in the left
// sidebar is chosen, and reveals the same panel as a sheet on a small screen.
export default class extends Controller {
  static targets = ["panel"];

  open(event) {
    this.element
      .querySelectorAll("[data-sidebar-holdings-account-id]")
      .forEach((link) => {
        const selected = link === event.currentTarget;
        link.classList.toggle("bg-container", selected);
        link.classList.toggle("hover:bg-surface-hover", !selected);
      });

    this.#expand();
    this.panelTarget.querySelector("[data-id='holdings']")?.click();
  }

  close() {
    if (!this.hasPanelTarget) return;

    this.panelTarget.classList.add("max-lg:hidden");
  }

  #expand() {
    if (!this.hasPanelTarget) return;

    this.panelTarget.classList.remove("max-lg:hidden");
    if (this.panelTarget.classList.contains("w-0")) {
      this.element.querySelector("[data-sidebar-holdings-toggle]")?.click();
    }
  }
}
