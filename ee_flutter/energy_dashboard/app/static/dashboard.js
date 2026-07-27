window.addEventListener("DOMContentLoaded", function () {
  var element = document.getElementById("dashboard-data");
  if (!element || typeof Plotly === "undefined") return;
  var data = JSON.parse(element.textContent);
  var config = {responsive: true, displaylogo: false};
  var layout = function (title) {
    return {
      title: {text: title, font: {size: 15}},
      margin: {l: 48, r: 18, t: 52, b: 58},
      paper_bgcolor: "#ffffff",
      plot_bgcolor: "#ffffff",
      font: {family: "Arial, sans-serif", color: "#263238"},
    };
  };
  var bar = function (id, series, title, color) {
    Plotly.newPlot(id, [{
      x: series.labels,
      y: series.values,
      type: "bar",
      marker: {color: color},
    }], layout(title), config);
  };
  var line = function (id, series, title, color) {
    Plotly.newPlot(id, [{
      x: series.labels,
      y: series.values,
      type: "scatter",
      mode: "lines+markers",
      line: {color: color, width: 3},
    }], layout(title), config);
  };
  var donut = function (id, series, title) {
    Plotly.newPlot(id, [{
      labels: series.labels,
      values: series.values,
      type: "pie",
      hole: 0.55,
      marker: {colors: ["#e3263a", "#2f6f73", "#467a52", "#d39b2a", "#6c5b7b", "#4b6a88"]},
    }], layout(title), config);
  };

  line("trap-time", data.traps.time, "Trampas por fecha", "#e3263a");
  donut("trap-sections", data.traps.sections, "Registros por seccion");
  bar("trap-types", data.traps.types, "Tipos de aplicacion", "#2f6f73");
  donut("trap-methods", data.traps.methods, "Directo vs indirecto");
  bar("trap-equipment", data.traps.equipment, "Equipos con mas analisis", "#6c5b7b");

  bar("pipe-meters", data.barePipe.metersBySection, "Metros por seccion", "#2f6f73");
  bar("pipe-loss", data.barePipe.lossBySection, "Perdida kW por seccion", "#e3263a");
  bar("pipe-diameter", data.barePipe.metersByDiameter, "Metros por diametro", "#d39b2a");
  line("pipe-time", data.barePipe.time, "Nuevos reportes", "#467a52");

  line("boiler-bunker", data.boilers.bunker, "Bunker validado", "#e3263a");
  line("boiler-water", data.boilers.water, "Agua validada", "#2f6f73");
  line("boiler-steam", data.boilers.steam, "Vapor validado", "#467a52");
  donut("boiler-share", data.boilers.share, "Participacion por caldera");

  bar("pump-power", data.pumps.powerBySection, "Potencia kW por seccion", "#e3263a");
  bar("pump-count", data.pumps.countBySection, "Bombas por seccion", "#2f6f73");
  Plotly.newPlot("pump-hp-kw", [{
    x: data.pumps.hp,
    y: data.pumps.kw,
    text: data.pumps.tags,
    mode: "markers",
    type: "scatter",
    marker: {color: "#d39b2a", size: 10},
  }], layout("HP nominal vs potencia electrica kW"), config);
  Plotly.newPlot("pump-unbalance", [{
    x: data.pumps.tags,
    y: data.pumps.currentUnbalance,
    type: "bar",
    marker: {color: "#6c5b7b"},
  }], layout("Desequilibrio de corriente por equipo"), config);
  donut("pump-confidence", data.pumps.confidence, "Nivel de confianza");
  donut("pump-ranges", data.pumps.powerRanges, "Distribucion por rango HP");
  Plotly.newPlot("pump-savings", [{
    x: data.pumps.savings.map(function (item) { return item.assetId; }),
    y: data.pumps.savings.map(function (item) { return item.savedKw; }),
    type: "bar",
    marker: {color: "#467a52"},
  }], layout("Ahorro linea base vs posterior (kW)"), config);

  line("leak-time", data.leaks.time, "Fugas por fecha", "#e3263a");
  donut("leak-types", data.leaks.types, "Fugas por tipo");
  bar("leak-sections", data.leaks.sections, "Fugas por seccion", "#2f6f73");
  donut("leak-statuses", data.leaks.statuses, "Estado de atencion");
});
