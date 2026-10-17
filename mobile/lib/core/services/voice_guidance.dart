import 'package:flutter_tts/flutter_tts.dart';

import 'navigation_guide.dart';

/// Guidage vocal des manœuvres : annonce les instructions à des seuils de
/// distance, sans répéter la même manœuvre (anti-bavardage).
///
/// L'utilisateur peut couper le son via [enabled] ; l'état est géré par
/// l'écran appelant. Le service ne fait aucune hypothèse sur la durée de vie :
/// appelez [dispose] quand l'écran est détruit.
class VoiceGuidance {
  VoiceGuidance({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  bool _ready = false;
  bool enabled = true;

  /// Index de la dernière manœuvre annoncée et dernier palier annoncé, pour
  /// éviter les répétitions.
  int? _lastStepIndex;
  int _lastThreshold = -1;
  bool _lastOffRoute = false;

  /// Seuils (en mètres) auxquels une manœuvre est annoncée, décroissants.
  static const List<int> thresholds = [800, 300, 60];

  Future<void> init() async {
    if (_ready) {
      return;
    }
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {
      // Synthèse vocale indisponible sur l'appareil : le guidage visuel reste.
      _ready = false;
    }
  }

  /// Annonce la manœuvre courante si un seuil vient d'être franchi.
  Future<void> announce(NavigationState state) async {
    if (!enabled || !_ready) {
      return;
    }

    if (state.offRoute) {
      if (!_lastOffRoute) {
        _lastOffRoute = true;
        _lastStepIndex = null;
        _lastThreshold = -1;
        await _speak('Vous vous êtes écarté de l\'itinéraire. Recalcul en cours.');
      }
      return;
    }
    _lastOffRoute = false;

    final distance = state.distanceToManeuverMeters;
    final stepIndex = state.stepIndex;

    // Nouvelle manœuvre : on réinitialise le suivi des paliers.
    if (stepIndex != _lastStepIndex) {
      _lastStepIndex = stepIndex;
      _lastThreshold = -1;
    }

    for (var i = 0; i < thresholds.length; i++) {
      final threshold = thresholds[i];
      if (distance <= threshold && (i + 1) > _lastThreshold) {
        _lastThreshold = i + 1;
        await _speak(_phrase(state, threshold));
        return;
      }
    }
  }

  String _phrase(NavigationState state, int threshold) {
    final distance = state.distanceToManeuverMeters;
    final rounded = distance >= 1000
        ? '${(distance / 1000).round()} kilomètres'
        : '${(distance / 100).round() * 100} mètres';
    // Arrivée : message dédié.
    if (state.arrived) {
      return 'Vous êtes arrivé à destination.';
    }
    if (threshold <= 60) {
      return state.instruction;
    }
    return 'Dans $rounded, ${_lowercaseFirst(state.instruction)}';
  }

  String _lowercaseFirst(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text[0].toLowerCase() + text.substring(1);
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ignore les erreurs de synthèse (moteur absent, etc.).
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
