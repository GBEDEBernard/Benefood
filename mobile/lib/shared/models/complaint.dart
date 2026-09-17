class ComplaintOrder {
  const ComplaintOrder({required this.id, this.reference, this.status});

  final String id;
  final String? reference;
  final String? status;

  factory ComplaintOrder.fromJson(Map<String, dynamic> json) => ComplaintOrder(
        id: _s(json['id']),
        reference: json['reference'] is String ? json['reference'] as String : null,
        status: json['status'] is String ? json['status'] as String : null,
      );
}

class ComplaintMessage {
  const ComplaintMessage({required this.id, required this.senderType, required this.message, this.createdAt});

  final String id;
  final String senderType;
  final String message;
  final String? createdAt;

  bool get isFromSupport => senderType == 'porteuse';

  factory ComplaintMessage.fromJson(Map<String, dynamic> json) => ComplaintMessage(
        id: _s(json['id']),
        senderType: _s(json['sender_type']),
        message: _s(json['message']),
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
      );
}

class Complaint {
  const Complaint({
    required this.id,
    required this.type,
    required this.subject,
    required this.description,
    required this.status,
    this.orderId,
    this.order,
    this.resolution,
    this.messages = const [],
    this.closedAt,
    this.createdAt,
  });

  final String id;
  final String? orderId;
  final ComplaintOrder? order;
  final String type;
  final String subject;
  final String description;
  final String status;
  final String? resolution;
  final List<ComplaintMessage> messages;
  final String? closedAt;
  final String? createdAt;

  bool get isClosed => status == 'closed';

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    final rawMessages = json['messages'];
    ComplaintOrder? order;
    if (rawOrder is Map<String, dynamic>) {
      order = ComplaintOrder.fromJson(rawOrder);
    }
    List<ComplaintMessage> messages = [];
    if (rawMessages is List) {
      messages = rawMessages.whereType<Map<String, dynamic>>().map(ComplaintMessage.fromJson).toList();
    }

    return Complaint(
      id: _s(json['id']),
      orderId: json['order_id'] is String ? json['order_id'] as String : null,
      order: order,
      type: _s(json['type']),
      subject: _s(json['subject']),
      description: _s(json['description']),
      status: _s(json['status']),
      resolution: json['resolution'] is String ? json['resolution'] as String : null,
      messages: messages,
      closedAt: json['closed_at'] is String ? json['closed_at'] as String : null,
      createdAt: json['created_at'] is String ? json['created_at'] as String : null,
    );
  }
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;