/// Utilitaires de formatage (montants XOF, dates, numéros).
library;

/// Les montants sont stockés en **centimes** côté API (J31).
/// Exemple : 1500 centimes = 15 FCFA.
String formatAmount(int cents, {bool showSymbol = true}) {
  final units = cents / 100;
  final formatted = _formatXof(units);
  return showSymbol ? '$formatted FCFA' : formatted;
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

String formatDateTime(String? iso, {String fallback = ''}) {
  if (iso == null || iso.isEmpty) {
    return fallback;
  }
  try {
    final date = DateTime.parse(iso).toLocal();
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${formatDate(iso, fallback: '$date')} $time';
  } catch (_) {
    return fallback;
  }
}