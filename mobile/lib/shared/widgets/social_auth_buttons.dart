import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session_provider.dart';
import '../../core/errors/api_exception.dart';
import 'auth_kit.dart';
import 'feedback_widgets.dart';

/// Section d'authentification sociale (Google, Facebook, LinkedIn).
///
/// Les boutons déclenchent un échange de jeton réel avec le backend
/// (`POST /api/v1/auth/social/{provider}`) lorsque l'application mobile est
/// configurée pour obtenir un jeton auprès du fournisseur (SDK natif /
/// flux OAuth). Tant que cette configuration n'est pas finalisée, l'action
/// affiche un état explicite et, en mode debug, permet de tester l'API avec
/// un jeton fourni manuellement.
class SocialAuthSection extends StatefulWidget {
  const SocialAuthSection({
    super.key,
    required this.session,
    required this.onSuccess,
    this.mode = SocialAuthMode.login,
    this.compact = false,
    this.variant = SocialAuthVariant.expanded,
    this.showDivider = true,
  });

  final SessionProvider session;
  final VoidCallback onSuccess;
  final SocialAuthMode mode;
  final bool compact;

  /// `expanded` : grands boutons libellés (formulaires).
  /// `icons` : rangée de logos seuls, idéale pour une carte « Continuer avec ».
  final SocialAuthVariant variant;

  /// Affiche le séparateur « ou » sous les boutons (variante `expanded`).
  final bool showDivider;

  @override
  State<SocialAuthSection> createState() => _SocialAuthSectionState();
}

enum SocialAuthMode { login, register }

enum SocialAuthVariant { expanded, icons }

class _SocialAuthSectionState extends State<SocialAuthSection> {
  String? _loadingProvider;

  bool get _busy => _loadingProvider != null;

  String _cta(String provider) {
    final verb = widget.mode == SocialAuthMode.register ? 'S’inscrire' : 'Continuer';
    return '$verb avec $provider';
  }

  Future<void> _handle(String provider) async {
    if (_busy) {
      return;
    }

    // Acquisition native du jeton fournisseur : à brancher via les SDK
    // officiels (google_sign_in, flutter_facebook_auth, LinkedIn OIDC) une fois
    // les identifiants et paquets configurés. En debug, on permet un test réel
    // de bout en bout en saisissant un jeton (id_token / access_token).
    final token = await _obtainProviderToken(provider);
    if (!mounted || token == null) {
      return;
    }

    setState(() => _loadingProvider = provider);
    try {
      final result = await widget.session.loginWithSocial(
        provider: provider,
        idToken: token.type == _TokenType.idToken ? token.value : null,
        accessToken: token.type == _TokenType.accessToken ? token.value : null,
        tokenType: token.type == _TokenType.idToken ? 'id_token' : 'access_token',
      );
      if (!mounted) {
        return;
      }
      if (result.isNew) {
        showToast(context, 'Compte créé avec ${_providerLabel(provider)}.');
      }
      widget.onSuccess();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 'auth.account_exists_link_required') {
        showToast(
          context,
          e.message.isNotEmpty
              ? e.message
              : 'Un compte existe déjà avec cet e-mail. Connectez-vous puis liez ce fournisseur.',
          isError: true,
        );
      } else if (e.code == 'auth.provider_not_configured') {
        showToast(
          context,
          'Le fournisseur ${_providerLabel(provider)} n’est pas encore configuré côté serveur.',
          isError: true,
        );
      } else {
        showToast(context, e.message.isNotEmpty ? e.message : 'Connexion impossible.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Connexion impossible pour le moment.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  Future<_ProviderToken?> _obtainProviderToken(String provider) async {
    // Point d’intégration SDK natif (production) :
    // - Google   : google_sign_in -> authentication.idToken
    // - Facebook : flutter_facebook_auth -> accessToken.tokenString
    // - LinkedIn : flux OIDC -> access_token
    // Retourner ici le jeton obtenu pour déclencher l’échange backend réel.
    if (kDebugMode) {
      return _showDebugTokenDialog(provider);
    }

    showToast(
      context,
      'Connexion ${_providerLabel(provider)} : finalisez la configuration de l’app mobile (SDK et clés OAuth).',
      isError: true,
    );
    return null;
  }

  Future<_ProviderToken?> _showDebugTokenDialog(String provider) async {
    final controller = TextEditingController();
    _TokenType type = provider == 'facebook' ? _TokenType.accessToken : _TokenType.idToken;

    final result = await showModalBottomSheet<_ProviderToken>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottom = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9DE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connexion ${_providerLabel(provider)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AuthColors.ink),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mode développeur : saisissez un jeton valide du fournisseur pour tester l’échange sécurisé avec le backend. '
                    'En production, ce jeton sera obtenu automatiquement via le SDK officiel.',
                    style: TextStyle(fontSize: 13.5, color: AuthColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<_TokenType>(
                    segments: const [
                      ButtonSegment(value: _TokenType.idToken, label: Text('ID token')),
                      ButtonSegment(value: _TokenType.accessToken, label: Text('Access token')),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) => setModalState(() => type = value.first),
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Collez le jeton ${_providerLabel(provider)}',
                      filled: true,
                      fillColor: AuthColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        return;
                      }
                      Navigator.of(context).pop(_ProviderToken(value: value, type: type));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AuthColors.brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == SocialAuthVariant.icons) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconBrandButton(
            brand: _Brand.google,
            tooltip: _cta('Google'),
            loading: _loadingProvider == 'google',
            disabled: _busy && _loadingProvider != 'google',
            onPressed: () => _handle('google'),
          ),
          const SizedBox(width: 12),
          _IconBrandButton(
            brand: _Brand.facebook,
            tooltip: _cta('Facebook'),
            loading: _loadingProvider == 'facebook',
            disabled: _busy && _loadingProvider != 'facebook',
            onPressed: () => _handle('facebook'),
          ),
          const SizedBox(width: 12),
          _IconBrandButton(
            brand: _Brand.linkedin,
            tooltip: _cta('LinkedIn'),
            loading: _loadingProvider == 'linkedin',
            disabled: _busy && _loadingProvider != 'linkedin',
            onPressed: () => _handle('linkedin'),
          ),
        ],
      );
    }

    final gap = widget.compact ? 10.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BrandButton(
          label: _cta('Google'),
          brand: _Brand.google,
          loading: _loadingProvider == 'google',
          disabled: _busy && _loadingProvider != 'google',
          onPressed: () => _handle('google'),
        ),
        SizedBox(height: gap),
        _BrandButton(
          label: _cta('Facebook'),
          brand: _Brand.facebook,
          loading: _loadingProvider == 'facebook',
          disabled: _busy && _loadingProvider != 'facebook',
          onPressed: () => _handle('facebook'),
        ),
        SizedBox(height: gap),
        _BrandButton(
          label: _cta('LinkedIn'),
          brand: _Brand.linkedin,
          loading: _loadingProvider == 'linkedin',
          disabled: _busy && _loadingProvider != 'linkedin',
          onPressed: () => _handle('linkedin'),
        ),
        if (widget.showDivider) ...[
          SizedBox(height: widget.compact ? 14 : 18),
          const _OrDivider(),
        ],
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, color: Color(0xFFE3E3E8))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Ou continuer avec e-mail',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AuthColors.muted.withValues(alpha: 0.95),
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1, color: Color(0xFFE3E3E8))),
      ],
    );
  }
}

enum _Brand { google, facebook, linkedin }

class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.label,
    required this.brand,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
  });

  final String label;
  final _Brand brand;
  final VoidCallback onPressed;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final style = switch (brand) {
      _Brand.google => const _BrandStyle(
          background: Colors.white,
          foreground: Color(0xFF1F1F1F),
          border: Color(0xFFDADCE0),
        ),
      _Brand.facebook => const _BrandStyle(
          background: Color(0xFF1877F2),
          foreground: Colors.white,
          border: Color(0xFF1877F2),
        ),
      _Brand.linkedin => const _BrandStyle(
          background: Color(0xFF0A66C2),
          foreground: Colors.white,
          border: Color(0xFF0A66C2),
        ),
    };

    final effective = disabled ? 0.45 : 1.0;

    return Opacity(
      opacity: effective,
      child: Material(
        color: style.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: style.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (loading || disabled) ? null : onPressed,
          child: SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: style.foreground,
                            ),
                          )
                        : _BrandMark(brand: brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: style.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandStyle {
  const _BrandStyle({required this.background, required this.foreground, required this.border});
  final Color background;
  final Color foreground;
  final Color border;
}

class _IconBrandButton extends StatelessWidget {
  const _IconBrandButton({
    required this.brand,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
  });

  final _Brand brand;
  final String tooltip;
  final VoidCallback onPressed;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final style = switch (brand) {
      _Brand.google => const _BrandStyle(
          background: Colors.white,
          foreground: Color(0xFF1F1F1F),
          border: Color(0xFFE3E3E8),
        ),
      _Brand.facebook => const _BrandStyle(
          background: Color(0xFF1877F2),
          foreground: Colors.white,
          border: Color(0xFF1877F2),
        ),
      _Brand.linkedin => const _BrandStyle(
          background: Color(0xFF0A66C2),
          foreground: Colors.white,
          border: Color(0xFF0A66C2),
        ),
    };

    final effective = disabled ? 0.45 : 1.0;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: effective,
          child: Material(
            color: style.background,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: BorderSide(color: style.border, width: 1.2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: (loading || disabled) ? null : onPressed,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: style.foreground,
                          ),
                        )
                      : SizedBox(width: 20, height: 20, child: _BrandMark(brand: brand)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.brand});
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return switch (brand) {
      _Brand.google => const _GoogleMark(),
      _Brand.facebook => const _FacebookMark(),
      _Brand.linkedin => const _LinkedInMark(),
    };
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: s * 0.46);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.butt;

    // Segments G multicolores
    canvas.drawArc(rect, -0.55, 1.55, false, stroke..color = const Color(0xFFEA4335));
    canvas.drawArc(rect, 1.0, 1.15, false, stroke..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, 2.15, 1.25, false, stroke..color = const Color(0xFF34A853));
    canvas.drawArc(rect, 3.4, 1.15, false, stroke..color = const Color(0xFF4285F4));

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(center.dx, center.dy), Offset(center.dx + s * 0.42, center.dy), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FacebookMark extends StatelessWidget {
  const _FacebookMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text(
        'f',
        style: TextStyle(
          color: Color(0xFF1877F2),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _LinkedInMark extends StatelessWidget {
  const _LinkedInMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      child: const Text(
        'in',
        style: TextStyle(
          color: Color(0xFF0A66C2),
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1,
        ),
      ),
    );
  }
}

enum _TokenType { idToken, accessToken }

class _ProviderToken {
  const _ProviderToken({required this.value, required this.type});
  final String value;
  final _TokenType type;
}

String _providerLabel(String provider) => switch (provider) {
      'google' => 'Google',
      'facebook' => 'Facebook',
      'linkedin' => 'LinkedIn',
      _ => provider,
    };
