import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/complaint.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_badge.dart';
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
        icon: const Icon(Icons.add),
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
          final palette = BadgePalette.complaint(complaint.status);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(complaint.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${complaint.type} · ${formatDate(complaint.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: palette != null ? StatusBadge(label: palette.$1, color: palette.$2, small: true) : null,
              onTap: () => context.push('/client/complaints/${complaint.id}'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
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
    final palette = BadgePalette.complaint(complaint.status);

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
                      child: Text(complaint.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${complaint.type} · ${formatDateTime(complaint.createdAt, fallback: '')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(complaint.description),
                  ),
                ),
                if (complaint.order != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Commande concernée'),
                      subtitle: Text('${complaint.order!.reference ?? ''} · Statut : ${complaint.order!.status ?? '—'}'),
                    ),
                  ),
                if (complaint.resolution != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined),
                          const SizedBox(width: 8),
                          Expanded(child: Text(complaint.resolution!)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: message.isFromSupport
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.message),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(message.createdAt, fallback: ''),
                            style: Theme.of(context).textTheme.labelSmall,
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
                      decoration: const InputDecoration(hintText: 'Votre message…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réclamation envoyée'), behavior: SnackBarBehavior.floating),
        );
        context.pushReplacement('/client/complaints/${complaint.id}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
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