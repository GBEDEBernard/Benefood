import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../restaurant_palette.dart';
import '../widgets/time_picker_sheet.dart';
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

const List<String> _dayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

// Palette orange chaude (aucun vert).
const _orange = RestaurantPalette.orange;
const _orangeDeep = Color(0xFFD9480F);
const _amber = Color(0xFFFFB347);
const _cream = Color(0xFFFFF3E6);
const _line = Color(0xFFF0E2D2);
const _muted = Color(0xFF6B5645);
const _ink = Color(0xFF2B1608);
const _closedBg = Color(0xFFF8F3EE);

/// Slots modifiables de la planification hebdomadaire (lundi = 0).
class _DaySlot {
  _DaySlot({required this.dayOfWeek, this.opensAt, this.closesAt, this.isClosed = false});

  final int dayOfWeek;
  String? opensAt;
  String? closesAt;
  bool isClosed;
}

// ───────────────────────── Utilitaires horaires ─────────────────────────

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

/// Durée d'ouverture en minutes (gère la fermeture après minuit).
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

/// Édition des horaires d'ouverture : 7 jours, boutique ouverte/fermée par
/// jour, heures d'ouverture et de fermeture à la minute.
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
  bool _saveRequested = false;

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
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      if (isOpen) {
        slot.opensAt = picked;
      } else {
        slot.closesAt = picked;
      }
    });
    if (mounted) {
      showToast(context, _savedTimeMessage(isOpen, picked, day));
    }
  }

  String _savedTimeMessage(bool isOpen, String picked, int day) {
    final field = isOpen ? 'ouverture' : 'fermeture';
    return 'Heure de $field · ${_dayNames[day]} : $picked';
  }

  void _openAll() => setState(() {
        for (final slot in _slots) {
          slot.isClosed = false;
        }
      });

  void _closeAll() => setState(() {
        for (final slot in _slots) {
          slot.isClosed = true;
        }
      });

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
    if (_saveRequested) return;
    setState(() => _saveRequested = true);
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
      }
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
      if (mounted) {
        setState(() => _saveRequested = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final now = DateTime.now();
    final today = now.weekday - 1; // lundi = 0
    final nowMin = now.hour * 60 + now.minute;

    final openDays = _slots.where((s) => !s.isClosed).length;
    final weeklyMinutes =
        _slots.where((s) => !s.isClosed).fold<int>(0, (sum, s) => sum + _duration(s));

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
      detail =
          'Aujourd’hui · ${todaySlot.opensAt ?? '--:--'} – ${todaySlot.closesAt ?? '--:--'}';
      live = openNow;
    }

    return Scaffold(
      backgroundColor: RestaurantPalette.background,
      body: MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ShopEditorAppBar(
                title: 'Horaires',
                onSave: _save,
                saving: _saveRequested,
                api: widget.marketplace,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _buildList(
                    constraints.maxWidth,
                    today: today,
                    status: status,
                    detail: detail,
                    live: live,
                    openDays: openDays,
                    weeklyMinutes: weeklyMinutes,
                  ),
                ),
              ),
              _SaveBar(saving: _saveRequested, onTap: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    double width, {
    required int today,
    required String status,
    required String detail,
    required bool live,
    required int openDays,
    required int weeklyMinutes,
  }) {
    // Responsive : une colonne sur téléphone, deux sur tablette.
    final cols = width >= 760 ? 2 : 1;
    const maxContent = 880.0;
    const gap = 12.0;
    final inner = math.min(width - 32, maxContent);
    final side = (width - inner) / 2;
    final cardWidth = cols == 2 ? (inner - gap) / 2 : inner;

    return ListView(
      padding: EdgeInsets.fromLTRB(side, 16, side, 20),
      physics: const BouncingScrollPhysics(),
      children: [
        _reveal(
          0,
          _SummaryCard(
            status: status,
            detail: detail,
            live: live,
            openDays: openDays,
            weeklyMinutes: weeklyMinutes,
          ),
        ),
        const SizedBox(height: 14),
        _reveal(
          1,
          _ShortcutChips(
            onOpenAll: _openAll,
            onCloseAll: _closeAll,
            onCopyMonday: _copyMonday,
          ),
        ),
        const SizedBox(height: 18),
        _reveal(2, const _SectionHeader()),
        const SizedBox(height: 10),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _slots.length; i++)
              SizedBox(
                width: cardWidth,
                child: _reveal(
                  3 + i,
                  _DayCard(
                    name: _dayNames[i],
                    short: _dayShort[i],
                    slot: _slots[i],
                    isToday: i == today,
                    onToggleClosed: (closed) {
                      HapticFeedback.selectionClick();
                      setState(() => _slots[i].isClosed = closed);
                    },
                    onPickOpen: () => _pickTime(i, isOpen: true),
                    onPickClose: () => _pickTime(i, isOpen: false),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _reveal(
          11,
          const _HoursFooter(
            'Heure locale — les clients voient ces horaires sur la fiche boutique. '
            'Fermez un jour avec l’interrupteur pour ne pas proposer vos produits ce jour-là.',
          ),
        ),
      ],
    );
  }

  /// Apparition en cascade (une seule fois) : fondu + remontée.
  Widget _reveal(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
    );
  }
}

// ───────────────────────── Composants ─────────────────────────

/// Effet de pression : légère réduction à l'appui.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Carte récapitulative orange : statut en direct, jours ouverts et volume
/// d'heures par semaine. Dégradé qui tourne, bulles flottantes, reflet.
class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.status,
    required this.detail,
    required this.live,
    required this.openDays,
    required this.weeklyMinutes,
  });

  final String status;
  final String detail;
  final bool live;
  final int openDays;
  final int weeklyMinutes;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bubble(double t,
      {required double size,
      required double alpha,
      required double phase,
      double? left,
      double? right,
      double? top,
      double? bottom}) {
    final a = (t + phase) * 2 * math.pi;
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(9 * math.sin(a), 7 * math.cos(a)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final angle = math.pi / 4 + 0.6 * math.sin(t * 2 * math.pi);
        final pulse = (math.sin(t * 2 * math.pi * 6) + 1) / 2;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(math.cos(angle), math.sin(angle)),
              end: Alignment(-math.cos(angle), -math.sin(angle)),
              colors: const [_orange, _orangeDeep, Color(0xFFFF9A3D)],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _orange.withValues(alpha: 0.36),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              _bubble(t, size: 130, alpha: 0.13, phase: 0.0, right: -36, top: -40),
              _bubble(t, size: 96, alpha: 0.09, phase: 0.4, left: -30, bottom: -50),
              _bubble(t, size: 36, alpha: 0.12, phase: 0.7, right: 80, bottom: 70),
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(-1.9 + 3.8 * t, 0),
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Container(
                        width: 70,
                        height: 420,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.16),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (widget.live)
                                          Container(
                                            width: 8 + 8 * pulse,
                                            height: 8 + 8 * pulse,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withValues(alpha: 0.45 * (1 - pulse)),
                                            ),
                                          ),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: widget.live
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 260),
                                      child: Text(
                                        widget.status,
                                        key: ValueKey(widget.status),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryStat(
                            icon: Icons.event_available_rounded,
                            label: 'Jours ouverts',
                            value: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: widget.openDays.toDouble()),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Text(
                                '${v.round()} / 7',
                                style: _statStyle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryStat(
                            icon: Icons.timelapse_rounded,
                            label: 'Par semaine',
                            value: TweenAnimationBuilder<double>(
                              tween: Tween(
                                  begin: 0, end: widget.weeklyMinutes.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Text(
                                _fmtDuration(v.round()),
                                style: _statStyle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _statStyle = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w800,
);

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: value),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutChips extends StatelessWidget {
  const _ShortcutChips({
    required this.onOpenAll,
    required this.onCloseAll,
    required this.onCopyMonday,
  });

  final VoidCallback onOpenAll;
  final VoidCallback onCloseAll;
  final VoidCallback onCopyMonday;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ShortcutChip(icon: Icons.lock_open_rounded, label: 'Tout ouvrir', onTap: onOpenAll),
        _ShortcutChip(icon: Icons.event_busy_rounded, label: 'Tout fermer', onTap: onCloseAll),
        _ShortcutChip(
            icon: Icons.copy_all_rounded, label: 'Copier le lundi', onTap: onCopyMonday),
      ],
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _orange.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(color: Color(0x12B45309), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _orange),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _orangeDeep,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 17,
          decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Planning de la semaine',
            style: TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte d'un jour : pastille du jour, interrupteur, heures d'ouverture /
/// fermeture et frise sur 24 h. Se déplie / se replie quand on ferme le jour.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.name,
    required this.short,
    required this.slot,
    required this.isToday,
    required this.onToggleClosed,
    required this.onPickOpen,
    required this.onPickClose,
  });

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
    const duration = Duration(milliseconds: 300);

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: open ? Colors.white : _closedBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? _orange : _line,
          width: isToday ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? _orange.withValues(alpha: 0.2)
                : const Color(0x12B45309),
            blurRadius: isToday ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: duration,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: open
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_orange, _orangeDeep],
                        )
                      : null,
                  color: open ? null : const Color(0xFFEADBCB),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: open
                      ? [
                          BoxShadow(
                            color: _orange.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const [],
                ),
                alignment: Alignment.center,
                child: Text(
                  short,
                  style: TextStyle(
                    color: open ? Colors.white : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RestaurantPalette.darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Aujourd’hui',
                              style: TextStyle(
                                color: _orangeDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        open ? '${_fmtDuration(_duration(slot))} d’ouverture' : 'Fermé toute la journée',
                        key: ValueKey(open ? _duration(slot) : -1),
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              _DaySwitch(value: open, onChanged: (v) => onToggleClosed(!v)),
            ],
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TimeBox(
                                label: 'Ouverture',
                                value: slot.opensAt,
                                icon: Icons.wb_sunny_rounded,
                                onTap: onPickOpen,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: _orange),
                            ),
                            Expanded(
                              child: _TimeBox(
                                label: 'Fermeture',
                                value: slot.closesAt,
                                icon: Icons.nightlight_round,
                                onTap: onPickClose,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _DayBar(slot: slot),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DaySwitch extends StatelessWidget {
  const _DaySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _orange
            : const Color(0xFFE2D3C2),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}

/// Bouton d'heure : libellé, heure en grand et icône d'édition.
class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      value ?? '--:--',
                      key: ValueKey(value),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, size: 15, color: _orangeDeep),
          ],
        ),
      ),
    );
  }
}

/// Frise 0 h – 24 h : le segment orange s'ajuste en douceur selon les heures
/// choisies (gère aussi une fermeture après minuit).
class _DayBar extends StatelessWidget {
  const _DayBar({required this.slot});

  final _DaySlot slot;

  @override
  Widget build(BuildContext context) {
    final o = _opensMin(slot);
    final c = _closesMin(slot);
    final overnight = c <= o;

    // Segment 1 : de l'ouverture à la fermeture (ou à minuit).
    final s1 = o / 1440;
    final e1 = (overnight ? 1440 : c) / 1440;
    // Segment 2 : de minuit à la fermeture (seulement si après minuit).
    final e2 = overnight ? c / 1440 : 0.0;

    const labelStyle = TextStyle(color: _muted, fontSize: 9.5, fontWeight: FontWeight.w600);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const dur = Duration(milliseconds: 380);
            return SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E6D8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: dur,
                    curve: Curves.easeOutCubic,
                    left: w * s1,
                    width: w * (e1 - s1),
                    top: 0,
                    bottom: 0,
                    child: const _BarSegment(),
                  ),
                  AnimatedPositioned(
                    duration: dur,
                    curve: Curves.easeOutCubic,
                    left: 0,
                    width: w * e2,
                    top: 0,
                    bottom: 0,
                    child: const _BarSegment(),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 h', style: labelStyle),
            Text('6 h', style: labelStyle),
            Text('12 h', style: labelStyle),
            Text('18 h', style: labelStyle),
            Text('24 h', style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _BarSegment extends StatelessWidget {
  const _BarSegment();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors: [_orange, _amber]),
        boxShadow: [
          BoxShadow(color: _orange.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
    );
  }
}

class _HoursFooter extends StatelessWidget {
  const _HoursFooter(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: _orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'enregistrement fixe en bas de l'écran.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45309).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              onPressed: saving ? null : onTap,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: saving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Enregistrer les horaires'),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}