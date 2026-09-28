import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_settings.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Réglages du serveur API (dev) — permet de pointer un appareil physique
/// vers l'IP locale du poste, ex. `http://192.168.1.102:8000`.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _controller.text = AppConfig.apiBaseUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = ApiSettings.normalize(_controller.text);
    if (url == null) {
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$url/api/v1/health'))
          .timeout(const Duration(seconds: 6));
      if (mounted) {
        setState(() {
          _testResult = response.statusCode == 200
              ? 'Connexion OK — le serveur répond.'
              : 'Le serveur répond (HTTP ${response.statusCode}), mais l’API ne renvoie pas le statut attendu.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _testResult = 'Échec : serveur injoignable. Vérifiez l’adresse, que le '
              'backend tourne (php -S 0.0.0.0:8000 server.php) et que le téléphone '
              'et le poste sont sur le même réseau Wi-Fi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save() async {
    final url = ApiSettings.normalize(_controller.text);

    setState(() => _saving = true);
    await ApiSettings.saveOverride(url);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (url == null) {
      showToast(context, 'Réglage par défaut rétabli. Redémarrez l’app.');
    } else {
      showToast(context, 'URL enregistrée. Redémarrez l’app pour appliquer.');
    }
    _controller.text = AppConfig.apiBaseUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Serveur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.dns_outlined, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Adresse du serveur API',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sur un téléphone physique, renseignez l’IP de votre poste sur le même '
              'réseau Wi-Fi, ex. http://192.168.1.102:8000',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _controller,
              label: 'URL de base',
              icon: Icons.link,
              keyboardType: TextInputType.url,
              hint: 'http://192.168.1.102:8000',
            ),
            const SizedBox(height: 16),
            AppButton(
              label: _testing ? 'Test en cours…' : 'Tester la connexion',
              icon: Icons.wifi_tethering,
              onPressed: _testing ? null : _test,
              loading: _testing,
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              _TestResultBadge(result: _testResult!),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Retour au réglage par défaut',
                  onPressed: _saveWith(null),
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Le changement s’applique au prochain démarrage de l’application.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _saveWith(String? value) {
    return () async {
      _controller.text = value ?? '';
      await _save();
    };
  }
}

class _TestResultBadge extends StatelessWidget {
  const _TestResultBadge({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final ok = result.startsWith('Connexion OK');
    final color = ok ? Colors.green.shade700 : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(result, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}