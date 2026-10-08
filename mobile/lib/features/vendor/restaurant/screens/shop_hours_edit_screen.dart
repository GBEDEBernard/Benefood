import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../restaurant_palette.dart';
import 'shop_edit_shell.dart';

const List<String> _dayNames = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// Slots modifiables de la planification hebdomadaire (lundi = 0).
class _DaySlot {
  _DaySlot({required this.dayOfWeek, this.opensAt, this.closesAt, this.isClosed = false});

  final int dayOfWeek;
  String? opensAt;
  String? closesAt;
  bool isClosed;
}

/// Édition des horaires d'ouverture : 7 jours, boutique ouverte/fermée par
/// jour, création/fermeture à la minute.
class ShopHoursEditScreen extends StatefulWidget {
  const ShopHoursEditScreen({super.key, required this.hours, this.marketplace});

  final List<OpeningHour> hours;
  final MarketplaceApi? marketplace;

  @override
  State<ShopHoursEditScreen> createState() => _ShopHoursEditScreenState();
}

class _ShopHoursEditScreenState extends State<ShopHoursEditScreen> {
  late final List<_DaySlot> _slots;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _slots = List.generate(7, (day) {
      OpeningHour? existing;
      for (final h in widget.hours) {
        if (h.dayOfWeek == day) {
          existing = h;
          break;
        }
      }
      return _DaySlot(
        dayOfWeek: day,
        opensAt: existing?.opensAt ?? '08:00',
        closesAt: existing?.closesAt ?? '22:00',
        isClosed: existing?.isClosed ?? false,
      );
    });
  }

  Future<void> _pickTime(int day, {required bool isOpen}) async {
    final slot = _slots[day];
    final current = (isOpen ? slot.opensAt : slot.closesAt) ?? (isOpen ? '08:00' : '22:00');
    final initial = TimeOfDay(hour: int.parse(current.split(':').first), minute: int.parse(current.split(':').last));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: _dayNames[day],
      builder: (context, child) => child!,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isOpen) {
        slot.opensAt = value;
      } else {
        slot.closesAt = value;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final hours = _slots.map((slot) {
        final open = !slot.isClosed;
        return OpeningHour(
          dayOfWeek: slot.dayOfWeek,
          opensAt: open ? slot.opensAt : null,
          closesAt: open ? slot.closesAt : null,
          isClosed: !open,
        );
      }).toList();

      final api = widget.marketplace;
      if (api != null) {
        await api.updateVendorShop(hours: hours);
      } else {
        showToast(context, 'Aperçu démo — lancez le serveur pour enregistrer.');
      }
      if (mounted) {
        showToast(context, 'Horaires enregistrés.');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.fieldErrors.isNotEmpty) {
          showToast(context, e.fieldErrors.values.first.first, isError: true);
        } else {
          showToast(context, e.message, isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RestaurantPalette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ShopEditorAppBar(title: 'Horaires', onSave: _save, saving: _saving),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const ShopEditLabel(
                    'Horaires d’ouverture',
                    helper: 'Heure locale — les clients voient vos horaires sur la fiche boutique.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: RestaurantPalette.cardDecoration,
                    child: Column(
                      children: [
                        for (var i = 0; i < _slots.length; i++) ...[
                          if (i > 0) const _DayDivider(),
                          _DayRow(
                            name: _dayNames[i],
                            slot: _slots[i],
                            onToggleClosed: (closed) => setState(() => _slots[i].isClosed = closed),
                            onPickOpen: () => _pickTime(i, isOpen: true),
                            onPickClose: () => _pickTime(i, isOpen: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Fermez un jour avec l’interrupteur pour ne pas proposer vos produits ce jour-là.',
                    style: TextStyle(color: RestaurantPalette.grayText, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.name,
    required this.slot,
    required this.onToggleClosed,
    required this.onPickOpen,
    required this.onPickClose,
  });

  final String name;
  final _DaySlot slot;
  final ValueChanged<bool> onToggleClosed;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    final open = !slot.isClosed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (open) ..._timeChips(),
          Switch.adaptive(
            value: open,
            activeTrackColor: RestaurantPalette.success,
            onChanged: (v) => onToggleClosed(!v),
          ),
        ],
      ),
    );
  }

  List<Widget> _timeChips() {
    return [
      _TimeOption(
        value: slot.opensAt,
        onTap: onPickOpen,
        leading: true,
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Text('–', style: TextStyle(color: RestaurantPalette.grayText, fontSize: 13)),
      ),
      _TimeOption(value: slot.closesAt, onTap: onPickClose),
      const SizedBox(width: 4),
    ];
  }
}

class _TimeOption extends StatelessWidget {
  const _TimeOption({required this.value, required this.onTap, this.leading = false});

  final String? value;
  final VoidCallback onTap;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: RestaurantPalette.orange.withValues(alpha: leading ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: RestaurantPalette.orange.withValues(alpha: 0.25)),
        ),
        child: Text(
          value ?? '--:--',
          style: const TextStyle(
            color: RestaurantPalette.orange,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F1F1));
  }
}