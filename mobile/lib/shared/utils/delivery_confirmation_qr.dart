String buildDeliveryConfirmationQr({
  required String reference,
  required String code,
}) {
  return Uri(
    scheme: 'beninfood',
    host: 'delivery-confirmation',
    queryParameters: {'reference': reference, 'code': code},
  ).toString();
}

String? parseDeliveryConfirmationQr(
  String value, {
  required String expectedReference,
}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'beninfood' ||
      uri.host != 'delivery-confirmation' ||
      uri.queryParameters['reference'] != expectedReference) {
    return null;
  }

  final code = uri.queryParameters['code'];
  return code != null && RegExp(r'^\d{6}$').hasMatch(code) ? code : null;
}
