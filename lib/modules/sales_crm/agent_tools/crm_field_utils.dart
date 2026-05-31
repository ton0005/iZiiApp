double? parseMoneyValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }

  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  final normalized =
      text.replaceAll(',', '').replaceAll(RegExp(r'(?<=\d)\.(?=\d{3}\b)'), '');
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
  return match == null ? null : double.tryParse(match.group(0)!);
}

Map<String, dynamic> readCustomFields(Map<String, dynamic> args) {
  final fields = <String, dynamic>{};
  final rawFields = args['custom_fields'];
  if (rawFields is Map) {
    fields
        .addAll(rawFields.map((key, value) => MapEntry(key.toString(), value)));
  } else if (rawFields is String && rawFields.trim().isNotEmpty) {
    final parts = rawFields.split(':');
    if (parts.length >= 2) {
      fields[parts.first.trim()] = parts.sublist(1).join(':').trim();
    } else {
      fields['custom'] = rawFields.trim();
    }
  }

  final budget = args['budget'];
  if (budget != null && budget.toString().trim().isNotEmpty) {
    fields['budget'] = budget;
  }

  final fieldName = args['field_name']?.toString().trim();
  final fieldValue = args['field_value'];
  if (fieldName != null &&
      fieldName.isNotEmpty &&
      fieldValue != null &&
      fieldValue.toString().trim().isNotEmpty) {
    fields[fieldName] = fieldValue;
  }

  return fields;
}

String formatCustomFields(Map<String, dynamic> fields) {
  if (fields.isEmpty) {
    return '';
  }
  return fields.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join(', ');
}
