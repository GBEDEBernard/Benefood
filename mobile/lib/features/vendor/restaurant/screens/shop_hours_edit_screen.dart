import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../widgets/time_picker_sheet.dart';

const List<String> _dayNames = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];

const List<String> _dayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

const _orange = Color(0xFFFF6600);
const _cream = Color(0xFFFFF3E6);
const _muted = Color(0xFF6B5645);
const _green = Color(0xFF00A859);
const _darkBlue = Color(0xFF1A1A1A);
const _bg = Color(0xFFF9FAFB);

class _DaySlot {
  _DaySlot({required this.dayOfWeek, this.opensAt, this.closesAt, this.isClosed = false});
  final int dayOfWeek;
  String? opensAt;
  String? closesAt;
  bool isClosed;
}

int _mins(String? value, int fallback) {
  if (value == null) return fallback;
  final p = value.split(':');
  if (p.length < 2) return fallback;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return fallback;
  return h * 60 + m;
}

int _opensMin(_DaySlot s) => _mins(s.opensAt, 8 * 60);
int _closesMin(_DaySlot s) => _mins(s.closesAt, 22 * 60);

int _duration(_DaySlot s) {
  var d = _closesMin(s) - _opensMin(s);
  if (d <= 0) d += 1440;
  return d;
}

String _fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final r = minutes % 60;
  return r == 0 ? '$h h' : '$h h ${r.toString().padLeft(2, '0')}';
}

bool _isOpenAt(_DaySlot s, int nowMin) {
  final o = _opensMin(s);
  final c = _closesMin(s);
  return c > o ? (nowMin >= o && nowMin < c) : (nowMin >= o || nowMin < c);
}

class ShopHoursEditScreen extends StatefulWidget {
  const ShopHoursEditScreen({super.key, required this.hours, this.marketplace, this.onSaved});
  final List<OpeningHour> hours;
  final MarketplaceApi? marketplace;
  final VoidCallback? onSaved;
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
    if (!mounted) return;
    final picked = await showTimePickerSheet(
      context: context,
      title: '${isOpen ? 'Heure d’ouverture' : 'Heure de fermeture'} · ${_dayNames[day]}',
      initial: current,
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (isOpen) {
        slot.opensAt = picked;
      } else {
        slot.closesAt = picked;
      }
    });
    if (mounted) showToast(context, _savedTimeMessage(isOpen, picked, day));
  }

  String _savedTimeMessage(bool isOpen, String picked, int day) {
    final field = isOpen ? 'ouverture' : 'fermeture';
    return 'Heure de $field · ${_dayNames[day]} : $picked';
  }

  void _openAll() => setState(() { for (final slot in _slots) { slot.isClosed = false; } });
  void _closeAll() => setState(() { for (final slot in _slots) { slot.isClosed = true; } });
  void _copyMonday() {
    final monday = _slots.first;
    setState(() {
      for (var i = 1; i < _slots.length; i++) {
        final slot = _slots[i];
        if (!slot.isClosed) {
          slot.opensAt = monday.opensAt;
          slot.closesAt = monday.closesAt;
        }
      }
    });
    showToast(context, 'Horaires du lundi copiés sur les jours ouverts.');
  }

  Future<void> _save() async {
    if (_saving) return;
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
      if (api != null) await api.updateVendorShop(hours: hours);
      if (mounted) {
        showToast(context, 'Horaires enregistrés.');
        Navigator.of(context).pop(hours);
        widget.onSaved?.call();
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = now.weekday - 1;
    final nowMin = now.hour * 60 + now.minute;
    final openDays = _slots.where((s) => !s.isClosed).length;
    final weeklyMinutes = _slots.where((s) => !s.isClosed).fold<int>(0, (sum, s) => sum + _duration(s));
    final todaySlot = _slots[today];
    final String status;
    final String detail;
    final bool live;
    if (todaySlot.isClosed) {
      status = 'Fermé aujourd’hui';
      detail = 'Jour de repos · ${_dayNames[today]}';
      live = false;
    } else {
      final openNow = _isOpenAt(todaySlot, nowMin);
      status = openNow ? 'Ouvert maintenant' : 'Actuellement fermé';
      detail = 'Aujourd’hui · ${todaySlot.opensAt ?? '--:--'} – ${todaySlot.closesAt ?? '--:--'}';
      live = openNow;
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  _StatusCard(status: status, detail: detail, live: live, openDays: openDays, weeklyMinutes: weeklyMinutes),
                  const SizedBox(height: 16),
                  _QuickActions(onOpenAll: _openAll, onCloseAll: _closeAll, onCopyMonday: _copyMonday),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(width: 4, height: 18, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Planning de la semaine', style: TextStyle(color: _darkBlue, fontSize: 16, fontWeight: FontWeight.w800))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _slots.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DayCard(
                        name: _dayNames[i],
                        short: _dayShort[i],
                        slot: _slots[i],
                        isToday: i == today,
                        onToggleClosed: (closed) { HapticFeedback.selectionClick(); setState(() => _slots[i].isClosed = closed); },
                        onPickOpen: () => _pickTime(i, isOpen: true),
                        onPickClose: () => _pickTime(i, isOpen: false),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const _HoursFooter('Heure locale — les clients voient ces horaires sur la fiche boutique. Fermez un jour avec l’interrupteur pour ne pas proposer vos produits ce jour-là.'),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            _SaveBar(saving: _saving, onTap: _save),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _darkBlue, size: 20), onPressed: () => Navigator.of(context).pop(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 4),
          const Text('Horaires', style: TextStyle(color: _darkBlue, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined, color: _darkBlue, size: 22), onPressed: () {}),
              Positioned(right: 6, top: 6, child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Center(child: Text('9', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))),
            ],
          ),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.language_rounded, color: _darkBlue, size: 22), onPressed: () {}),
              Positioned(right: 6, top: 6, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.grey.shade700, shape: BoxShape.circle), child: const Center(child: Text('FR', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))))),
            ],
          ),
          Container(width: 32, height: 32, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFF8C42), Color(0xFFFF6600)])), child: const Center(child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.detail, required this.live, required this.openDays, required this.weeklyMinutes});
  final String status;
  final String detail;
  final bool live;
  final int openDays;
  final int weeklyMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statut actuel', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: live ? _green : Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Flexible(child: Text(status, style: const TextStyle(color: _darkBlue, fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _MiniCard(icon: Icons.calendar_today_rounded, iconColor: _green, value: '$openDays / 7', label: 'Jours ouverts')),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniCard(icon: Icons.access_time_rounded, iconColor: _orange, value: '${(weeklyMinutes / 60).round()} h', label: 'Par semaine')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: _orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.restaurant_rounded, color: _orange, size: 40),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.iconColor, required this.value, required this.label});
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: _darkBlue, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenAll, required this.onCloseAll, required this.onCopyMonday});
  final VoidCallback onOpenAll;
  final VoidCallback onCloseAll;
  final VoidCallback onCopyMonday;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickBtn(icon: Icons.lock_open_rounded, label: 'Tout ouvrir', color: _green, onTap: onOpenAll),
        const SizedBox(width: 8),
        _QuickBtn(icon: Icons.lock_rounded, label: 'Tout fermer', color: Colors.red, onTap: onCloseAll),
        const SizedBox(width: 8),
        _QuickBtn(icon: Icons.copy_rounded, label: 'Copier le lundi', color: _orange, onTap: onCopyMonday),
        const SizedBox(width: 8),
        _QuickBtn(icon: Icons.event_available_rounded, label: 'Jours spéciaux', color: _darkBlue, onTap: () {}),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.name, required this.short, required this.slot, required this.isToday, required this.onToggleClosed, required this.onPickOpen, required this.onPickClose});
  final String name;
  final String short;
  final _DaySlot slot;
  final bool isToday;
  final ValueChanged<bool> onToggleClosed;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    final open = !slot.isClosed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isToday ? Border.all(color: _orange, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: open ? _orange : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(short, style: TextStyle(color: open ? Colors.white : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(color: _darkBlue, fontSize: 15, fontWeight: FontWeight.w800)),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Text('Aujourd’hui', style: TextStyle(color: _orange, fontSize: 9, fontWeight: FontWeight.w800))),
                        ],
                      ],
                    ),
                    Text(open ? '${_fmtDuration(_duration(slot))} d’ouverture' : 'Fermé toute la journée', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: open,
                onChanged: (v) => onToggleClosed(!v),
                thumbColor: WidgetStateProperty.all(Colors.white),
                trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _green : Colors.grey.shade300),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GestureDetector(onTap: onPickOpen, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: _orange.withValues(alpha: 0.3))), child: Row(children: [Icon(Icons.wb_sunny_rounded, color: _orange, size: 16), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Ouverture', style: TextStyle(color: Colors.grey, fontSize: 10)), Text(slot.opensAt ?? '--:--', style: const TextStyle(color: _darkBlue, fontSize: 16, fontWeight: FontWeight.w800))]))])))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 16, color: _orange)),
                Expanded(child: GestureDetector(onTap: onPickClose, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: _orange.withValues(alpha: 0.3))), child: Row(children: [Icon(Icons.nightlight_round, color: _darkBlue, size: 16), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Fermeture', style: TextStyle(color: Colors.grey, fontSize: 10)), Text(slot.closesAt ?? '--:--', style: const TextStyle(color: _darkBlue, fontSize: 16, fontWeight: FontWeight.w800))]))])))),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _duration(slot) / 1440,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(slot.dayOfWeek == 5 ? _orange : _green),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0 h', style: TextStyle(color: Colors.grey, fontSize: 9)),
                Text('6 h', style: TextStyle(color: Colors.grey, fontSize: 9)),
                Text('12 h', style: TextStyle(color: Colors.grey, fontSize: 9)),
                Text('18 h', style: TextStyle(color: Colors.grey, fontSize: 9)),
                Text('24 h', style: TextStyle(color: Colors.grey, fontSize: 9)),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text('Jour fermé', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onTap});
  final bool saving;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))]),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _darkBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
          onPressed: saving ? null : onTap,
          child: saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.save_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Enregistrer les horaires', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Accueil'),
          _NavItem(icon: Icons.receipt_long_rounded, label: 'Commandes'),
          _NavItem(icon: Icons.storefront_rounded, label: 'Shop', elevated: true),
          _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
          _NavItem(icon: Icons.person_rounded, label: 'Profil'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.elevated = false});
  final IconData icon;
  final String label;
  final bool elevated;
  @override
  Widget build(BuildContext context) {
    if (elevated) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40FF6600), blurRadius: 8, offset: Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 2),
          const Text('Shop', style: TextStyle(color: _orange, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey, size: 22),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}

class _HoursFooter extends StatelessWidget {
  const _HoursFooter(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _orange.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _orange.withValues(alpha: 0.15))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _orange),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}