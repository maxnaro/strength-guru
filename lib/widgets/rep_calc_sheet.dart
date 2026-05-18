import 'package:flutter/material.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';
import '../util/rep_calc.dart';

enum _CalcMode { estimate1rm, weightFromOneRm, repsFromWeight }

void showRepCalcSheet(BuildContext context) {
  showSGSheet<void>(context, child: const _RepCalcSheet());
}

class _RepCalcSheet extends StatefulWidget {
  const _RepCalcSheet();

  @override
  State<_RepCalcSheet> createState() => _RepCalcSheetState();
}

class _RepCalcSheetState extends State<_RepCalcSheet> {
  _CalcMode _mode = _CalcMode.estimate1rm;
  RepFormula _formula = RepFormula.epley;

  double _e1Weight = 60;
  int _e1Reps = 8;
  int _e1Rir = 1;

  double _w1rm = 100;
  int _wReps = 8;
  int _wRir = 1;

  double _r1rm = 100;
  double _rWeight = 80;

  double get _oneRmResult => estimate1Rm(_e1Weight, _e1Reps, _e1Rir, _formula);
  double get _weightResult =>
      roundToStep(weightForReps(_w1rm, _wReps, _wRir, _formula), 2.5);
  int get _repsResult => repsForWeight(_r1rm, _rWeight, _formula);

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text('Rep Calculator',
                style: SGText.display(18, color: p.text)),
          ),
          const SizedBox(height: 16),
          _SegToggle3(
            labels: const ['Est. 1RM', 'Weight', 'Reps'],
            selected: _mode.index,
            palette: p,
            onChanged: (i) => setState(() => _mode = _CalcMode.values[i]),
          ),
          const SizedBox(height: 20),
          _buildModeBody(p),
          const SizedBox(height: 20),
          _SegToggle2(
            labels: const ['Epley', 'Brzycki'],
            selected: _formula.index,
            palette: p,
            onChanged: (i) => setState(() => _formula = RepFormula.values[i]),
          ),
          const SizedBox(height: 20),
          _buildResult(p),
        ],
      ),
    );
  }

  Widget _buildModeBody(SGPalette p) {
    return switch (_mode) {
      _CalcMode.estimate1rm => Column(
          children: [
            SGStepper(
              value: _e1Weight,
              min: 0,
              max: 500,
              step: 2.5,
              label: 'WEIGHT (KG)',
              onChanged: (v) => setState(() => _e1Weight = v.toDouble()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SGStepper(
                  value: _e1Reps,
                  min: 1,
                  max: 50,
                  step: 1,
                  label: 'REPS',
                  onChanged: (v) => setState(() => _e1Reps = v.toInt()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SGStepper(
                  value: _e1Rir,
                  min: 0,
                  max: 10,
                  step: 1,
                  label: 'RIR',
                  onChanged: (v) => setState(() => _e1Rir = v.toInt()),
                ),
              ),
            ]),
          ],
        ),
      _CalcMode.weightFromOneRm => Column(
          children: [
            SGStepper(
              value: _w1rm,
              min: 0,
              max: 500,
              step: 2.5,
              label: '1RM (KG)',
              onChanged: (v) => setState(() => _w1rm = v.toDouble()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SGStepper(
                  value: _wReps,
                  min: 1,
                  max: 50,
                  step: 1,
                  label: 'TARGET REPS',
                  onChanged: (v) => setState(() => _wReps = v.toInt()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SGStepper(
                  value: _wRir,
                  min: 0,
                  max: 10,
                  step: 1,
                  label: 'TARGET RIR',
                  onChanged: (v) => setState(() => _wRir = v.toInt()),
                ),
              ),
            ]),
          ],
        ),
      _CalcMode.repsFromWeight => Row(
          children: [
            Expanded(
              child: SGStepper(
                value: _r1rm,
                min: 0,
                max: 500,
                step: 2.5,
                label: '1RM (KG)',
                onChanged: (v) => setState(() => _r1rm = v.toDouble()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SGStepper(
                value: _rWeight,
                min: 0,
                max: 500,
                step: 2.5,
                label: 'WEIGHT (KG)',
                onChanged: (v) => setState(() => _rWeight = v.toDouble()),
              ),
            ),
          ],
        ),
    };
  }

  Widget _buildResult(SGPalette p) {
    final (label, valueStr) = switch (_mode) {
      _CalcMode.estimate1rm => (
          'ESTIMATED 1RM',
          '${_oneRmResult.toStringAsFixed(1)} kg',
        ),
      _CalcMode.weightFromOneRm => (
          'SUGGESTED WEIGHT',
          '${_weightResult.toStringAsFixed(1)} kg',
        ),
      _CalcMode.repsFromWeight => (
          'ESTIMATED REPS',
          '$_repsResult reps',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(SGRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: SGText.mono(10, color: p.textFaint)),
          const SizedBox(height: 4),
          Text(valueStr, style: SGText.display(26, color: p.text)),
        ],
      ),
    );
  }
}

// ── Segment toggles ──────────────────────────────────────────────────────────

class _SegToggle3 extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final SGPalette palette;
  final ValueChanged<int> onChanged;

  const _SegToggle3({
    required this.labels,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(
          labels.length,
          (i) => Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected == i ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: SGText.body(13,
                        weight: FontWeight.w600,
                        color: selected == i ? palette.text : palette.textDim),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegToggle2 extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final SGPalette palette;
  final ValueChanged<int> onChanged;

  const _SegToggle2({
    required this.labels,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Formula', style: SGText.body(13, color: palette.textDim)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: palette.chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: List.generate(
                labels.length,
                (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected == i
                            ? palette.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: SGText.body(12,
                              weight: FontWeight.w600,
                              color: selected == i
                                  ? palette.text
                                  : palette.textDim),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
