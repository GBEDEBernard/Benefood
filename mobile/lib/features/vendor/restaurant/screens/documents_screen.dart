import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../restaurant_palette.dart';
import '../widgets/vendor_screen_header.dart';

/// Mon dossier (J21 §4) : progression de la vérification et documents
/// transmis (statut, motif de rejet, consultation et renvoi).
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.marketplace, this.onOpenDrawer});

  /// API vendeur en mode réel ; `null` = mode démonstration.
  final MarketplaceApi? marketplace;

  final VoidCallback? onOpenDrawer;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  Map<String, dynamic> _status = {};
  bool _loading = true;
  String? _error;
  String? _uploadingType;

  bool get _demoMode => widget.marketplace == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_demoMode) {
      setState(() {
        _status = _demoStatus();
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.marketplace!.vendorStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _documents {
    final raw = _status['documents'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> get _progress {
    final raw = _status['progress'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<void> _open(VendorDocumentView document) async {
    if (document.url == null || document.url!.isEmpty) {
      showToast(context, 'Lien de consultation indisponible.', isError: true);
      return;
    }
    final uri = Uri.tryParse(document.url!);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showToast(context, 'Impossible d\'ouvrir le document.', isError: true);
      }
    }
  }

  Future<void> _reupload(VendorDocumentView document) async {
    if (_demoMode || _uploadingType != null) {
      if (_demoMode) {
        showToast(context, 'Renvoi de document indisponible en démonstration.');
      }
      return;
    }
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger le fichier.', isError: true);
      }
      return;
    }
    if (file == null || !mounted) {
      return;
    }
    final bytes = await file.readAsBytes();
    setState(() => _uploadingType = document.type);
    try {
      await widget.marketplace!.uploadVendorDocument(document.type, bytes, fileName: file.name);
      if (!mounted) {
        return;
      }
      showToast(context, 'Document renvoyé.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingType = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: Column(
        children: [
          VendorScreenHeader(title: 'MON DOSSIER', onOpenDrawer: widget.onOpenDrawer),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && !_demoMode) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ProgressCard(steps: _progress),
          const SizedBox(height: 16),
          const Text(
            'DOCUMENTS TRANSMIS',
            style: TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (_documents.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: RestaurantPalette.cardDecoration,
              child: const Text(
                'Aucun document transmis pour le moment. Complétez votre dossier '
                'depuis le parcours d\'inscription.',
                style: TextStyle(color: RestaurantPalette.grayText, fontSize: 13, height: 1.4),
              ),
            )
          else
            for (final raw in _documents)
              _DocumentCard(
                document: VendorDocumentView.fromJson(raw),
                uploading: _uploadingType == raw['type'],
                onOpen: _open,
                onReupload: _reupload,
              ),
        ],
      ),
    );
  }
}

/// Document du dossier, normalisé pour l'affichage.
class VendorDocumentView {
  const VendorDocumentView({
    required this.type,
    required this.status,
    this.reason,
    this.createdAt,
    this.reviewedAt,
    this.url,
  });

  final String type;
  final String status;
  final String? reason;
  final String? createdAt;
  final String? reviewedAt;
  final String? url;

  factory VendorDocumentView.fromJson(Map<String, dynamic> json) {
    return VendorDocumentView(
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'submitted',
      reason: json['reason'] as String?,
      createdAt: json['created_at'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      url: json['url'] as String?,
    );
  }

  String get label => documentTypeLabel(type);

  /// Statut lisible et couleur associée.
  (String, Color) get statusInfo => switch (status) {
        'valid' => ('Validé', RestaurantPalette.success),
        'rejected' => ('Rejeté', RestaurantPalette.danger),
        _ => ('En vérification', RestaurantPalette.ready),
      };
}

String documentTypeLabel(String type) => switch (type) {
      'id_card' => 'Pièce d\'identité',
      'business_registration' => 'Registre de commerce',
      'ifu' => 'IFU (Identifiant Fiscal Unique)',
      'store_photo' => 'Photo de la boutique',
      _ => type,
    };

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.steps});

  final List<Map<String, dynamic>> steps;

  @override
  Widget build(BuildContext context) {
    final lastDone = steps.lastIndexWhere((s) => s['done'] == true);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VÉRIFICATION DU DOSSIER',
            style: TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          if (steps.isEmpty)
            const Text(
              'Progression indisponible.',
              style: TextStyle(color: RestaurantPalette.grayText, fontSize: 13),
            )
          else
            for (var i = 0; i < steps.length; i++)
              _ProgressStep(
                label: steps[i]['label'] as String? ?? '',
                done: steps[i]['done'] == true,
                active: i == lastDone,
                last: i == steps.length - 1,
              ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.done,
    required this.active,
    required this.last,
  });

  final String label;
  final bool done;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? RestaurantPalette.success : RestaurantPalette.borderColor;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? RestaurantPalette.success : RestaurantPalette.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : active
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(strokeWidth: 2, color: RestaurantPalette.orange),
                          )
                        : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? RestaurantPalette.success : RestaurantPalette.borderColor,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 8 : 18, top: 1),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                  color: done ? RestaurantPalette.darkText : RestaurantPalette.grayText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.uploading,
    required this.onOpen,
    required this.onReupload,
  });

  final VendorDocumentView document;
  final bool uploading;
  final ValueChanged<VendorDocumentView> onOpen;
  final ValueChanged<VendorDocumentView> onReupload;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = document.statusInfo;
    final outdated = document.status == 'rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: RestaurantPalette.cardSpacing),
      padding: const EdgeInsets.all(14),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  document.label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: RestaurantPalette.darkText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          if (document.reason != null && document.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Motif : ${document.reason}',
              style: const TextStyle(color: RestaurantPalette.danger, fontSize: 12.5, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onOpen(document),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Consulter'),
                style: TextButton.styleFrom(
                  foregroundColor: RestaurantPalette.forest,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              const Spacer(),
              if (outdated)
                TextButton.icon(
                  onPressed: uploading ? null : () => onReupload(document),
                  icon: uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Renvoyer'),
                  style: TextButton.styleFrom(
                    foregroundColor: RestaurantPalette.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _demoStatus() => {
      'documents': [
        {
          'type': 'id_card',
          'status': 'valid',
          'created_at': DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
          'reviewed_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          'url': null,
        },
        {
          'type': 'business_registration',
          'status': 'valid',
          'created_at': DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
          'reviewed_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          'url': null,
        },
        {
          'type': 'ifu',
          'status': 'submitted',
          'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'url': null,
        },
        {
          'type': 'store_photo',
          'status': 'rejected',
          'reason': 'Image floue, merci de reprendre la photo de la façade.',
          'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          'reviewed_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'url': null,
        },
      ],
      'progress': const [
        {'key': 'registration', 'label': 'Inscription', 'done': true},
        {'key': 'legal_information', 'label': 'Informations légales', 'done': true},
        {'key': 'documents_submitted', 'label': 'Documents soumis', 'done': true},
        {'key': 'verification', 'label': 'Vérification', 'done': false},
        {'key': 'validated', 'label': 'Dossier validé', 'done': false},
        {'key': 'shop_activated', 'label': 'Boutique activée', 'done': false},
      ],
    };
