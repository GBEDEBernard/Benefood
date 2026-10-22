import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../restaurant_palette.dart';

/// Ouvre la feuille de sélection d'heure (français, 24 h, molettes).
Future<String?> showTimePickerSheet({
  required BuildContext context,
  required String title,
  required String initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent, // On gère le fond nous-mêmes
    isScrollControlled: true,
    isDismissible: true, // Permet de fermer en cliquant à côté
    enableDrag: true, // Permet de fermer en glissant vers le bas
    builder: (_) => _TimePickerSheet(title: title, initial: initial),
  );
}

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  static const List<String> _presets = ['06:00', '08:00', '12:00', '14:00', '18:00', '22:00'];

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final parts = widget.initial.split(':');
    _hour = int.tryParse(parts.first) ?? 8;
    _minute = parts.length > 1 ? int.tryParse(parts.last) ?? 0 : 0;
    _hour = _hour.clamp(0, 23);
    _minute = _minute.clamp(0, 59);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String get _value => '${_pad(_hour)}:${_pad(_minute)}';

  static String _pad(int v) => v.toString().padLeft(2, '0');

  void _applyPreset(String preset) {
    final parts = preset.split(':');
    setState(() {
      _hour = int.parse(parts.first);
      _minute = int.parse(parts.last);
    });
    _hourController.animateToItem(_hour, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    _minuteController.animateToItem(_minute, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    
    // 🎨 LE FOND BLANC ET LES BORDS ARRONDIS SONT ICI
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              _SheetHeader(title: widget.title),
              const SizedBox(height: 20),
              _TimeWheelGroup(
                hourController: _hourController,
                minuteController: _minuteController,
                onHourChanged: (hour) => setState(() => _hour = hour),
                onMinuteChanged: (minute) => setState(() => _minute = minute),
              ),
              const SizedBox(height: 20),
              _PresetChips(
                presets: _presets,
                onPreset: _applyPreset,
              ),
              const SizedBox(height: 24),
              _SheetActions(value: _value),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: RestaurantPalette.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.schedule, size: 20, color: RestaurantPalette.orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // Ajout d'un bouton fermer en haut à droite
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.grey, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }
}

class _TimeWheelGroup extends StatelessWidget {
  const _TimeWheelGroup({
    required this.hourController,
    required this.minuteController,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  static String _padSmall(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _WheelBackground(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _Wheel(
                    controller: hourController,
                    count: 24,
                    label: _padSmall,
                    onSelected: onHourChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'h',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Wheel(
                    controller: minuteController,
                    count: 60,
                    label: _padSmall,
                    onSelected: onMinuteChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: RestaurantPalette.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RestaurantPalette.orange.withOpacity(0.2), width: 1.5),
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.label,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int) label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      onSelectedItemChanged: onSelected,
      itemExtent: 48,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.6,
      useMagnifier: true,
      magnification: 1.15,
      overAndUnderCenterOpacity: 0.3,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          if (index < 0 || index >= count) {
            return null;
          }
          return Center(
            child: Text(
              label(index),
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PresetChips extends StatelessWidget {
  const _PresetChips({required this.presets, required this.onPreset});

  final List<String> presets;
  final void Function(String) onPreset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final preset in presets) _PresetChip(label: preset, onTap: () => onPreset(preset)),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50, // Fond gris très clair
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: RestaurantPalette.darkText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              // 🛠️ CORRECTION : Rendre le bouton Annuler bien visible
              foregroundColor: Colors.black87, 
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: RestaurantPalette.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}