import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

// Donut for the portfolio allocation section. Segments, colours and drill
// links come from the server. Labels sit in left and right columns with a
// short leader; a narrow screen keeps the ring and leaves the names to the
// table.
export default class extends Controller {
  static targets = ["chart"];
  static values = {
    segments: { type: Array, default: [] },
  };

  #resizeObserver = null;
  #labelThreshold = 2.5;

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

    const width = this.chartTarget.clientWidth || 256;
    const labelled = width >= 520;
    const viewWidth = labelled ? 240 : 100;
    const viewHeight = 100;
    const cx = viewWidth / 2;
    const cy = viewHeight / 2;
    const outer = labelled ? 28 : 46;
    const inner = labelled ? 17 : 28;

    const svg = root
      .append("svg")
      .attr("viewBox", `0 0 ${viewWidth} ${viewHeight}`)
      .attr("class", "h-full w-full text-primary")
      .attr("role", "img")
      .attr("aria-hidden", "true");

    const total = segments.reduce(
      (sum, segment) => sum + Number(segment.amount),
      0,
    );
    const pie = d3
      .pie()
      .sort(null)
      .padAngle(segments.length > 1 ? 0.012 : 0)
      .value((segment) => Number(segment.amount));
    const arc = d3.arc().innerRadius(inner).outerRadius(outer).cornerRadius(1);
    const arcs = pie(segments);

    const plot = svg.append("g").attr("transform", `translate(${cx}, ${cy})`);

    plot
      .selectAll("path")
      .data(arcs)
      .enter()
      .append("path")
      .attr("d", arc)
      .attr("fill", (datum) => datum.data.color)
      .attr("data-segment-id", (datum) => datum.data.id)
      .attr("class", "cursor-pointer")
      .on("click", (_event, datum) => this.#open(datum.data))
      .on("mouseover", (_event, datum) => this.#emphasize(datum.data.id))
      .on("mouseleave", () => this.#emphasize(null));

    if (!labelled) return;

    const showAmount = true;
    const labels = arcs
      .map((datum) => {
        const percent = (Number(datum.data.amount) / total) * 100;
        if (percent < this.#labelThreshold) return null;
        const angle = (datum.startAngle + datum.endAngle) / 2;
        return {
          datum,
          percent,
          side: Math.sin(angle) >= 0 ? "right" : "left",
          angle,
          naturalY: cy - Math.cos(angle) * (outer + 4),
        };
      })
      .filter(Boolean);

    this.#stack(
      labels.filter((label) => label.side === "right"),
      viewHeight,
    );
    this.#stack(
      labels.filter((label) => label.side === "left"),
      viewHeight,
    );

    const leaders = svg.append("g").attr("class", "leaders");
    const texts = svg.append("g").attr("class", "labels");

    labels.forEach((label) => {
      const x1 = cx + Math.sin(label.angle) * (outer + 1);
      const y1 = cy - Math.cos(label.angle) * (outer + 1);
      const column = label.side === "right" ? cx + outer + 10 : cx - outer - 10;
      const end = label.side === "right" ? column + 4 : column - 4;

      leaders
        .append("path")
        .attr("data-segment-id", label.datum.data.id)
        .attr("fill", "none")
        .attr("stroke", "currentColor")
        .attr("stroke-opacity", 0.4)
        .attr("stroke-width", 0.4)
        .attr("d", `M${x1},${y1} L${column},${label.y} L${end},${label.y}`);

      const text = texts
        .append("text")
        .attr("data-segment-id", label.datum.data.id)
        .attr("x", label.side === "right" ? end + 1.5 : end - 1.5)
        .attr("y", label.y)
        .attr("fill", "currentColor")
        .attr("text-anchor", label.side === "right" ? "start" : "end")
        .attr("dominant-baseline", "middle")
        .style("font-size", "5px")
        .attr("class", label.datum.data.href ? "cursor-pointer" : null)
        .text(this.#labelText(label));

      const amount = label.datum.data.amount_label;
      if (showAmount && label.percent >= 8 && amount) {
        text
          .append("tspan")
          .attr("x", label.side === "right" ? end + 1.5 : end - 1.5)
          .attr("dy", "5.6")
          .attr("opacity", 0.7)
          .text(amount);
      }

      if (label.datum.data.href) {
        text.on("click", () => this.#open(label.datum.data));
      }
    });
  }

  #labelText(label) {
    const name = this.#shorten(label.datum.data.label || "", 22);
    const percent = `${label.percent.toFixed(1)}%`;
    return `${name} ${percent}`;
  }

  #shorten(name, max) {
    if (name.length <= max) return name;
    return `${name.slice(0, max - 1)}…`;
  }

  #stack(labels, viewHeight) {
    const gap = 14;
    const top = 6;
    const bottom = viewHeight - 6;
    labels.sort((a, b) => a.naturalY - b.naturalY);
    labels.forEach((label, index) => {
      label.y = Math.max(label.naturalY, top + index * gap);
    });
    for (let index = labels.length - 1; index >= 0; index -= 1) {
      const max = bottom - (labels.length - 1 - index) * gap;
      if (labels[index].y > max) labels[index].y = max;
    }
  }

  #open(segment) {
    if (!segment.href) return;
    Turbo.visit(segment.href);
  }

  #emphasize(id) {
    if (!this.hasChartTarget) return;

    this.chartTarget.querySelectorAll("path, text").forEach((node) => {
      const match = !id || node.dataset.segmentId === id;
      node.setAttribute("opacity", match ? "1" : "0.35");
    });

    this.element.querySelectorAll("tr[data-segment-id]").forEach((row) => {
      row.classList.toggle("bg-container-hover", row.dataset.segmentId === id);
    });
  }
}
