/// Utilitaires de formatage (montants XOF, dates, numéros).
library;

/// Parité fixe du franc CFA (XOF) avec l'euro.
const double kXofPerEuro = 655.957;

/// Montants XOF : entiers sans décimale (précision 0 côté serveur).
/// Exemple : 1500 = 1 500 FCFA.
String formatAmount(int amount, {bool showSymbol = true}) {
  final formatted = _formatXof(amount.toDouble());
  return showSymbol ? '$formatted FCFA' : formatted;
}

/// Conversion indicative d'un montant XOF en euros (1 EUR = 655,957 XOF).
/// Utilisée uniquement à l'affichage : les débits restent libellés en FCFA.
String formatEuroFromXof(
  int amount, {
  double rate = kXofPerEuro,
  bool showSymbol = true,
}) {
  final safeRate = rate > 0 ? rate : kXofPerEuro;
  final parts = (amount / safeRate).toStringAsFixed(2).split('.');
  final formatted = '${_thousands(parts[0])},${parts[1]}';
  return showSymbol ? '$formatted €' : formatted;
}

String _formatXof(double value) {
  final isInteger = value == value.roundToDouble();
  final text = isInteger ? value.round().toString() : value.toStringAsFixed(2);
  return _thousands(text);
}

String _thousands(String digits) {
  final buffer = StringBuffer();
  var count = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    buffer.write(digits[i]);
    count++;
    if (count % 3 == 0 && i > 0) {
      buffer.write(' ');
    }
  }
  return buffer.toString().split('').reversed.join();
}

/// Montant abrégé pour les axes de graphique et les tuiles compactes :
/// 1 500 → "1,5 k", 2 000 000 → "2 M".
String formatCompactAmount(num amount) {
  final value = amount.toDouble();
  if (value.abs() >= 1000000) {
    return '${_compact(value / 1000000)} M';
  }
  if (value.abs() >= 1000) {
    return '${_compact(value / 1000)} k';
  }
  return _compact(value);
}

String _compact(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) {
    return rounded.toInt().toString();
  }
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String formatPhone(String phone) {
  return phone;
}

/// Formate une distance en km (J177) : "350 m" sous 1 km, sinon "1,2 km".
String formatDistance(double? km) {
  if (km == null || !km.isFinite) {
    return '—';
  }
  if (km < 1) {
    return '${(km * 1000).round()} m';
  }
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

String formatDate(String? iso, {String fallback = ''}) {
  if (iso == null || iso.isEmpty) {
    return fallback;
  }
  try {
    final date = DateTime.parse(iso).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  } catch (_) {
    return fallback;
  }
}

const _weekdayLabels = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

const _monthLabels = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Jour court et lisible : "Aujourd'hui" ou "lun. 27 oct.".
String formatDayLabel(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final isToday =
      local.year == reference.year &&
      local.month == reference.month &&
      local.day == reference.day;

  if (isToday) {
    return 'Aujourd’hui';
  }

  return '${_weekdayLabels[local.weekday - 1]} ${local.day} ${_monthLabels[local.month - 1]}';
}

/// Heure seule (HH:MM) d'un instant ISO : "14:35".
String formatTime(String? iso, {String fallback = '--:--'}) {
  if (iso == null || iso.isEmpty) {
    return fallback;
  }
  try {
    final date = DateTime.parse(iso).toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return fallback;
  }
}

/// Écart relatif à maintenant, en clair : "à l'instant", "il y a 12 min",
/// "il y a 2 h", "il y a 3 j".
String formatAgo(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) {
    return '';
  }
  DateTime parsed;
  try {
    parsed = DateTime.parse(iso).toLocal();
  } catch (_) {
    return '';
  }
  final reference = now ?? DateTime.now();
  final seconds = reference.difference(parsed).inSeconds;

  // Une horloge serveur légèrement en avance ne doit pas afficher de futur.
  if (seconds < 60) {
    return 'à l’instant';
  }
  if (seconds < 3600) {
    return 'il y a ${seconds ~/ 60} min';
  }
  if (seconds < 86400) {
    return 'il y a ${seconds ~/ 3600} h';
  }
  return 'il y a ${seconds ~/ 86400} j';
}

String formatDateTime(String? iso, {String fallback = ''}) {
  if (iso == null || iso.isEmpty) {
    return fallback;
  }
  try {
    final date = DateTime.parse(iso).toLocal();
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${formatDate(iso, fallback: '$date')} $time';
  } catch (_) {
    return fallback;
  }
}
