import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../shared/neo_components.dart';
import 'savings_simulator.dart';

class SavingsSimulatorPage extends StatefulWidget {
  const SavingsSimulatorPage({super.key});

  @override
  State<SavingsSimulatorPage> createState() => _SavingsSimulatorPageState();
}

class _SavingsSimulatorPageState extends State<SavingsSimulatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _startingController = TextEditingController(text: '0');
  final _contributionController = TextEditingController(text: '50000');
  final _targetController = TextEditingController(text: '300000');
  final _monthsController = TextEditingController(text: '6');
  SavingFrequency _frequency = SavingFrequency.weekly;
  List<_Scenario> _scenarios = [];

  @override
  void dispose() {
    _startingController.dispose();
    _contributionController.dispose();
    _targetController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final starting = int.parse(_startingController.text);
    final contribution = int.parse(_contributionController.text);
    final target = int.parse(_targetController.text);
    final months = int.parse(_monthsController.text);
    setState(() {
      _scenarios = [
        _Scenario(
            'Hemat',
            (contribution * 75 ~/ 100).clamp(1, 999999999999).toInt(),
            NeoPalette.of(context).accent),
        _Scenario('Normal', contribution, NeoPalette.of(context).primary),
        _Scenario('Agresif', contribution * 125 ~/ 100,
            NeoPalette.of(context).secondary),
      ]
          .map((scenario) => scenario.copyWith(
              projection: simulateSavings(
                  startingBalance: starting,
                  contribution: scenario.contribution,
                  frequency: _frequency,
                  target: target,
                  months: months)))
          .toList();
    });
  }

  String _frequencyLabel(SavingFrequency frequency) => switch (frequency) {
        SavingFrequency.daily => 'Harian',
        SavingFrequency.weekly => 'Mingguan',
        SavingFrequency.monthly => 'Bulanan',
      };

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulasi tabungan')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
          children: [
            NeoCard(
                color: palette.highlight,
                child: const Text(
                    'Ini proyeksi aritmetika berdasarkan masukanmu, bukan janji hasil atau anjuran untuk mengurangi kebutuhan pokok.',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(height: 16),
            Form(
                key: _formKey,
                child: NeoCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Atur simulasi',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      _MoneyField(
                          controller: _startingController, label: 'Saldo awal'),
                      const SizedBox(height: 10),
                      _MoneyField(
                          controller: _contributionController,
                          label: 'Setoran per periode',
                          allowZero: false),
                      const SizedBox(height: 10),
                      _MoneyField(
                          controller: _targetController,
                          label: 'Target',
                          allowZero: false),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: DropdownButtonFormField<SavingFrequency>(
                                initialValue: _frequency,
                                decoration: const InputDecoration(
                                    labelText: 'Frekuensi'),
                                items: [
                                  for (final item in SavingFrequency.values)
                                    DropdownMenuItem(
                                        value: item,
                                        child: Text(_frequencyLabel(item)))
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _frequency = value);
                                  }
                                })),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _MoneyField(
                                controller: _monthsController,
                                label: 'Periode (bulan)',
                                allowZero: false,
                                maxLength: 3)),
                      ]),
                      const SizedBox(height: 13),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: _calculate,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text('Hitung simulasi'))),
                    ]))),
            if (_scenarios.isNotEmpty) ...[
              const SizedBox(height: 18),
              const NeoSectionTitle('SKENARIO SETORAN'),
              const SizedBox(height: 9),
              NeoCard(
                  child: Column(children: [
                SizedBox(
                    height: 210,
                    child: _ProjectionChart(
                        scenarios: _scenarios,
                        target: int.parse(_targetController.text))),
                const SizedBox(height: 9),
                for (final scenario in _scenarios)
                  _ScenarioSummary(
                      scenario: scenario,
                      frequencyLabel: _frequencyLabel(_frequency)),
              ])),
            ],
          ]),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField(
      {required this.controller,
      required this.label,
      this.allowZero = true,
      this.maxLength = 12});

  final TextEditingController controller;
  final String label;
  final bool allowZero;
  final int maxLength;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength)
        ],
        decoration: InputDecoration(
            labelText: label,
            prefixText: label == 'Periode (bulan)' ? null : 'Rp '),
        validator: (value) {
          final amount = int.tryParse(value ?? '');
          if (amount == null || (allowZero ? amount < 0 : amount <= 0)) {
            return allowZero
                ? 'Masukkan angka valid.'
                : 'Masukkan nilai lebih dari nol.';
          }
          if (label == 'Periode (bulan)' && amount > 120) {
            return 'Periode maksimal 120 bulan.';
          }
          return null;
        },
      );
}

class _Scenario {
  const _Scenario(this.name, this.contribution, this.color, {this.projection});

  final String name;
  final int contribution;
  final Color color;
  final SavingsProjection? projection;

  _Scenario copyWith({SavingsProjection? projection}) =>
      _Scenario(name, contribution, color,
          projection: projection ?? this.projection);
}

class _ProjectionChart extends StatelessWidget {
  const _ProjectionChart({required this.scenarios, required this.target});
  final List<_Scenario> scenarios;
  final int target;

  @override
  Widget build(BuildContext context) {
    final maxValue = scenarios
        .map((scenario) => scenario.projection!.endingBalance)
        .fold<int>(target, (a, b) => a > b ? a : b)
        .toDouble();
    return LineChart(LineChartData(
      minX: 0,
      maxX: scenarios.first.projection!.points.length - 1.0,
      minY: 0,
      maxY: maxValue == 0 ? 1 : maxValue * 1.08,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
            y: target.toDouble(),
            color: NeoPalette.of(context).border,
            strokeWidth: 2,
            dashArray: [5, 4])
      ]),
      lineBarsData: [
        for (final scenario in scenarios)
          LineChartBarData(
              spots: [
                for (var index = 0;
                    index < scenario.projection!.points.length;
                    index++)
                  FlSpot(index.toDouble(),
                      scenario.projection!.points[index].balance.toDouble())
              ],
              color: scenario.color,
              barWidth: 3,
              isCurved: false,
              dotData: const FlDotData(show: false))
      ],
    ));
  }
}

class _ScenarioSummary extends StatelessWidget {
  const _ScenarioSummary(
      {required this.scenario, required this.frequencyLabel});
  final _Scenario scenario;
  final String frequencyLabel;

  @override
  Widget build(BuildContext context) {
    final projection = scenario.projection!;
    final result = projection.reachedAt == null
        ? 'Belum tercapai dalam periode ini'
        : 'Perkiraan tercapai ${DateFormat('d MMM yyyy', 'id_ID').format(projection.reachedAt!)}';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 13,
              height: 13,
              margin: const EdgeInsets.only(top: 3, right: 8),
              decoration: BoxDecoration(
                  color: scenario.color,
                  border: Border.all(color: NeoPalette.of(context).border))),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(scenario.name,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                    '${formatRupiah(scenario.contribution)} $frequencyLabel · rencana setoran ${formatRupiah(projection.totalContributions)}',
                    style: const TextStyle(fontSize: 11)),
                Text('${formatRupiah(projection.endingBalance)} · $result',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800))
              ])),
        ]));
  }
}
