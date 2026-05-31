import 'package:izii_app/modules/sales_crm/agent_tools/crm_field_utils.dart';
import 'package:test/test.dart';

void main() {
  group('parseMoneyValue', () {
    test('accepts numbers and money text with currency labels', () {
      expect(parseMoneyValue(2000), 2000);
      expect(parseMoneyValue('2000 AUD'), 2000);
      expect(parseMoneyValue('300000000 VND'), 300000000);
      expect(parseMoneyValue('600.000.000 VND'), 600000000);
    });
  });

  group('readCustomFields', () {
    test('stores budget as a flexible custom field', () {
      expect(
        readCustomFields({'budget': '2000 AUD'}),
        {'budget': '2000 AUD'},
      );
    });

    test('stores arbitrary field name and value pairs', () {
      expect(
        readCustomFields({
          'field_name': 'preferred_brand',
          'field_value': 'Dell',
        }),
        {'preferred_brand': 'Dell'},
      );
    });

    test('parses simple custom field text', () {
      expect(
        readCustomFields({'custom_fields': 'budget: 2000 AUD'}),
        {'budget': '2000 AUD'},
      );
    });
  });
}
