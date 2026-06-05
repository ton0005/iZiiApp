import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';

// Events
abstract class CrmEvent extends Equatable {
  const CrmEvent();
  @override
  List<Object?> get props => [];
}

class LoadLeadsEvent extends CrmEvent {}

class LoadDealsEvent extends CrmEvent {}

class UpdateDealStageEvent extends CrmEvent {
  final String dealId;
  final String newStage;

  const UpdateDealStageEvent(this.dealId, this.newStage);

  @override
  List<Object?> get props => [dealId, newStage];
}

class UpdateLeadStatusEvent extends CrmEvent {
  final String leadId;
  final String newStatus;

  const UpdateLeadStatusEvent(this.leadId, this.newStatus);

  @override
  List<Object?> get props => [leadId, newStatus];
}

// State
class CrmState extends Equatable {
  final bool isLoading;
  final List<dynamic> leads;
  final List<Map<String, dynamic>> deals;
  final String? error;

  const CrmState({
    this.isLoading = false,
    this.leads = const [],
    this.deals = const [],
    this.error,
  });

  CrmState copyWith({
    bool? isLoading,
    List<dynamic>? leads,
    List<Map<String, dynamic>>? deals,
    String? error,
  }) {
    return CrmState(
      isLoading: isLoading ?? this.isLoading,
      leads: leads ?? this.leads,
      deals: deals ?? this.deals,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, leads, deals, error];
}

class CrmRepository {
  static final CrmRepository _instance = CrmRepository._internal();
  factory CrmRepository() => _instance;
  CrmRepository._internal();

  final _db = AppDatabase();

  Map<String, dynamic> _decodeCustomFields(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
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

  Future<List<Map<String, dynamic>>> getLeads() async {
    final leads = await _db.select(_db.leads).get();
    final sortedLeads = List.from(leads)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedLeads
        .map((l) => {
              'id': l.id,
              'title': l.title,
              'status': l.status,
              'name': l.notes ?? 'Không tên',
              'expected_revenue': l.expectedRevenue,
              'custom_fields': _decodeCustomFields(l.customFields),
              'created_at': l.createdAt.toIso8601String(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDeals() async {
    final query = _db.select(_db.deals).join([
      drift.leftOuterJoin(_db.contacts, _db.contacts.id.equalsExp(_db.deals.contactId)),
      drift.leftOuterJoin(_db.leads, _db.leads.id.equalsExp(_db.deals.leadId)),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      final deal = row.readTable(_db.deals);
      final contact = row.readTableOrNull(_db.contacts);
      final lead = row.readTableOrNull(_db.leads);

      return {
        'id': deal.id,
        'title': deal.title,
        'amount': deal.amount,
        'stage': deal.stage,
        'expected_close_date': deal.expectedCloseDate?.toIso8601String(),
        'created_at': deal.createdAt.toIso8601String(),
        'contact_name': contact?.name ?? 'Không rõ liên hệ',
        'contact_phone': contact?.phone,
        'lead_title': lead?.title,
      };
    }).toList();
  }

  Future<void> addLead(Map<String, dynamic> lead) async {
    await _db.into(_db.leads).insert(
          LeadsCompanion.insert(
            id: lead['id'],
            title: lead['title'],
            status: drift.Value(lead['status']),
            expectedRevenue: drift.Value(lead['expected_revenue']),
            notes: drift.Value(lead['name']),
            customFields: drift.Value(
              _encodeCustomFields(lead['custom_fields']),
            ),
          ),
        );
    SyncService().queueMutation('leads', 'insert', lead);
  }

  Future<void> updateLeadFull(Map<String, dynamic> leadMap) async {
    final leads = await _db.select(_db.leads).get();
    final lead = leads.firstWhere((l) => l.id == leadMap['id']);

    await _db.update(_db.leads).replace(lead.copyWith(
          title: leadMap['title'],
          status: leadMap['status'],
          expectedRevenue: leadMap['expected_revenue'],
          notes: drift.Value(leadMap['name']),
          customFields: _encodeCustomFields(leadMap['custom_fields']),
        ));
    SyncService().queueMutation('leads', 'update', leadMap);
  }

  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    final leads = await _db.select(_db.leads).get();
    final lead = leads.firstWhere((l) => l.id == leadId);
    await _db.update(_db.leads).replace(lead.copyWith(status: newStatus));
    SyncService().queueMutation('leads', 'update', {
      'id': leadId,
      'status': newStatus,
    });
  }

  Future<void> updateDealStage(String dealId, String newStage) async {
    final deals = await _db.select(_db.deals).get();
    final deal = deals.firstWhere((d) => d.id == dealId);
    await _db.update(_db.deals).replace(deal.copyWith(stage: newStage));
    SyncService().queueMutation('deals', 'update', {
      'id': dealId,
      'stage': newStage,
    });
  }

  Future<bool> updateLead(
    String nameQuery,
    String newNotes,
    double? newExpectedRevenue, {
    Map<String, dynamic> customFields = const {},
  }) async {
    final leads = await _db.select(_db.leads).get();
    final index = leads.indexWhere((l) =>
        (l.notes?.toLowerCase().contains(nameQuery.toLowerCase()) ?? false) ||
        l.title.toLowerCase().contains(nameQuery.toLowerCase()));

    if (index != -1) {
      final lead = leads[index];

      String updatedTitle = lead.title;
      if (newNotes.isNotEmpty) {
        updatedTitle = '${lead.title} - $newNotes';
      }

      await _db.update(_db.leads).replace(
            lead.copyWith(
              title: updatedTitle,
              expectedRevenue: newExpectedRevenue ?? lead.expectedRevenue,
              customFields: _encodeCustomFields({
                ..._decodeCustomFields(lead.customFields),
                ...customFields,
              }),
            ),
          );
      SyncService().queueMutation('leads', 'update', {
        'id': lead.id,
        'title': updatedTitle,
        'expected_revenue': newExpectedRevenue ?? lead.expectedRevenue,
        'custom_fields': {
          ..._decodeCustomFields(lead.customFields),
          ...customFields,
        },
      });
      return true;
    }
    return false;
  }
}

// Bloc
class CrmBloc extends Bloc<CrmEvent, CrmState> {
  CrmBloc() : super(const CrmState()) {
    on<LoadLeadsEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final leads = await CrmRepository().getLeads();
        emit(state.copyWith(
          isLoading: false,
          leads: leads,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<LoadDealsEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final deals = await CrmRepository().getDeals();
        emit(state.copyWith(
          isLoading: false,
          deals: deals,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<UpdateDealStageEvent>((event, emit) async {
      try {
        await CrmRepository().updateDealStage(event.dealId, event.newStage);
        final deals = await CrmRepository().getDeals();
        emit(state.copyWith(deals: deals));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<UpdateLeadStatusEvent>((event, emit) async {
      try {
        await CrmRepository().updateLeadStatus(event.leadId, event.newStatus);
        final leads = await CrmRepository().getLeads();
        emit(state.copyWith(leads: leads));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });
  }
}
