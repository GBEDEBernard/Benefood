import 'package:flutter/material.dart';

import '../restaurant_palette.dart';

/// Ouvre la feuille de sélection d'heure (français, 24 h, molettes) et
/// renvoie l'heure choisie au format « HH:mm » ou `null` si annulé.
Future<String?> showTimePickerSheet({
  required BuildContext context,
  required String title,
  required String initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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

  String get _value =>
      '${_pad(_hourController.selectedItem.clamp(0, 23))}:${_pad(_minuteController.selectedItem.clamp(0, 59))}';

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
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: RestaurantPalette.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: RestaurantPalette.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule, size: 19, color: RestaurantPalette.orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 176,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: RestaurantPalette.orange.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RestaurantPalette.orange.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _wheel(
                          controller: _hourController,
                          count: 24,
                          label: _pad,
                        ),
                      ),
                      const Text(
                        'h',
                        style: TextStyle(
                          color: RestaurantPalette.grayText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: _wheel(
                          controller: _minuteController,
                          count: 60,
                          label: _pad,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final preset in _presets) _PresetChip(label: preset, onTap: () => _applyPreset(preset)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RestaurantPalette.grayText,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_value),
                  style: FilledButton.styleFrom(
                    backgroundColor: RestaurantPalette.orange,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) label,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 46,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.7,
      useMagnifier: true,
      magnification: 1.12,
      overAndUnderCenterOpacity: 0.35,
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
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: RestaurantPalette.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
