import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../modules/accountant/repository.dart';

class PurchaseRepository {
  final AppDatabase _db;

  PurchaseRepository([AppDatabase? database]) : _db = database ?? AppDatabase();

  Map<String, dynamic> _decodeCustomFields(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  String _encodeCustomFields(dynamic fields) {
    if (fields == null) return '{}';
    if (fields is Map) {
      if (fields.isEmpty) return '{}';
      return jsonEncode(Map<String, dynamic>.from(fields));
    }
    return '{}';
  }

  // === PURCHASE ORDERS ===

  Future<List<Map<String, dynamic>>> getPurchaseOrders() async {
    final query = _db.select(_db.purchaseOrders);
    final orders = await query.get();

    final result = <Map<String, dynamic>>[];
    for (final o in orders) {
      final lines = await getPurchaseOrderLines(o.id);
      result.add({
        'id': o.id,
        'order_number': o.orderNumber,
        'partner_name': o.partnerName,
        'order_date': o.orderDate.toIso8601String(),
        'total_amount': o.totalAmount,
        'status': o.status,
        'created_at': o.createdAt.toIso8601String(),
        'custom_fields': _decodeCustomFields(o.customFields),
        'lines': lines,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderLines(
      String orderId) async {
    final query = _db.select(_db.purchaseOrderLines)
      ..where((tbl) => tbl.purchaseOrderId.equals(orderId));
    final lines = await query.get();
    return lines
        .map((l) => <String, dynamic>{
              'id': l.id,
              'purchase_order_id': l.purchaseOrderId,
              'product_name': l.productName,
              'quantity': l.quantity,
              'unit_price': l.unitPrice,
              'total_price': l.totalPrice,
              'created_at': l.createdAt.toIso8601String(),
            })
        .toList();
  }

  Future<void> addPurchaseOrder(Map<String, dynamic> orderData,
      List<Map<String, dynamic>> linesData) async {
    final orderId = orderData['id'] ?? const Uuid().v4();
    final orderNumber = orderData['order_number'] ??
        'PO-${DateTime.now().year}-${const Uuid().v4().substring(0, 4).toUpperCase()}';

    double totalAmount = 0.0;
    for (final l in linesData) {
      final qty = (l['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (l['unit_price'] as num?)?.toDouble() ?? 0.0;
      totalAmount += qty * price;
    }

    await _db.transaction(() async {
      // Insert Order
      await _db.into(_db.purchaseOrders).insert(PurchaseOrdersCompanion.insert(
            id: orderId,
            orderNumber: orderNumber,
            partnerName: orderData['partner_name'],
            totalAmount: Value(totalAmount),
            status: Value(orderData['status'] ?? 'draft'),
            customFields:
                Value(_encodeCustomFields(orderData['custom_fields'])),
          ));

      // Insert Lines
      for (final l in linesData) {
        final lineId = l['id'] ?? const Uuid().v4();
        final qty = (l['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (l['unit_price'] as num?)?.toDouble() ?? 0.0;
        await _db
            .into(_db.purchaseOrderLines)
            .insert(PurchaseOrderLinesCompanion.insert(
              id: lineId,
              purchaseOrderId: orderId,
              productName: l['product_name'],
              quantity: Value(qty),
              unitPrice: Value(price),
              totalPrice: Value(qty * price),
            ));
      }
    });

    // Queue sync mutations
    SyncService().queueMutation('purchase_orders', 'insert', {
      'id': orderId,
      'order_number': orderNumber,
      'partner_name': orderData['partner_name'],
      'total_amount': totalAmount,
      'status': orderData['status'] ?? 'draft',
      'custom_fields': orderData['custom_fields'] ?? {},
    });

    for (final l in linesData) {
      final qty = (l['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (l['unit_price'] as num?)?.toDouble() ?? 0.0;
      SyncService().queueMutation('purchase_order_lines', 'insert', {
        'id': l['id'] ?? const Uuid().v4(),
        'purchase_order_id': orderId,
        'product_name': l['product_name'],
        'quantity': qty,
        'unit_price': price,
        'total_price': qty * price,
      });
    }
  }

  Future<void> updatePurchaseOrderStatus(String orderId, String status) async {
    final o = await (_db.select(_db.purchaseOrders)
          ..where((tbl) => tbl.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null) throw Exception('Purchase order not found: $orderId');

    await (_db.update(_db.purchaseOrders)
          ..where((tbl) => tbl.id.equals(orderId)))
        .write(PurchaseOrdersCompanion(
      status: Value(status),
    ));

    SyncService().queueMutation('purchase_orders', 'update', {
      'id': orderId,
      'status': status,
    });

    if (status == 'approved' || status == 'received') {
      final accRepo = AccountantRepository();
      final ref = 'PO-${o.orderNumber}';
      final isAlreadyPosted = await accRepo.hasJournalEntryReference(ref);
      if (!isAlreadyPosted) {
        // Ensure standard accounts are seeded
        await accRepo.seedTaxRatesAndAccounts();

        final accounts = await accRepo.getAccounts();
        final cogsAcc = accounts.firstWhere((a) => a['code'] == '5-1000');
        final gstPaidAcc = accounts.firstWhere((a) => a['code'] == '2-2100');
        final apAcc = accounts.firstWhere((a) => a['code'] == '2-1000');

        final totalAmt = o.totalAmount;
        final gstAmt = double.parse((totalAmt * 0.1 / 1.1).toStringAsFixed(4));
        final netAmt = double.parse((totalAmt - gstAmt).toStringAsFixed(4));

        await accRepo.addJournalEntry({
          'entry_date': o.orderDate.toIso8601String(),
          'reference': ref,
          'narration':
              'Automated Purchase expense for PO ${o.orderNumber} to ${o.partnerName}',
          'lines': [
            {
              'account_id': cogsAcc['id'],
              'debit': netAmt,
              'credit': 0.0,
              'gst_tax_code': 'GST',
              'gst_amount': gstAmt,
            },
            {
              'account_id': gstPaidAcc['id'],
              'debit': gstAmt,
              'credit': 0.0,
              'gst_tax_code': 'ITS',
              'gst_amount': 0.0,
            },
            {
              'account_id': apAcc['id'],
              'debit': 0.0,
              'credit': totalAmt,
              'gst_tax_code': 'ITS',
              'gst_amount': 0.0,
            },
          ],
        });
      }
    }
  }
}
