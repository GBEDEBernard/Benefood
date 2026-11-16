import 'dart:ui' show Locale;

/// Langue disponible dans l'application.
///
/// Le [code] est celui stocké côté API (`users.locale`) : `fr`, `en` ou
/// `fon`. [name] est le libellé français et [nativeName] le libellé affiché
/// dans le sélecteur.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isDefault = false,
  });

  final String code;
  final String name;
  final String nativeName;
  final bool isDefault;

  Locale get locale => Locale(code);

  String get shortCode => code == 'fon' ? 'FON' : code.toUpperCase();

  static const french = AppLanguage(
    code: 'fr',
    name: 'Français',
    nativeName: 'Français',
    isDefault: true,
  );

  static const english = AppLanguage(
    code: 'en',
    name: 'Anglais',
    nativeName: 'English',
  );

  static const fon = AppLanguage(
    code: 'fon',
    name: 'Fon',
    nativeName: 'Fɔngbè',
  );

  static const builtIn = [french, english, fon];

  static const supportedLocales = [Locale('fr'), Locale('en'), Locale('fon')];

  static bool isSupported(String? code) =>
      code != null && builtIn.any((language) => language.code == code);

  static String normalize(String? code) =>
      isSupported(code) ? code! : french.code;

  static AppLanguage fromCode(String? code) => builtIn.firstWhere(
    (language) => language.code == normalize(code),
    orElse: () => french,
  );

  factory AppLanguage.fromJson(Map<String, dynamic> json) {
    final rawCode = json['code'] is String ? json['code'] as String : null;
    final code = rawCode != null && rawCode.isNotEmpty
        ? rawCode
        : french.code;
    final fallback = fromCode(code);
    return AppLanguage(
      code: code,
      name: json['name'] is String && (json['name'] as String).isNotEmpty
          ? json['name'] as String
          : fallback.name,
      nativeName:
          json['native_name'] is String &&
              (json['native_name'] as String).isNotEmpty
          ? json['native_name'] as String
          : fallback.nativeName,
      isDefault: json['is_default'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppLanguage &&
      other.code == code &&
      other.name == name &&
      other.nativeName == nativeName &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(code, name, nativeName, isDefault);
}
