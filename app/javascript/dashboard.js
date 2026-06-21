// Dashboard chart rendering. This module lives in the importmap (loaded once,
// persisted across Turbo navigations), so its `turbo:load` listener survives
// the full-body refresh the import job broadcasts. That matters because Turbo
// dedupes identical inline scripts and may skip re-evaluating a chart-init
// script after a refresh — relying on a persisted listener reading the freshly
// re-rendered `#dashboard-data` JSON block is the robust path.
const charts = {};

function readData() {
  const el = document.getElementById("dashboard-data");
  if (!el) return null;
  try {
    return JSON.parse(el.textContent);
  } catch (e) {
    console.error("Invalid dashboard-data JSON", e);
    return null;
  }
}

function destroy(name) {
  if (charts[name]) {
    try { charts[name].destroy(); } catch (_) {}
    charts[name] = null;
  }
}

function buildCharts() {
  const data = readData();
  if (!data || typeof Chart === "undefined") return;

  ["requests", "status", "browser", "os"].forEach(destroy);

  const doughnutOpts = {
    responsive: true,
    plugins: { legend: { position: "right", labels: { color: "#94a3b8", font: { size: 12 } } } }
  };

  const ctx1 = document.getElementById("requestsChart");
  if (ctx1) {
    const rph = data.requests_per_hour || {};
    charts.requests = new Chart(ctx1, {
      type: "line",
      data: {
        labels: Object.keys(rph),
        datasets: [{
          data: Object.values(rph),
          borderColor: "#34d399",
          backgroundColor: "rgba(52, 211, 153, 0.1)",
          fill: true,
          tension: 0.3
        }]
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: "#64748b", maxRotation: 0, autoSkip: true, maxTicksLimit: 8 }, grid: { display: false } },
          y: { ticks: { color: "#64748b" }, grid: { color: "#1e293b" } }
        }
      }
    });
  }

  const ctx2 = document.getElementById("statusChart");
  if (ctx2) {
    const sc = data.status_counts || {};
    const colors = Object.keys(sc).map(s => {
      const code = parseInt(s, 10);
      if (code >= 200 && code < 300) return "#34d399";
      if (code >= 300 && code < 400) return "#60a5fa";
      if (code >= 400 && code < 500) return "#fbbf24";
      if (code >= 500) return "#f87171";
      return "#94a3b8";
    });
    charts.status = new Chart(ctx2, {
      type: "doughnut",
      data: { labels: Object.keys(sc), datasets: [{ data: Object.values(sc), backgroundColor: colors }] },
      options: doughnutOpts
    });
  }

  const ctx3 = document.getElementById("browserChart");
  if (ctx3) {
    const bc = data.browser_counts || {};
    const palette = { Firefox: "#f97316", Chrome: "#60a5fa", Safari: "#34d399", Edge: "#3b82f6", Opera: "#f87171", Other: "#94a3b8", Unknown: "#475569" };
    charts.browser = new Chart(ctx3, {
      type: "doughnut",
      data: { labels: Object.keys(bc), datasets: [{ data: Object.values(bc), backgroundColor: Object.keys(bc).map(k => palette[k] || "#94a3b8") }] },
      options: doughnutOpts
    });
  }

  const ctx4 = document.getElementById("osChart");
  if (ctx4) {
    const oc = data.os_counts || {};
    const palette = { Windows: "#60a5fa", macOS: "#94a3b8", Android: "#34d399", iOS: "#a78bfa", Linux: "#fbbf24", ChromeOS: "#f87171", Other: "#64748b", Unknown: "#475569" };
    charts.os = new Chart(ctx4, {
      type: "doughnut",
      data: { labels: Object.keys(oc), datasets: [{ data: Object.values(oc), backgroundColor: Object.keys(oc).map(k => palette[k] || "#94a3b8") }] },
      options: doughnutOpts
    });
  }
}

document.addEventListener("turbo:load", buildCharts);
