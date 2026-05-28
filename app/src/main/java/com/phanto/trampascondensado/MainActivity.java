package com.phanto.trampascondensado;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.NumberPicker;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;

import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends Activity {
    private static final int COLOR_PAGE = Color.rgb(245, 247, 248);
    private static final int COLOR_SURFACE = Color.WHITE;
    private static final int COLOR_PRIMARY = Color.rgb(47, 111, 115);
    private static final int COLOR_PRIMARY_DARK = Color.rgb(30, 72, 76);
    private static final int COLOR_TEXT = Color.rgb(32, 39, 43);
    private static final int COLOR_MUTED = Color.rgb(91, 105, 112);
    private static final int COLOR_BORDER = Color.rgb(218, 226, 229);
    private static final int COLOR_BRAND_RED = Color.rgb(227, 38, 58);
    private static final double PALM_OIL_SPECIFIC_HEAT_KJ_KG_C = 2.0;
    private static final double PALM_OIL_DENSITY_KG_L = 0.89;
    private static final double CONDENSATE_DENSITY_KG_L = 1.0;
    private static final double DEFAULT_SAFETY_FACTOR = 1.2;
    private static final double DEFAULT_AMBIENT_TEMPERATURE_C = 30.0;
    private static final double FREE_CONVECTION_U_W_M2_C = 11.36;
    private static final double BOILER_HEADER_CONDENSATE_PERCENT = 12.0;
    private static final double SECONDARY_DISTRIBUTOR_DRAINAGE_PERCENT = 1.0;
    private static final double DISTRIBUTOR_DESIGN_VELOCITY_M_S = 10.0;
    private static final double ATMOSPHERIC_PRESSURE_BAR = 1.01325;
    private static final double STEAM_GAS_CONSTANT_J_KG_K = 461.5;
    private static final double[] STEAM_PRESSURE_BAR_G = {
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    };
    private static final double[] STEAM_TEMPERATURE_C = {
            120.2, 133.5, 143.6, 151.8, 158.8, 165.0, 170.4, 175.4, 179.9, 184.1,
            188.0, 191.6, 195.0, 198.3, 201.4
    };
    private static final double[] STEAM_LATENT_HEAT_KJ_KG = {
            2201.6, 2163.2, 2133.4, 2108.0, 2085.8, 2066.3, 2048.8, 2032.9, 2014.6,
            2000.0, 1984.3, 1970.7, 1957.7, 1945.2, 1933.6
    };
    private static final DecimalFormat ONE_DECIMAL = new DecimalFormat("#,##0.0");
    private static final DecimalFormat NO_DECIMAL = new DecimalFormat("#,##0");

    private final Map<String, ApplicationRule> rules = new HashMap<>();
    private final Map<String, NumberPicker> pickers = new HashMap<>();
    private final Map<String, FieldSpec> currentFields = new HashMap<>();

    private LinearLayout contentLayout;
    private LinearLayout recommendationLayout;
    private LinearLayout directCondensateLayout;
    private LinearLayout fieldsLayout;
    private LinearLayout resultCardLayout;
    private TextView inputIntroView;
    private TextView trapTypeValue;
    private TextView conditionValue;
    private TextView notesValue;
    private TextView resultTitle;
    private TextView resultBody;
    private Spinner useSpinner;
    private CheckBox unknownCondensateCheckBox;
    private Button calculateButton;
    private ApplicationRule selectedRule;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        loadRules();
        showSplash();
        new Handler(Looper.getMainLooper()).postDelayed(this::showMainScreen, 1000);
    }

    private void showSplash() {
        getWindow().setStatusBarColor(Color.rgb(227, 38, 58));
        getWindow().setNavigationBarColor(Color.rgb(227, 38, 58));
        getWindow().getDecorView().setSystemUiVisibility(0);

        LinearLayout root = new LinearLayout(this);
        root.setGravity(Gravity.CENTER);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.rgb(227, 38, 58));
        root.setPadding(dp(28), dp(28), dp(28), dp(28));

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.splash_logo);
        logo.setAdjustViewBounds(true);
        logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
        root.addView(logo, new LinearLayout.LayoutParams(dp(88), dp(97)));

        setContentView(root);
    }

    private void showMainScreen() {
        getWindow().setStatusBarColor(COLOR_PAGE);
        getWindow().setNavigationBarColor(Color.WHITE);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);

        ScrollView scrollView = new ScrollView(this);
        scrollView.setBackgroundColor(COLOR_PAGE);
        scrollView.setFillViewport(true);

        contentLayout = new LinearLayout(this);
        contentLayout.setOrientation(LinearLayout.VERTICAL);
        contentLayout.setPadding(dp(18), dp(18), dp(18), dp(28));
        scrollView.addView(contentLayout);

        TextView title = new TextView(this);
        title.setText("Selección de trampa");
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(25);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        contentLayout.addView(title);

        TextView helper = new TextView(this);
        helper.setText("Escoge la aplicación. Si conoces el caudal de condensado, ese dato dimensiona la trampa; si no lo conoces, usa la estimación indirecta.");
        helper.setTextColor(COLOR_MUTED);
        helper.setTextSize(14);
        helper.setPadding(0, dp(8), 0, dp(18));
        contentLayout.addView(helper);

        addSectionLabel("Uso");
        useSpinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_dropdown_item,
                getRuleNames()
        );
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        useSpinner.setAdapter(adapter);
        contentLayout.addView(useSpinner, matchWrap());

        recommendationLayout = card();
        recommendationLayout.setPadding(dp(16), dp(14), dp(16), dp(14));
        trapTypeValue = addInfoLine(recommendationLayout, "Tipo de trampa", "");
        conditionValue = addInfoLine(recommendationLayout, "Condición típica", "");
        notesValue = addInfoLine(recommendationLayout, "Observaciones", "");
        addWithTopMargin(contentLayout, recommendationLayout, dp(14));

        inputIntroView = new TextView(this);
        inputIntroView.setText("Ingresa los valores con los que cuentes");
        inputIntroView.setTextColor(COLOR_TEXT);
        inputIntroView.setTextSize(18);
        inputIntroView.setTypeface(Typeface.DEFAULT_BOLD);
        inputIntroView.setPadding(0, dp(18), 0, dp(10));
        contentLayout.addView(inputIntroView);

        unknownCondensateCheckBox = new CheckBox(this);
        unknownCondensateCheckBox.setText("No conozco la cantidad de condensado");
        unknownCondensateCheckBox.setTextColor(COLOR_TEXT);
        unknownCondensateCheckBox.setButtonTintList(ColorStateList.valueOf(COLOR_BRAND_RED));
        unknownCondensateCheckBox.setTextSize(15);
        unknownCondensateCheckBox.setPadding(0, 0, 0, dp(8));
        unknownCondensateCheckBox.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                refreshInputFields();
                resultTitle.setText("Resultado");
                resultBody.setText("Completa los datos y presiona Calcular.");
            }
        });
        contentLayout.addView(unknownCondensateCheckBox, matchWrap());

        directCondensateLayout = new LinearLayout(this);
        directCondensateLayout.setOrientation(LinearLayout.VERTICAL);
        contentLayout.addView(directCondensateLayout);

        fieldsLayout = new LinearLayout(this);
        fieldsLayout.setOrientation(LinearLayout.VERTICAL);
        contentLayout.addView(fieldsLayout);

        calculateButton = new Button(this);
        calculateButton.setText("Calcular");
        calculateButton.setTextColor(Color.WHITE);
        calculateButton.setBackgroundColor(COLOR_BRAND_RED);
        calculateButton.setAllCaps(false);
        calculateButton.setTextSize(16);
        calculateButton.setOnClickListener(v -> calculate());
        addWithTopMargin(contentLayout, calculateButton, dp(16));

        resultCardLayout = card();
        resultCardLayout.setPadding(dp(16), dp(14), dp(16), dp(14));
        resultTitle = new TextView(this);
        resultTitle.setText("Resultado");
        resultTitle.setTextColor(COLOR_TEXT);
        resultTitle.setTextSize(18);
        resultTitle.setTypeface(Typeface.DEFAULT_BOLD);
        resultCardLayout.addView(resultTitle);

        resultBody = new TextView(this);
        resultBody.setText("Completa los datos y presiona Calcular.");
        resultBody.setTextColor(COLOR_MUTED);
        resultBody.setTextSize(14);
        resultBody.setPadding(0, dp(8), 0, 0);
        resultCardLayout.addView(resultBody);
        addWithTopMargin(contentLayout, resultCardLayout, dp(14));

        useSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                selectedRule = rules.get((String) parent.getItemAtPosition(position));
                refreshRule();
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        selectedRule = null;
        refreshRule();
        setContentView(scrollView);
    }

    private void refreshRule() {
        if (selectedRule == null) {
            setSelectionSectionsVisible(false);
            pickers.clear();
            currentFields.clear();
            if (directCondensateLayout != null) {
                directCondensateLayout.removeAllViews();
            }
            if (fieldsLayout != null) {
                fieldsLayout.removeAllViews();
            }
            return;
        }
        setSelectionSectionsVisible(true);
        trapTypeValue.setText(selectedRule.trapType);
        conditionValue.setText(selectedRule.condition);
        notesValue.setText(selectedRule.observations);
        resultBody.setText("Completa los datos y presiona Calcular.");

        pickers.clear();
        currentFields.clear();
        refreshInputFields();
    }

    private void setSelectionSectionsVisible(boolean visible) {
        int visibility = visible ? View.VISIBLE : View.GONE;
        if (recommendationLayout != null) {
            recommendationLayout.setVisibility(visibility);
        }
        if (inputIntroView != null) {
            inputIntroView.setVisibility(visibility);
        }
        if (unknownCondensateCheckBox != null) {
            unknownCondensateCheckBox.setVisibility(visibility);
        }
        if (directCondensateLayout != null) {
            directCondensateLayout.setVisibility(visibility);
        }
        if (fieldsLayout != null) {
            fieldsLayout.setVisibility(visibility);
        }
        if (calculateButton != null) {
            calculateButton.setVisibility(visibility);
        }
        if (resultCardLayout != null) {
            resultCardLayout.setVisibility(visibility);
        }
    }

    private void refreshInputFields() {
        if (selectedRule == null || directCondensateLayout == null || fieldsLayout == null) {
            return;
        }

        pickers.clear();
        currentFields.clear();
        directCondensateLayout.removeAllViews();
        fieldsLayout.removeAllViews();

        if (!selectedRule.requiresSizing) {
            inputIntroView.setVisibility(View.GONE);
            unknownCondensateCheckBox.setVisibility(View.GONE);
            directCondensateLayout.setVisibility(View.GONE);
            fieldsLayout.setVisibility(View.GONE);
            calculateButton.setVisibility(View.GONE);
            resultCardLayout.setVisibility(View.GONE);
            return;
        }

        inputIntroView.setVisibility(View.VISIBLE);
        unknownCondensateCheckBox.setVisibility(View.VISIBLE);
        calculateButton.setVisibility(View.VISIBLE);
        resultCardLayout.setVisibility(View.VISIBLE);

        boolean estimateIndirectly = unknownCondensateCheckBox != null && unknownCondensateCheckBox.isChecked();
        directCondensateLayout.setVisibility(estimateIndirectly ? View.GONE : View.VISIBLE);
        fieldsLayout.setVisibility(estimateIndirectly ? View.VISIBLE : View.GONE);

        if (estimateIndirectly) {
            for (FieldSpec field : selectedRule.fields) {
                addField(fieldsLayout, field);
            }
        } else {
            addField(directCondensateLayout, new FieldSpec("directCondensate", "Caudal de condensado a desalojar", "L/min", 0, 100, 1, 0));
        }
    }

    private void addField(LinearLayout parent, FieldSpec spec) {
        currentFields.put(spec.key, spec);
        LinearLayout container = card();
        container.setPadding(dp(14), dp(12), dp(14), dp(12));

        TextView label = new TextView(this);
        label.setText(spec.label + " (" + spec.unit + ")");
        label.setTextColor(COLOR_TEXT);
        label.setTextSize(15);
        label.setTypeface(Typeface.DEFAULT_BOLD);
        container.addView(label);

        NumberPicker picker = new NumberPicker(this);
        List<Double> values = buildValues(spec);
        String[] displayed = new String[values.size()];
        int defaultIndex = 0;
        for (int i = 0; i < values.size(); i++) {
            double value = values.get(i);
            displayed[i] = spec.customLabels != null ? spec.customLabels[i] : formatPickerValue(value, spec.step);
            if (Math.abs(value - spec.defaultValue) < 0.0001) {
                defaultIndex = i;
            }
        }
        picker.setMinValue(0);
        picker.setMaxValue(displayed.length - 1);
        picker.setDisplayedValues(displayed);
        picker.setWrapSelectorWheel(false);
        picker.setValue(defaultIndex);
        picker.setDescendantFocusability(NumberPicker.FOCUS_BLOCK_DESCENDANTS);
        container.addView(picker, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(104)
        ));

        TextView unit = new TextView(this);
        unit.setText("Selecciona con la rueda");
        unit.setTextColor(COLOR_MUTED);
        unit.setTextSize(12);
        unit.setGravity(Gravity.CENTER);
        container.addView(unit);

        pickers.put(spec.key, picker);
        addWithTopMargin(parent, container, dp(10));
    }

    private List<Double> buildValues(FieldSpec spec) {
        List<Double> values = new ArrayList<>();
        if (spec.customValues != null) {
            for (double customValue : spec.customValues) {
                values.add(customValue);
            }
            return values;
        }
        double value = spec.min;
        int guard = 0;
        while (value <= spec.max + 0.0001 && guard < 1000) {
            values.add(roundOne(value));
            value += spec.step;
            guard++;
        }
        return values;
    }

    private double value(String key) {
        FieldSpec spec = currentFields.get(key);
        NumberPicker picker = pickers.get(key);
        if (spec == null || picker == null) {
            return 0;
        }
        if (spec.customValues != null) {
            int index = Math.max(0, Math.min(picker.getValue(), spec.customValues.length - 1));
            return spec.customValues[index];
        }
        return spec.min + (picker.getValue() * spec.step);
    }

    private void calculate() {
        if (selectedRule == null) {
            return;
        }

        boolean estimateIndirectly = unknownCondensateCheckBox != null && unknownCondensateCheckBox.isChecked();
        Calculation calculation;
        if (estimateIndirectly) {
            calculation = selectedRule.calculator.calculate();
        } else {
            double directCondensateLMin = value("directCondensate");
            if (directCondensateLMin <= 0) {
                resultTitle.setText("Falta el caudal");
                resultBody.setText("Ingresa el caudal de condensado a desalojar o palomea \"No conozco la cantidad de condensado\" para estimarlo con otros parámetros.");
                return;
            }
            double directCondensateKgH = directCondensateLMin * CONDENSATE_DENSITY_KG_L * 60.0;
            calculation = new Calculation(directCondensateKgH, "Medición directa de " + ONE_DECIMAL.format(directCondensateLMin) + " L/min, convertida con densidad aproximada de condensado de 1.0 kg/L.");
        }

        double recommendedCapacity = calculation.condensateKgH * selectedRule.safetyFactor;
        String suggestedDiameter = recommendTrapConnectionDiameter(recommendedCapacity);
        double pressure = Math.max(0, value("steamPressure"));
        String pressureNote = pressure > 0
                ? "\nPresión de vapor considerada: " + ONE_DECIMAL.format(pressure) + " bar(g)."
                : "";

        String summary = "Uso: " + selectedRule.name
                + "\nTipo recomendado: " + selectedRule.trapType
                + "\nCarga estimada: " + NO_DECIMAL.format(calculation.condensateKgH) + " kg/h"
                + "\nEquivalente aproximado: " + NO_DECIMAL.format(calculation.condensateKgH / CONDENSATE_DENSITY_KG_L) + " L/h"
                + "\nFactor de seguridad: " + ONE_DECIMAL.format(selectedRule.safetyFactor)
                + "\nCapacidad mínima sugerida: " + NO_DECIMAL.format(recommendedCapacity) + " kg/h"
                + "\nDiámetro preliminar sugerido: " + suggestedDiameter
                + pressureNote
                + "\n\nBase de cálculo: " + calculation.explanation
                + "\n\nNota: resultado preliminar para selección inicial. Para compra se debe validar contra presión diferencial, contrapresión, orificio interno, material, conexiones y tabla del fabricante.";

        resultTitle.setText("Resumen de trampa requerida");
        resultBody.setText(summary);
    }

    private void loadRules() {
        addRule(new ApplicationRule(
                "Tracing",
                "Baja carga",
                "Termodinámica bimetálica",
                "Selección directa para tracing de vapor. Puede permitir subenfriamiento.",
                false,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{},
                () -> {
                    return new Calculation(0, "Para tracing se selecciona directamente trampa termodinámica bimetálica.");
                }
        ));

        addRule(new ApplicationRule(
                "Serpentín de tanque",
                "Transferencia de calor",
                "Flotador termostática",
                "Buena para control estable.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        oilVolumeField(500),
                        new FieldSpec("initialTemperature", "Temperatura inicial", "°C", 0, 120, 1, 30),
                        new FieldSpec("finalTemperature", "Temperatura final", "°C", 20, 180, 1, 80),
                        heatingTimeField(90),
                        new FieldSpec("steamPressure", "Presión de vapor de ingreso", "bar(g)", 1, 15, 0.5, 6)
                },
                () -> batchHeatingCalculation("serpentín de tanque")
        ));

        addRule(new ApplicationRule(
                "Chaqueta o Marmita",
                "Carga variable",
                "Flotador termostática",
                "Importante eliminar aire y mantener control fino de temperatura.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        oilVolumeField(200),
                        new FieldSpec("initialTemperature", "Temperatura inicial", "°C", 0, 120, 1, 25),
                        new FieldSpec("finalTemperature", "Temperatura final", "°C", 20, 180, 1, 80),
                        heatingTimeField(60),
                        new FieldSpec("steamPressure", "Presión de vapor de ingreso", "bar(g)", 1, 15, 0.5, 6)
                },
                () -> batchHeatingCalculation("chaqueta/marmita")
        ));

        addRule(new ApplicationRule(
                "Chaqueta trabajo pesado",
                "Drenaje",
                "Balde invertido",
                "Ambientes sucios; priorizar confiabilidad.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        oilVolumeField(300),
                        new FieldSpec("initialTemperature", "Temperatura inicial", "°C", 0, 120, 1, 25),
                        new FieldSpec("finalTemperature", "Temperatura final", "°C", 20, 200, 1, 95),
                        heatingTimeField(45),
                        new FieldSpec("steamPressure", "Presión de vapor de ingreso", "bar(g)", 1, 15, 0.5, 7)
                },
                () -> batchHeatingCalculation("chaqueta de trabajo pesado")
        ));

        addRule(new ApplicationRule(
                "Distribuidor principal de caldero",
                "Drenaje principal con posible arrastre",
                "Balde invertido",
                "Crítico; validar carryover, instalar filtro y considerar separador si el vapor llega húmedo.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        new FieldSpec("boilerWaterConsumption", "Agua consumida por caldero", "m³/h", 0, 60, 1, 19),
                        new FieldSpec("headerDiameter", "Diámetro del distribuidor", "pulg", 2, 24, 0.5, 6),
                        new FieldSpec("headerLength", "Largo del distribuidor", "m", 1, 30, 0.5, 6),
                        new FieldSpec("steamPressure", "Presión del distribuidor", "bar(g)", 1, 15, 0.5, 7)
                },
                () -> {
                    double waterConsumptionM3H = value("boilerWaterConsumption");
                    double diameter = value("headerDiameter");
                    double length = value("headerLength");
                    double pressure = value("steamPressure");
                    double surfaceCondensate = pipeSurfaceCondensateKgH(diameter, length, pressure);
                    if (waterConsumptionM3H > 0) {
                        double carryoverCondensate = waterConsumptionM3H * 1000.0 * (BOILER_HEADER_CONDENSATE_PERCENT / 100.0);
                        double condensate = Math.max(surfaceCondensate, carryoverCondensate);
                        return new Calculation(Math.max(condensate, 8), "Estimación para distribuidor principal: agua consumida por caldero x factor interno de condensado/arrastre de "
                                + ONE_DECIMAL.format(BOILER_HEADER_CONDENSATE_PERCENT)
                                + "%. La pérdida térmica superficial del distribuidor se calcula como respaldo y se toma el mayor valor.");
                    }
                    return new Calculation(Math.max(surfaceCondensate, 8), "Estimación por pérdida térmica de superficie externa del distribuidor principal, con ambiente interno asumido de 30 °C. No se aplicó factor de arrastre porque el consumo de agua quedó en cero.");
                }
        ));

        addRule(new ApplicationRule(
                "Distribuidor de vapor",
                "Drenaje de distribución secundaria",
                "Balde invertido",
                "Usar para distribuidores alejados del caldero; la producción total del caldero no representa necesariamente este ramal.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        new FieldSpec("boilerPressure", "Presión del caldero", "bar(g)", 1, 15, 0.5, 8),
                        new FieldSpec("steamPressure", "Presión del distribuidor", "bar(g)", 1, 15, 0.5, 6),
                        new FieldSpec("headerDiameter", "Diámetro del distribuidor", "pulg", 1, 24, 0.5, 4),
                        new FieldSpec("headerLength", "Largo del distribuidor", "m", 1, 50, 0.5, 6)
                },
                () -> {
                    double boilerPressure = value("boilerPressure");
                    double distributorPressure = value("steamPressure");
                    double diameter = value("headerDiameter");
                    double length = value("headerLength");
                    double surfaceCondensate = pipeSurfaceCondensateKgH(diameter, length, distributorPressure);
                    double estimatedSteamCapacity = estimatedDistributorSteamCapacityKgH(diameter, distributorPressure);
                    double pressureFraction = pressureFraction(boilerPressure, distributorPressure);
                    double runningDrainage = estimatedSteamCapacity
                            * (SECONDARY_DISTRIBUTOR_DRAINAGE_PERCENT / 100.0)
                            * pressureFraction;
                    double condensate = Math.max(surfaceCondensate, runningDrainage);
                    return new Calculation(Math.max(condensate, 8), "Estimación para distribuidor secundario: se calcula una capacidad probable de vapor con diámetro, presión y velocidad interna de referencia de "
                            + NO_DECIMAL.format(DISTRIBUTOR_DESIGN_VELOCITY_M_S)
                            + " m/s; luego se toma "
                            + ONE_DECIMAL.format(SECONDARY_DISTRIBUTOR_DRAINAGE_PERCENT)
                            + "% como drenaje típico de línea y se ajusta con una fracción interna por presión caldero/distribuidor. La pérdida térmica superficial se calcula como respaldo y se toma el mayor valor. Si luego se conoce el caudal real del ramal, ese dato debe reemplazar esta estimación.");
                }
        ));

        addRule(new ApplicationRule(
                "Intercambiador de calor",
                "Alta carga variable",
                "Flotador termostática",
                "Revisar posible bloqueo por contrapresión.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        new FieldSpec("processFlow", "Caudal de aceite o grasa", "m³/h", 1, 500, 1, 10),
                        new FieldSpec("initialTemperature", "Temperatura de entrada", "°C", 0, 140, 1, 30),
                        new FieldSpec("finalTemperature", "Temperatura de salida", "°C", 20, 180, 1, 85),
                        new FieldSpec("steamPressure", "Presión de vapor", "bar(g)", 1, 15, 0.5, 6)
                },
                () -> {
                    double flowM3H = value("processFlow");
                    double deltaT = Math.max(0, value("finalTemperature") - value("initialTemperature"));
                    double cp = PALM_OIL_SPECIFIC_HEAT_KJ_KG_C;
                    double pressure = value("steamPressure");
                    double processKgH = flowM3H * 1000.0 * PALM_OIL_DENSITY_KG_L;
                    double dutyKw = processKgH * cp * deltaT / 3600.0;
                    double condensate = dutyKw * 3600.0 / latentHeat(pressure);
                    return new Calculation(Math.max(condensate, 5), "Estimación por carga térmica del aceite o grasa, convirtiendo el caudal de "
                            + ONE_DECIMAL.format(flowM3H)
                            + " m³/h a masa con densidad fija de 0.89 kg/L, calor específico fijo de 2.0 kJ/kg °C y calor latente del vapor.");
                }
        ));

        addRule(new ApplicationRule(
                "Linea principal de vapor (Pierna de condensado)",
                "Drenaje de línea",
                "Balde invertido",
                "Colocar pierna colectora.",
                true,
                DEFAULT_SAFETY_FACTOR,
                new FieldSpec[]{
                        new FieldSpec("mainDiameter", "Diámetro de línea principal", "pulg", 1, 24, 0.5, 4),
                        new FieldSpec("mainLength", "Longitud entre drenajes", "m", 5, 200, 5, 30),
                        new FieldSpec("steamPressure", "Presión de vapor", "bar(g)", 1, 15, 0.5, 7)
                },
                () -> {
                    double diameter = value("mainDiameter");
                    double length = value("mainLength");
                    double pressure = value("steamPressure");
                    double area = Math.PI * inchesToMeters(diameter) * length;
                    double heatLossW = radiantHeatLossW(area, pressure, DEFAULT_AMBIENT_TEMPERATURE_C);
                    double condensateKgH = heatLossW * 3.6 / latentHeat(pressure);
                    return new Calculation(Math.max(condensateKgH, 8), "Estimación por pérdida térmica de operación en el tramo entre drenajes, con ambiente interno asumido de 30 °C.");
                }
        ));
    }

    private Calculation batchHeatingCalculation(String source) {
        double volume = value("processVolume");
        double initial = value("initialTemperature");
        double fin = value("finalTemperature");
        double timeMin = value("heatingTime");
        double cp = PALM_OIL_SPECIFIC_HEAT_KJ_KG_C;
        double pressure = value("steamPressure");
        double deltaT = Math.max(0, fin - initial);
        double productMassKg = volume * PALM_OIL_DENSITY_KG_L;
        double heatKj = productMassKg * cp * deltaT;
        double condensateKg = heatKj / latentHeat(pressure);
        double condensateKgH = condensateKg * (60.0 / Math.max(5, timeMin));
        return new Calculation(Math.max(condensateKgH, 5), "Estimación por calentamiento de aceite de palma en " + source + ", usando volumen, temperaturas, tiempo, calor específico fijo de 2.0 kJ/kg °C y presión.");
    }

    private void addRule(ApplicationRule rule) {
        rules.put(rule.name, rule);
    }

    private FieldSpec oilVolumeField(double defaultValue) {
        return new FieldSpec("processVolume", "Volumen de aceite o grasa", "L", buildOilVolumeValues(), defaultValue);
    }

    private FieldSpec heatingTimeField(double defaultValueMinutes) {
        double[] values = buildHeatingTimeValues();
        String[] labels = buildHeatingTimeLabels(values);
        return new FieldSpec("heatingTime", "Tiempo de calentamiento", "min / h", values, labels, defaultValueMinutes);
    }

    private double[] buildHeatingTimeValues() {
        List<Double> values = new ArrayList<>();
        for (double value = 5; value <= 60; value += 5) {
            values.add(value);
        }
        for (double value = 90; value <= 360; value += 30) {
            values.add(value);
        }
        for (double value = 420; value <= 2880; value += 60) {
            values.add(value);
        }

        double[] customValues = new double[values.size()];
        for (int i = 0; i < values.size(); i++) {
            customValues[i] = values.get(i);
        }
        return customValues;
    }

    private String[] buildHeatingTimeLabels(double[] values) {
        String[] labels = new String[values.length];
        for (int i = 0; i < values.length; i++) {
            double minutes = values[i];
            if (minutes <= 60) {
                labels[i] = NO_DECIMAL.format(minutes) + " min";
            } else {
                double hours = minutes / 60.0;
                labels[i] = (Math.abs(hours - Math.round(hours)) < 0.001
                        ? NO_DECIMAL.format(hours)
                        : ONE_DECIMAL.format(hours)) + " h";
            }
        }
        return labels;
    }

    private double[] buildOilVolumeValues() {
        List<Double> values = new ArrayList<>();
        for (double value = 100; value <= 1000; value += 100) {
            values.add(value);
        }
        for (double value = 1500; value <= 10000; value += 500) {
            values.add(value);
        }
        for (double value = 15000; value <= 50000; value += 5000) {
            values.add(value);
        }
        for (double value = 60000; value <= 1000000; value += 10000) {
            values.add(value);
        }

        double[] customValues = new double[values.size()];
        for (int i = 0; i < values.size(); i++) {
            customValues[i] = values.get(i);
        }
        return customValues;
    }

    private List<String> getRuleNames() {
        List<String> names = new ArrayList<>();
        names.add("Selecciona un uso");
        names.add("Tracing");
        names.add("Serpentín de tanque");
        names.add("Chaqueta o Marmita");
        names.add("Chaqueta trabajo pesado");
        names.add("Distribuidor principal de caldero");
        names.add("Distribuidor de vapor");
        names.add("Intercambiador de calor");
        names.add("Linea principal de vapor (Pierna de condensado)");
        return names;
    }

    private TextView addInfoLine(LinearLayout parent, String label, String value) {
        TextView labelView = new TextView(this);
        labelView.setText(label);
        labelView.setTextColor(COLOR_MUTED);
        labelView.setTextSize(12);
        labelView.setTypeface(Typeface.DEFAULT_BOLD);
        parent.addView(labelView);

        TextView valueView = new TextView(this);
        valueView.setText(value);
        valueView.setTextColor(COLOR_TEXT);
        valueView.setTextSize(15);
        valueView.setPadding(0, dp(2), 0, dp(10));
        parent.addView(valueView);
        return valueView;
    }

    private void addSectionLabel(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(COLOR_TEXT);
        view.setTextSize(14);
        view.setTypeface(Typeface.DEFAULT_BOLD);
        view.setPadding(0, 0, 0, dp(6));
        contentLayout.addView(view);
    }

    private LinearLayout card() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setBackground(new android.graphics.drawable.GradientDrawable() {{
            setColor(COLOR_SURFACE);
            setCornerRadius(dp(8));
            setStroke(dp(1), COLOR_BORDER);
        }});
        return layout;
    }

    private void addWithTopMargin(LinearLayout parent, View view, int topMargin) {
        LinearLayout.LayoutParams params = matchWrap();
        params.topMargin = topMargin;
        parent.addView(view, params);
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String formatPickerValue(double value, double step) {
        if (step < 1 || Math.abs(value - Math.round(value)) > 0.001) {
            return ONE_DECIMAL.format(value);
        }
        return NO_DECIMAL.format(value);
    }

    private double roundOne(double value) {
        return Math.round(value * 10.0) / 10.0;
    }

    private double inchesToMeters(double inches) {
        return inches * 0.0254;
    }

    private String recommendTrapConnectionDiameter(double requiredCapacityKgH) {
        if (requiredCapacityKgH <= 200) {
            return "1/2 pulg (15 mm)";
        }
        if (requiredCapacityKgH <= 500) {
            return "3/4 pulg (20 mm)";
        }
        if (requiredCapacityKgH <= 1000) {
            return "1 pulg (25 mm)";
        }
        if (requiredCapacityKgH <= 2000) {
            return "1-1/4 pulg (32 mm)";
        }
        if (requiredCapacityKgH <= 3000) {
            return "1-1/2 pulg (40 mm)";
        }
        if (requiredCapacityKgH <= 5000) {
            return "2 pulg (50 mm)";
        }
        return "2-1/2 a 4 pulg (65-100 mm) o trampas en paralelo";
    }

    private double saturationTemperature(double barGauge) {
        return interpolateSteamProperty(barGauge, STEAM_TEMPERATURE_C);
    }

    private double latentHeat(double barGauge) {
        return interpolateSteamProperty(barGauge, STEAM_LATENT_HEAT_KJ_KG);
    }

    private double radiantHeatLossW(double areaM2, double steamPressureBarG, double ambientTemperatureC) {
        double deltaT = Math.max(0, saturationTemperature(steamPressureBarG) - ambientTemperatureC);
        return areaM2 * FREE_CONVECTION_U_W_M2_C * deltaT;
    }

    private double pipeSurfaceCondensateKgH(double diameterInches, double lengthMeters, double pressureBarG) {
        double area = Math.PI * inchesToMeters(diameterInches) * lengthMeters;
        double heatLossW = radiantHeatLossW(area, pressureBarG, DEFAULT_AMBIENT_TEMPERATURE_C);
        return heatLossW * 3.6 / latentHeat(pressureBarG);
    }

    private double estimatedDistributorSteamCapacityKgH(double diameterInches, double pressureBarG) {
        double diameterMeters = inchesToMeters(diameterInches);
        double flowAreaM2 = Math.PI * diameterMeters * diameterMeters / 4.0;
        return flowAreaM2 * DISTRIBUTOR_DESIGN_VELOCITY_M_S * saturatedSteamDensityKgM3(pressureBarG) * 3600.0;
    }

    private double saturatedSteamDensityKgM3(double pressureBarG) {
        double absolutePressurePa = (pressureBarG + ATMOSPHERIC_PRESSURE_BAR) * 100000.0;
        double saturationTemperatureK = saturationTemperature(pressureBarG) + 273.15;
        return absolutePressurePa / (STEAM_GAS_CONSTANT_J_KG_K * saturationTemperatureK);
    }

    private double pressureFraction(double boilerPressureBarG, double distributorPressureBarG) {
        double boilerAbsolute = Math.max(ATMOSPHERIC_PRESSURE_BAR, boilerPressureBarG + ATMOSPHERIC_PRESSURE_BAR);
        double distributorAbsolute = Math.max(ATMOSPHERIC_PRESSURE_BAR, distributorPressureBarG + ATMOSPHERIC_PRESSURE_BAR);
        return clamp(distributorAbsolute / boilerAbsolute, 0.25, 1.0);
    }

    private double interpolateSteamProperty(double barGauge, double[] values) {
        if (barGauge <= STEAM_PRESSURE_BAR_G[0]) {
            return values[0];
        }
        int last = STEAM_PRESSURE_BAR_G.length - 1;
        if (barGauge >= STEAM_PRESSURE_BAR_G[last]) {
            return values[last];
        }
        for (int i = 0; i < last; i++) {
            double lowPressure = STEAM_PRESSURE_BAR_G[i];
            double highPressure = STEAM_PRESSURE_BAR_G[i + 1];
            if (barGauge >= lowPressure && barGauge <= highPressure) {
                double fraction = (barGauge - lowPressure) / (highPressure - lowPressure);
                return values[i] + (values[i + 1] - values[i]) * fraction;
            }
        }
        return values[last];
    }

    private double clamp(double value, double min, double max) {
        return Math.max(min, Math.min(max, value));
    }

    private interface Calculator {
        Calculation calculate();
    }

    private static class ApplicationRule {
        final String name;
        final String condition;
        final String trapType;
        final String observations;
        final boolean requiresSizing;
        final double safetyFactor;
        final FieldSpec[] fields;
        final Calculator calculator;

        ApplicationRule(String name, String condition, String trapType, String observations,
                        boolean requiresSizing, double safetyFactor, FieldSpec[] fields, Calculator calculator) {
            this.name = name;
            this.condition = condition;
            this.trapType = trapType;
            this.observations = observations;
            this.requiresSizing = requiresSizing;
            this.safetyFactor = safetyFactor;
            this.fields = fields;
            this.calculator = calculator;
        }
    }

    private static class FieldSpec {
        final String key;
        final String label;
        final String unit;
        final double min;
        final double max;
        final double step;
        final double defaultValue;
        final double[] customValues;
        final String[] customLabels;

        FieldSpec(String key, String label, String unit, double min, double max, double step, double defaultValue) {
            this.key = key;
            this.label = label;
            this.unit = unit;
            this.min = min;
            this.max = max;
            this.step = step;
            this.defaultValue = defaultValue;
            this.customValues = null;
            this.customLabels = null;
        }

        FieldSpec(String key, String label, String unit, double[] customValues, double defaultValue) {
            this(key, label, unit, customValues, null, defaultValue);
        }

        FieldSpec(String key, String label, String unit, double[] customValues, String[] customLabels, double defaultValue) {
            this.key = key;
            this.label = label;
            this.unit = unit;
            this.min = customValues.length > 0 ? customValues[0] : 0;
            this.max = customValues.length > 0 ? customValues[customValues.length - 1] : 0;
            this.step = 1;
            this.defaultValue = defaultValue;
            this.customValues = customValues;
            this.customLabels = customLabels;
        }
    }

    private static class Calculation {
        final double condensateKgH;
        final String explanation;

        Calculation(double condensateKgH, String explanation) {
            this.condensateKgH = condensateKgH;
            this.explanation = explanation;
        }
    }
}
