import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

// Donut for the portfolio allocation section. Segments, colours and drill
// links come from the server; this only draws and forwards a click.
export default class extends Controller {
  static targets = ["chart"];
  static values = {
    segments: { type: Array, default: [] },
  };

  #resizeObserver = null;

  connect() {
    this.#draw();
    if (typeof ResizeObserver !== "undefined" && this.hasChartTarget) {
      this.#resizeObserver = new ResizeObserver(() => this.#draw());
      this.#resizeObserver.observe(this.chartTarget);
    }
  }

  disconnect() {
    this.#resizeObserver?.disconnect();
    this.#resizeObserver = null;
  }

  // Legend rows call these. The slice under the pointer stays solid.
  highlight(event) {
    this.#emphasize(event.currentTarget.dataset.segmentId);
  }

  clear() {
    this.#emphasize(null);
  }

  #draw() {
    if (!this.hasChartTarget) return;

    const root = d3.select(this.chartTarget);
    root.selectAll("*").remove();

    const segments = this.segmentsValue.filter(
      (segment) => Number(segment.amount) > 0,
    );
    if (!segments.length) return;

    const size = 100;
    const svg = root
      .append("svg")
      .attr("viewBox", `0 0 ${size} ${size}`)
      .attr("class", "h-full w-full")
      .attr("aria-hidden", "true");

    const pie = d3
      .pie()
      .sort(null)
      .padAngle(segments.length > 1 ? 0.012 : 0)
      .value((segment) => Number(segment.amount));

    const arc = d3.arc().innerRadius(28).outerRadius(46).cornerRadius(1);

    svg
      .append("g")
      .attr("transform", `translate(${size / 2}, ${size / 2})`)
      .selectAll("path")
      .data(pie(segments))
      .enter()
      .append("path")
      .attr("d", arc)
      .attr("fill", (datum) => datum.data.color)
      .attr("data-segment-id", (datum) => datum.data.id)
      .attr("class", "cursor-pointer")
      .on("click", (_event, datum) => this.#open(datum.data))
      .on("mouseover", (_event, datum) => this.#emphasize(datum.data.id))
      .on("mouseleave", () => this.#emphasize(null));
  }

  #open(segment) {
    if (!segment.href) return;
    Turbo.visit(segment.href);
  }

  #emphasize(id) {
    if (!this.hasChartTarget) return;

    this.chartTarget.querySelectorAll("path").forEach((path) => {
      path.setAttribute(
        "opacity",
        !id || path.dataset.segmentId === id ? "1" : "0.35",
      );
    });

    this.element.querySelectorAll("tr[data-segment-id]").forEach((row) => {
      row.classList.toggle("bg-container-hover", row.dataset.segmentId === id);
    });
  }
}
