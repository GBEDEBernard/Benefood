import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/complaint.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Centre de réclamations (J158 côté client : création, suivi, messages).
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  List<Complaint> _complaints = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final complaints = await widget.marketplace.complaints(perPage: 50);
      if (mounted) {
        setState(() {
          _complaints = complaints;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réclamations')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/client/complaints/new'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.support_agent),
        label: const Text('Nouvelle'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_complaints.isEmpty) {
      return EmptyState(
        icon: Icons.support_agent,
        title: 'Aucune réclamation',
        subtitle: 'Un souci avec une commande ? Faites-le nous savoir.',
        actionLabel: 'Signaler un problème',
        onAction: () => context.push('/client/complaints/new'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          final complaint = _complaints[index];
          final label = _statusLabel(complaint.status);
          final color = _statusColor(complaint.status);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push('/client/complaints/${complaint.id}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        complaint.isClosed ? Icons.verified_outlined : Icons.support_agent,
                        color: color,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${complaint.type} · ${formatDate(complaint.createdAt)}',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Détail d'une réclamation : suivi + échange de messages.
class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.marketplace, required this.complaintId});

  final MarketplaceApi marketplace;
  final String complaintId;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Complaint? _complaint;
  bool _loading = true;
  String? _error;
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final complaint = await widget.marketplace.complaint(widget.complaintId);
      if (mounted) {
        setState(() {
          _complaint = complaint;
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

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.marketplace.replyComplaint(widget.complaintId, text);
      _message.clear();
      await _load();
      if (mounted) {
        setState(() => _sending = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réclamation')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final complaint = _complaint!;
    final color = _statusColor(complaint.status);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        complaint.subject,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(complaint.status),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_typeLabel(complaint.type)} · ${formatDateTime(complaint.createdAt, fallback: '')}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(complaint.description),
                      ],
                    ),
                  ),
                ),
                if (complaint.order != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, color: AppColors.green, size: 20),
                      ),
                      title: const Text('Commande concernée'),
                      subtitle: Text(
                        '${complaint.order!.reference ?? '—'} · Statut : ${complaint.order!.status ?? '—'}',
                      ),
                    ),
                  ),
                ],
                if (complaint.resolution != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: AppColors.greenLight,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_outlined, color: AppColors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Résolution',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.greenDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(complaint.resolution!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final message in complaint.messages)
                  Align(
                    alignment: message.isFromSupport ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: message.isFromSupport
                            ? const Color(0xFFF0F2F4)
                            : AppColors.greenLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.message),
                          const SizedBox(height: 3),
                          Text(
                            '${formatDateTime(message.createdAt, fallback: '')}'
                            '${message.isFromSupport ? ' · Support' : ''}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: message.isFromSupport ? AppColors.textSecondary : AppColors.greenDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!complaint.isClosed)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Votre message…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Formulaire de nouvelle réclamation.
class ComplaintCreateScreen extends StatefulWidget {
  const ComplaintCreateScreen({super.key, required this.marketplace, this.orderId, this.orders = const []});

  final MarketplaceApi marketplace;
  final String? orderId;
  final List<Order> orders;

  @override
  State<ComplaintCreateScreen> createState() => _ComplaintCreateScreenState();
}

class _ComplaintCreateScreenState extends State<ComplaintCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _type = 'delivery';
  String? _orderId;
  List<Order> _orders = [];
  bool _saving = false;
  bool _loadingOrders = true;

  static const _types = <(String, String)>[
    ('delivery', 'Livraison'),
    ('quality', 'Qualité produit'),
    ('order', 'Commande'),
    ('payment', 'Paiement'),
    ('other', 'Autre'),
  ];

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderId;
    _loadOrders();
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (widget.orders.isNotEmpty) {
      _orders = widget.orders;
      _loadingOrders = false;
      return;
    }
    try {
      final orders = await widget.marketplace.orders(perPage: 10);
      if (mounted) {
        setState(() => _orders = orders);
      }
    } catch (_) {
      // non bloquant
    } finally {
      if (mounted) {
        setState(() => _loadingOrders = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final complaint = await widget.marketplace.createComplaint(
        orderId: _orderId,
        type: _type,
        subject: _subject.text.trim(),
        description: _description.text.trim(),
      );
      if (mounted) {
        showToast(context, 'Réclamation envoyée');
        context.pushReplacement('/client/complaints/${complaint.id}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle réclamation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.orangeLight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Décrivez clairement le problème : notre support vous répondra ici même.',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_loadingOrders && _orders.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _orderId,
                decoration: const InputDecoration(labelText: 'Commande concernée (optionnel)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucune')),
                  ..._orders.map(
                    (o) => DropdownMenuItem(
                      value: o.id,
                      child: Text('${o.reference} · ${o.status}', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _orderId = v),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type *', prefixIcon: Icon(Icons.category_outlined)),
              items: _types.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
              onChanged: (v) => setState(() => _type = v ?? 'other'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _subject,
              label: 'Objet',
              required: true,
              validator: (v) => (v == null || v.trim().length < 3) ? 'Titre trop court' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _description,
              label: 'Description',
              maxLines: 5,
              required: true,
              validator: (v) => (v == null || v.trim().length < 10) ? 'Décrivez le problème (min. 10 caractères)' : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Envoyer',
              icon: Icons.send,
              onPressed: _saving ? null : _save,
              loading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'open' => 'Ouverte',
    'in_review' => 'En cours',
    'resolved' => 'Résolue',
    'closed' => 'Clôturée',
    _ => status.replaceAll('_', ' '),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'open' => const Color(0xFFE08A00),
    'in_review' => const Color(0xFF1976D2),
    'resolved' => AppColors.green,
    'closed' => AppColors.textSecondary,
    _ => AppColors.green,
  };
}

String _typeLabel(String type) {
  return switch (type) {
    'delivery' => 'Livraison',
    'quality' => 'Qualité produit',
    'order' => 'Commande',
    'payment' => 'Paiement',
    _ => 'Autre',
  };
}