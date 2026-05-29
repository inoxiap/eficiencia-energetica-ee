const BRAND_VERSION = "0.1.0-pwa";

const CONSTANTS = {
  palmOilSpecificHeatKjKgC: 2.0,
  palmOilDensityKgL: 0.89,
  condensateDensityKgL: 1.0,
  defaultSafetyFactor: 1.2,
  ambientTemperatureC: 30.0,
  freeConvectionUWm2C: 11.36,
  boilerHeaderCondensatePercent: 12.0,
  secondaryDistributorDrainagePercent: 1.0,
  distributorDesignVelocityMS: 10.0,
  atmosphericPressureBar: 1.01325,
  steamGasConstantJKgK: 461.5,
  steamPressureBarG: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  steamTemperatureC: [120.2, 133.5, 143.6, 151.8, 158.8, 165.0, 170.4, 175.4, 179.9, 184.1, 188.0, 191.6, 195.0, 198.3, 201.4],
  steamLatentHeatKjKg: [2201.6, 2163.2, 2133.4, 2108.0, 2085.8, 2066.3, 2048.8, 2032.9, 2014.6, 2000.0, 1984.3, 1970.7, 1957.7, 1945.2, 1933.6]
};

const noDecimal = new Intl.NumberFormat("es-EC", { maximumFractionDigits: 0 });
const oneDecimal = new Intl.NumberFormat("es-EC", { minimumFractionDigits: 1, maximumFractionDigits: 1 });

const state = {
  selectedRule: null,
  fields: new Map()
};

const elements = {
  splash: document.getElementById("splash"),
  homeScreen: document.getElementById("homeScreen"),
  trapScreen: document.getElementById("trapScreen"),
  openTrapModule: document.getElementById("openTrapModule"),
  backHomeButton: document.getElementById("backHomeButton"),
  useSelect: document.getElementById("useSelect"),
  recommendationPanel: document.getElementById("recommendationPanel"),
  trapType: document.getElementById("trapType"),
  condition: document.getElementById("condition"),
  observations: document.getElementById("observations"),
  inputPanel: document.getElementById("inputPanel"),
  unknownCondensate: document.getElementById("unknownCondensate"),
  directFields: document.getElementById("directFields"),
  indirectFields: document.getElementById("indirectFields"),
  calculateButton: document.getElementById("calculateButton"),
  resultPanel: document.getElementById("resultPanel"),
  resultTitle: document.getElementById("resultTitle"),
  resultBody: document.getElementById("resultBody")
};

const rules = createRules();

window.addEventListener("load", () => {
  setTimeout(() => elements.splash.classList.add("is-hidden"), 1000);
});

document.addEventListener("DOMContentLoaded", () => {
  populateUseSelect();
  bindEvents();
  showHomeScreen();
  registerServiceWorker();
});

function bindEvents() {
  elements.openTrapModule.addEventListener("click", showTrapScreen);
  elements.backHomeButton.addEventListener("click", showHomeScreen);

  elements.useSelect.addEventListener("change", () => {
    const selectedName = elements.useSelect.value;
    state.selectedRule = rules.find((rule) => rule.name === selectedName) || null;
    refreshRule();
  });

  elements.unknownCondensate.addEventListener("change", () => {
    refreshInputFields();
    setResultMessage("Resultado", "Completa los datos y presiona Calcular.");
  });

  elements.calculateButton.addEventListener("click", calculate);
}

function showHomeScreen() {
  elements.homeScreen.classList.remove("is-hidden");
  elements.trapScreen.classList.add("is-hidden");
  resetSelection();
}

function showTrapScreen() {
  elements.homeScreen.classList.add("is-hidden");
  elements.trapScreen.classList.remove("is-hidden");
  resetSelection();
}

function populateUseSelect() {
  const names = [
    "",
    "Tracing",
    "Serpentín de tanque",
    "Chaqueta o Marmita",
    "Chaqueta trabajo pesado",
    "Distribuidor principal de caldero",
    "Distribuidor de vapor",
    "Intercambiador de calor",
    "Linea principal de vapor (Pierna de condensado)"
  ];

  elements.useSelect.replaceChildren(...names.map((name) => {
    const option = document.createElement("option");
    option.value = name;
    option.textContent = name || "Selecciona un uso";
    return option;
  }));
}

function resetSelection() {
  state.selectedRule = null;
  elements.useSelect.value = "";
  elements.unknownCondensate.checked = false;
  elements.recommendationPanel.classList.add("is-hidden");
  elements.inputPanel.classList.add("is-hidden");
  elements.resultPanel.classList.add("is-hidden");
}

function refreshRule() {
  const rule = state.selectedRule;
  state.fields.clear();
  elements.directFields.replaceChildren();
  elements.indirectFields.replaceChildren();

  if (!rule) {
    resetSelection();
    return;
  }

  elements.trapType.textContent = rule.trapType;
  elements.condition.textContent = rule.condition;
  elements.observations.textContent = rule.observations;
  elements.recommendationPanel.classList.remove("is-hidden");

  if (!rule.requiresSizing) {
    elements.inputPanel.classList.add("is-hidden");
    elements.resultPanel.classList.add("is-hidden");
    return;
  }

  elements.inputPanel.classList.remove("is-hidden");
  elements.resultPanel.classList.remove("is-hidden");
  elements.unknownCondensate.checked = false;
  refreshInputFields();
  setResultMessage("Resultado", "Completa los datos y presiona Calcular.");
}

function refreshInputFields() {
  const rule = state.selectedRule;
  if (!rule || !rule.requiresSizing) {
    return;
  }

  state.fields.clear();
  elements.directFields.replaceChildren();
  elements.indirectFields.replaceChildren();

  const estimateIndirectly = elements.unknownCondensate.checked;
  elements.directFields.classList.toggle("is-hidden", estimateIndirectly);
  elements.indirectFields.classList.toggle("is-hidden", !estimateIndirectly);

  if (estimateIndirectly) {
    rule.fields.forEach((field) => addField(elements.indirectFields, field));
  } else {
    addField(elements.directFields, fieldSpec("directCondensate", "Caudal de condensado a desalojar", "L/min", 0, 100, 1, 0));
  }
}

function addField(parent, spec) {
  state.fields.set(spec.key, spec);

  const wrapper = document.createElement("div");
  wrapper.className = "field-card";

  const label = document.createElement("label");
  label.htmlFor = `field-${spec.key}`;
  label.textContent = `${spec.label} (${spec.unit})`;

  const select = document.createElement("select");
  select.id = `field-${spec.key}`;
  select.dataset.key = spec.key;

  const values = buildValues(spec);
  values.forEach((value, index) => {
    const option = document.createElement("option");
    option.value = String(value);
    option.textContent = spec.customLabels ? spec.customLabels[index] : formatPickerValue(value, spec.step);
    if (Math.abs(value - spec.defaultValue) < 0.0001) {
      option.selected = true;
    }
    select.appendChild(option);
  });

  const hint = document.createElement("p");
  hint.className = "field-hint";
  hint.textContent = "Selecciona con la rueda";

  wrapper.append(label, select, hint);
  parent.appendChild(wrapper);
}

function buildValues(spec) {
  if (spec.customValues) {
    return spec.customValues.slice();
  }

  const values = [];
  for (let value = spec.min; value <= spec.max + 0.0001; value += spec.step) {
    values.push(roundOne(value));
  }
  return values;
}

function value(key) {
  const select = document.querySelector(`[data-key="${key}"]`);
  if (!select) {
    return 0;
  }
  return Number(select.value);
}

function calculate() {
  const rule = state.selectedRule;
  if (!rule) {
    return;
  }

  const estimateIndirectly = elements.unknownCondensate.checked;
  let calculation;

  if (estimateIndirectly) {
    calculation = rule.calculate();
  } else {
    const directCondensateLMin = value("directCondensate");
    if (directCondensateLMin <= 0) {
      setResultMessage("Falta el caudal", '<span class="error-text">Ingresa el caudal de condensado a desalojar o marca "No conozco la cantidad de condensado".</span>');
      return;
    }
    const directCondensateKgH = directCondensateLMin * CONSTANTS.condensateDensityKgL * 60;
    calculation = {
      condensateKgH: directCondensateKgH,
      explanation: `Medición directa de ${oneDecimal.format(directCondensateLMin)} L/min, convertida con densidad aproximada de condensado de 1.0 kg/L.`
    };
  }

  const recommendedCapacity = calculation.condensateKgH * rule.safetyFactor;
  const pressure = Math.max(0, value("steamPressure"));
  const rows = [
    ["Uso", rule.name],
    ["Tipo recomendado", rule.trapType],
    ["Carga estimada", `${noDecimal.format(calculation.condensateKgH)} kg/h`],
    ["Equivalente aproximado", `${noDecimal.format(calculation.condensateKgH / CONSTANTS.condensateDensityKgL)} L/h`],
    ["Factor de seguridad", oneDecimal.format(rule.safetyFactor)],
    ["Capacidad mínima sugerida", `${noDecimal.format(recommendedCapacity)} kg/h`],
    ["Diámetro preliminar sugerido", recommendTrapConnectionDiameter(recommendedCapacity)]
  ];

  if (pressure > 0) {
    rows.push(["Presión de vapor considerada", `${oneDecimal.format(pressure)} bar(g)`]);
  }

  elements.resultTitle.textContent = "Resumen de trampa requerida";
  elements.resultBody.innerHTML = rows.map(([label, content]) => `
    <div class="result-row"><span>${escapeHtml(label)}</span><span>${escapeHtml(content)}</span></div>
  `).join("") + `
    <div class="result-note"><strong>Base de cálculo:</strong> ${escapeHtml(calculation.explanation)}</div>
    <div class="result-note">Resultado preliminar para selección inicial. Para compra se debe validar contra presión diferencial, contrapresión, orificio interno, material, conexiones y tabla del fabricante.</div>
  `;
}

function setResultMessage(title, html) {
  elements.resultPanel.classList.remove("is-hidden");
  elements.resultTitle.textContent = title;
  elements.resultBody.innerHTML = `<div>${html}</div>`;
}

function createRules() {
  return [
    {
      name: "Tracing",
      condition: "Baja carga",
      trapType: "Termodinámica bimetálica",
      observations: "Selección directa para tracing de vapor. Puede permitir subenfriamiento.",
      requiresSizing: false,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [],
      calculate: () => ({ condensateKgH: 0, explanation: "Para tracing se selecciona directamente trampa termodinámica bimetálica." })
    },
    {
      name: "Serpentín de tanque",
      condition: "Transferencia de calor",
      trapType: "Flotador termostática",
      observations: "Buena para control estable.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        oilVolumeField(500),
        fieldSpec("initialTemperature", "Temperatura inicial", "°C", 0, 120, 1, 30),
        fieldSpec("finalTemperature", "Temperatura final", "°C", 20, 180, 1, 80),
        heatingTimeField(90),
        fieldSpec("steamPressure", "Presión de vapor de ingreso", "bar(g)", 1, 15, 0.5, 6)
      ],
      calculate: () => batchHeatingCalculation("serpentín de tanque")
    },
    {
      name: "Chaqueta o Marmita",
      condition: "Carga variable",
      trapType: "Flotador termostática",
      observations: "Importante eliminar aire y mantener control fino de temperatura.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        oilVolumeField(200),
        fieldSpec("initialTemperature", "Temperatura inicial", "°C", 0, 120, 1, 25),
        fieldSpec("finalTemperature", "Temperatura final", "°C", 20, 180, 1, 80),
        heatingTimeField(60),
        fieldSpec("steamPressure", "Presión de vapor de ingreso", "bar(g)", 1, 15, 0.5, 6)
      ],
      calculate: () => batchHeatingCalculation("chaqueta/marmita")
    },
    {
      name: "Chaqueta trabajo pesado",
      condition: "Drenaje",
      trapType: "Balde invertido",
      observations: "Ambientes sucios; priorizar confiabilidad.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        oilVolumeField(300),
        fieldSpec("initialTemperature", "Temperatura inicial", "°C", 0, 120, 1, 25),
        fieldSpec("finalTemperature", "Temperatura final", "°C", 20, 200, 1, 95),
        heatingTimeField(45),
        fieldSpec("steamPressure", "Presión de vapor de ingreso", "bar(g)", 1, 15, 0.5, 7)
      ],
      calculate: () => batchHeatingCalculation("chaqueta de trabajo pesado")
    },
    {
      name: "Distribuidor principal de caldero",
      condition: "Drenaje principal con posible arrastre",
      trapType: "Balde invertido",
      observations: "Crítico; validar carryover, instalar filtro y considerar separador si el vapor llega húmedo.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        fieldSpec("boilerWaterConsumption", "Agua consumida por caldero", "m³/h", 0, 60, 1, 19),
        fieldSpec("headerDiameter", "Diámetro del distribuidor", "pulg", 2, 24, 0.5, 6),
        fieldSpec("headerLength", "Largo del distribuidor", "m", 1, 30, 0.5, 6),
        fieldSpec("steamPressure", "Presión del distribuidor", "bar(g)", 1, 15, 0.5, 7)
      ],
      calculate: boilerHeaderCalculation
    },
    {
      name: "Distribuidor de vapor",
      condition: "Drenaje de distribución secundaria",
      trapType: "Balde invertido",
      observations: "Usar para distribuidores alejados del caldero; la producción total del caldero no representa necesariamente este ramal.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        fieldSpec("boilerPressure", "Presión del caldero", "bar(g)", 1, 15, 0.5, 8),
        fieldSpec("steamPressure", "Presión del distribuidor", "bar(g)", 1, 15, 0.5, 6),
        fieldSpec("headerDiameter", "Diámetro del distribuidor", "pulg", 1, 24, 0.5, 4),
        fieldSpec("headerLength", "Largo del distribuidor", "m", 1, 50, 0.5, 6)
      ],
      calculate: secondaryDistributorCalculation
    },
    {
      name: "Intercambiador de calor",
      condition: "Alta carga variable",
      trapType: "Flotador termostática",
      observations: "Revisar posible bloqueo por contrapresión.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        fieldSpec("processFlow", "Caudal de aceite o grasa", "m³/h", 1, 500, 1, 10),
        fieldSpec("initialTemperature", "Temperatura de entrada", "°C", 0, 140, 1, 30),
        fieldSpec("finalTemperature", "Temperatura de salida", "°C", 20, 180, 1, 85),
        fieldSpec("steamPressure", "Presión de vapor", "bar(g)", 1, 15, 0.5, 6)
      ],
      calculate: heatExchangerCalculation
    },
    {
      name: "Linea principal de vapor (Pierna de condensado)",
      condition: "Drenaje de línea",
      trapType: "Balde invertido",
      observations: "Colocar pierna colectora.",
      requiresSizing: true,
      safetyFactor: CONSTANTS.defaultSafetyFactor,
      fields: [
        fieldSpec("mainDiameter", "Diámetro de línea principal", "pulg", 1, 24, 0.5, 4),
        fieldSpec("mainLength", "Longitud entre drenajes", "m", 5, 200, 5, 30),
        fieldSpec("steamPressure", "Presión de vapor", "bar(g)", 1, 15, 0.5, 7)
      ],
      calculate: steamMainCalculation
    }
  ];
}

function batchHeatingCalculation(source) {
  const volume = value("processVolume");
  const initial = value("initialTemperature");
  const final = value("finalTemperature");
  const timeMin = value("heatingTime");
  const pressure = value("steamPressure");
  const deltaT = Math.max(0, final - initial);
  const productMassKg = volume * CONSTANTS.palmOilDensityKgL;
  const heatKj = productMassKg * CONSTANTS.palmOilSpecificHeatKjKgC * deltaT;
  const condensateKg = heatKj / latentHeat(pressure);
  const condensateKgH = condensateKg * (60 / Math.max(5, timeMin));
  return {
    condensateKgH: Math.max(condensateKgH, 5),
    explanation: `Estimación por calentamiento de aceite de palma en ${source}, usando volumen, temperaturas, tiempo, calor específico fijo de 2.0 kJ/kg °C y presión.`
  };
}

function boilerHeaderCalculation() {
  const waterConsumptionM3H = value("boilerWaterConsumption");
  const diameter = value("headerDiameter");
  const length = value("headerLength");
  const pressure = value("steamPressure");
  const surfaceCondensate = pipeSurfaceCondensateKgH(diameter, length, pressure);

  if (waterConsumptionM3H > 0) {
    const carryoverCondensate = waterConsumptionM3H * 1000 * (CONSTANTS.boilerHeaderCondensatePercent / 100);
    const condensate = Math.max(surfaceCondensate, carryoverCondensate);
    return {
      condensateKgH: Math.max(condensate, 8),
      explanation: `Estimación para distribuidor principal: agua consumida por caldero x factor interno de condensado/arrastre de ${oneDecimal.format(CONSTANTS.boilerHeaderCondensatePercent)}%. La pérdida térmica superficial del distribuidor se calcula como respaldo y se toma el mayor valor.`
    };
  }

  return {
    condensateKgH: Math.max(surfaceCondensate, 8),
    explanation: "Estimación por pérdida térmica de superficie externa del distribuidor principal, con ambiente interno asumido de 30 °C. No se aplicó factor de arrastre porque el consumo de agua quedó en cero."
  };
}

function secondaryDistributorCalculation() {
  const boilerPressure = value("boilerPressure");
  const distributorPressure = value("steamPressure");
  const diameter = value("headerDiameter");
  const length = value("headerLength");
  const surfaceCondensate = pipeSurfaceCondensateKgH(diameter, length, distributorPressure);
  const estimatedSteamCapacity = estimatedDistributorSteamCapacityKgH(diameter, distributorPressure);
  const fraction = pressureFraction(boilerPressure, distributorPressure);
  const runningDrainage = estimatedSteamCapacity * (CONSTANTS.secondaryDistributorDrainagePercent / 100) * fraction;
  const condensate = Math.max(surfaceCondensate, runningDrainage);

  return {
    condensateKgH: Math.max(condensate, 8),
    explanation: `Estimación para distribuidor secundario: se calcula una capacidad probable de vapor con diámetro, presión y velocidad interna de referencia de ${noDecimal.format(CONSTANTS.distributorDesignVelocityMS)} m/s; luego se toma ${oneDecimal.format(CONSTANTS.secondaryDistributorDrainagePercent)}% como drenaje típico de línea y se ajusta con una fracción interna por presión caldero/distribuidor. La pérdida térmica superficial se calcula como respaldo y se toma el mayor valor.`
  };
}

function heatExchangerCalculation() {
  const flowM3H = value("processFlow");
  const deltaT = Math.max(0, value("finalTemperature") - value("initialTemperature"));
  const pressure = value("steamPressure");
  const processKgH = flowM3H * 1000 * CONSTANTS.palmOilDensityKgL;
  const dutyKw = processKgH * CONSTANTS.palmOilSpecificHeatKjKgC * deltaT / 3600;
  const condensate = dutyKw * 3600 / latentHeat(pressure);
  return {
    condensateKgH: Math.max(condensate, 5),
    explanation: `Estimación por carga térmica del aceite o grasa, convirtiendo el caudal de ${oneDecimal.format(flowM3H)} m³/h a masa con densidad fija de 0.89 kg/L, calor específico fijo de 2.0 kJ/kg °C y calor latente del vapor.`
  };
}

function steamMainCalculation() {
  const diameter = value("mainDiameter");
  const length = value("mainLength");
  const pressure = value("steamPressure");
  const condensateKgH = pipeSurfaceCondensateKgH(diameter, length, pressure);
  return {
    condensateKgH: Math.max(condensateKgH, 8),
    explanation: "Estimación por pérdida térmica de operación en el tramo entre drenajes, con ambiente interno asumido de 30 °C."
  };
}

function fieldSpec(key, label, unit, min, max, step, defaultValue) {
  return { key, label, unit, min, max, step, defaultValue };
}

function oilVolumeField(defaultValue) {
  return {
    key: "processVolume",
    label: "Volumen de aceite o grasa",
    unit: "L",
    customValues: buildOilVolumeValues(),
    defaultValue
  };
}

function heatingTimeField(defaultValue) {
  const customValues = buildHeatingTimeValues();
  return {
    key: "heatingTime",
    label: "Tiempo de calentamiento",
    unit: "min / h",
    customValues,
    customLabels: buildHeatingTimeLabels(customValues),
    defaultValue
  };
}

function buildOilVolumeValues() {
  return [
    ...range(100, 1000, 100),
    ...range(1500, 10000, 500),
    ...range(15000, 50000, 5000),
    ...range(60000, 1000000, 10000)
  ];
}

function buildHeatingTimeValues() {
  return [
    ...range(5, 60, 5),
    ...range(90, 360, 30),
    ...range(420, 2880, 60)
  ];
}

function buildHeatingTimeLabels(values) {
  return values.map((minutes) => {
    if (minutes <= 60) {
      return `${noDecimal.format(minutes)} min`;
    }
    const hours = minutes / 60;
    const label = Math.abs(hours - Math.round(hours)) < 0.001 ? noDecimal.format(hours) : oneDecimal.format(hours);
    return `${label} h`;
  });
}

function range(min, max, step) {
  const values = [];
  for (let value = min; value <= max + 0.0001; value += step) {
    values.push(roundOne(value));
  }
  return values;
}

function formatPickerValue(value, step) {
  if (step < 1 || Math.abs(value - Math.round(value)) > 0.001) {
    return oneDecimal.format(value);
  }
  return noDecimal.format(value);
}

function roundOne(value) {
  return Math.round(value * 10) / 10;
}

function inchesToMeters(inches) {
  return inches * 0.0254;
}

function recommendTrapConnectionDiameter(requiredCapacityKgH) {
  if (requiredCapacityKgH <= 200) return "1/2 pulg (15 mm)";
  if (requiredCapacityKgH <= 500) return "3/4 pulg (20 mm)";
  if (requiredCapacityKgH <= 1000) return "1 pulg (25 mm)";
  if (requiredCapacityKgH <= 2000) return "1-1/4 pulg (32 mm)";
  if (requiredCapacityKgH <= 3000) return "1-1/2 pulg (40 mm)";
  if (requiredCapacityKgH <= 5000) return "2 pulg (50 mm)";
  return "2-1/2 a 4 pulg (65-100 mm) o trampas en paralelo";
}

function saturationTemperature(barGauge) {
  return interpolateSteamProperty(barGauge, CONSTANTS.steamTemperatureC);
}

function latentHeat(barGauge) {
  return interpolateSteamProperty(barGauge, CONSTANTS.steamLatentHeatKjKg);
}

function radiantHeatLossW(areaM2, steamPressureBarG, ambientTemperatureC) {
  const deltaT = Math.max(0, saturationTemperature(steamPressureBarG) - ambientTemperatureC);
  return areaM2 * CONSTANTS.freeConvectionUWm2C * deltaT;
}

function pipeSurfaceCondensateKgH(diameterInches, lengthMeters, pressureBarG) {
  const area = Math.PI * inchesToMeters(diameterInches) * lengthMeters;
  const heatLossW = radiantHeatLossW(area, pressureBarG, CONSTANTS.ambientTemperatureC);
  return heatLossW * 3.6 / latentHeat(pressureBarG);
}

function estimatedDistributorSteamCapacityKgH(diameterInches, pressureBarG) {
  const diameterMeters = inchesToMeters(diameterInches);
  const flowAreaM2 = Math.PI * diameterMeters * diameterMeters / 4;
  return flowAreaM2 * CONSTANTS.distributorDesignVelocityMS * saturatedSteamDensityKgM3(pressureBarG) * 3600;
}

function saturatedSteamDensityKgM3(pressureBarG) {
  const absolutePressurePa = (pressureBarG + CONSTANTS.atmosphericPressureBar) * 100000;
  const saturationTemperatureK = saturationTemperature(pressureBarG) + 273.15;
  return absolutePressurePa / (CONSTANTS.steamGasConstantJKgK * saturationTemperatureK);
}

function pressureFraction(boilerPressureBarG, distributorPressureBarG) {
  const boilerAbsolute = Math.max(CONSTANTS.atmosphericPressureBar, boilerPressureBarG + CONSTANTS.atmosphericPressureBar);
  const distributorAbsolute = Math.max(CONSTANTS.atmosphericPressureBar, distributorPressureBarG + CONSTANTS.atmosphericPressureBar);
  return clamp(distributorAbsolute / boilerAbsolute, 0.25, 1.0);
}

function interpolateSteamProperty(barGauge, values) {
  const pressures = CONSTANTS.steamPressureBarG;
  if (barGauge <= pressures[0]) return values[0];
  const last = pressures.length - 1;
  if (barGauge >= pressures[last]) return values[last];

  for (let index = 0; index < last; index += 1) {
    const lowPressure = pressures[index];
    const highPressure = pressures[index + 1];
    if (barGauge >= lowPressure && barGauge <= highPressure) {
      const fraction = (barGauge - lowPressure) / (highPressure - lowPressure);
      return values[index] + (values[index + 1] - values[index]) * fraction;
    }
  }
  return values[last];
}

function clamp(number, min, max) {
  return Math.max(min, Math.min(max, number));
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  }[character]));
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) {
    return;
  }
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
