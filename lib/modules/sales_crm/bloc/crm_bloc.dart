import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/settings/settings_service.dart';

import '../../../core/sync/sharing_repository.dart';

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

class ConvertLeadToDealEvent extends CrmEvent {
  final String leadId;
  const ConvertLeadToDealEvent(this.leadId);

  @override
  List<Object?> get props => [leadId];
}

class LoadDealsByLeadIdEvent extends CrmEvent {
  final String leadId;
  const LoadDealsByLeadIdEvent(this.leadId);

  @override
  List<Object?> get props => [leadId];
}

class LoadLeadsByDealFilterEvent extends CrmEvent {
  final String dealId;
  const LoadLeadsByDealFilterEvent(this.dealId);

  @override
  List<Object?> get props => [dealId];
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

  Future<String> _getActiveUserId() async {
    try {
      return await SettingsService().getActiveUserId();
    } catch (_) {
      return 'default_user';
    }
  }

  Future<List<Map<String, dynamic>>> getLeads() async {
    final userId = await _getActiveUserId();
    final query = _db.select(_db.leads).join([
      drift.leftOuterJoin(_db.deals, _db.deals.leadId.equalsExp(_db.leads.id)),
    ]);
    final rows = await query.get();

    final Map<String, Map<String, dynamic>> leadsMap = {};
    final sharingRepo = SharingRepository();

    for (final row in rows) {
      final lead = row.readTable(_db.leads);
      final deal = row.readTableOrNull(_db.deals);

      final hasPerm = await sharingRepo.hasPermission(
        userId: userId,
        recordType: 'leads',
        recordId: lead.id,
        requiredLevel: 'view',
      );
      if (!hasPerm) continue;

      leadsMap[lead.id] = {
        'id': lead.id,
        'title': lead.title,
        'status': lead.status,
        'name': lead.notes,
        'expected_revenue': lead.expectedRevenue,
        'contact_id': lead.contactId,
        'source': lead.source,
        'owner_id': lead.ownerId,
        'custom_fields': _decodeCustomFields(lead.customFields),
        'created_at': lead.createdAt.toIso8601String(),
        'deal_id': deal?.id,
        'deal_title': deal?.title,
        'deal_amount': deal?.amount,
        'deal_stage': deal?.stage,
        'deal_expected_close_date': deal?.expectedCloseDate?.toIso8601String(),
        'deal_contact_id': deal?.contactId,
        'deal_source': deal?.source,
        'deal_owner_id': deal?.ownerId,
      };
    }

    final sortedLeads = leadsMap.values.toList()
      ..sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    return sortedLeads;
  }

  Future<Map<String, dynamic>?> getLeadById(String id) async {
    final lead = await (_db.select(_db.leads)..where((l) => l.id.equals(id))).getSingleOrNull();
    if (lead == null) return null;
    return {
      'id': lead.id,
      'title': lead.title,
      'status': lead.status,
      'name': lead.notes,
      'expected_revenue': lead.expectedRevenue,
      'contact_id': lead.contactId,
      'source': lead.source,
      'owner_id': lead.ownerId,
      'custom_fields': _decodeCustomFields(lead.customFields),
      'created_at': lead.createdAt.toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> getDeals() async {
    final userId = await _getActiveUserId();
    final query = _db.select(_db.deals).join([
      drift.leftOuterJoin(_db.contacts, _db.contacts.id.equalsExp(_db.deals.contactId)),
      drift.leftOuterJoin(_db.leads, _db.leads.id.equalsExp(_db.deals.leadId)),
    ]);

    final rows = await query.get();
    final sharingRepo = SharingRepository();
    final filtered = <Map<String, dynamic>>[];

    for (final row in rows) {
      final deal = row.readTable(_db.deals);
      final contact = row.readTableOrNull(_db.contacts);
      final lead = row.readTableOrNull(_db.leads);

      final hasPerm = await sharingRepo.hasPermission(
        userId: userId,
        recordType: 'deals',
        recordId: deal.id,
        requiredLevel: 'view',
      );
      if (!hasPerm) continue;

      filtered.add({
        'id': deal.id,
        'title': deal.title,
        'amount': deal.amount,
        'stage': deal.stage,
        'expected_close_date': deal.expectedCloseDate?.toIso8601String(),
        'created_at': deal.createdAt.toIso8601String(),
        'contact_name': contact?.name,
        'contact_phone': contact?.phone,
        'lead_title': lead?.title,
        'lead_id': deal.leadId,
        'contact_id': deal.contactId,
        'source': deal.source,
        'owner_id': deal.ownerId,
      });
    }
    return filtered;
  }

  Future<Map<String, dynamic>?> getDealByLeadId(String leadId) async {
    final query = _db.select(_db.deals).join([
      drift.leftOuterJoin(_db.contacts, _db.contacts.id.equalsExp(_db.deals.contactId)),
    ])..where(_db.deals.leadId.equals(leadId));

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final deal = row.readTable(_db.deals);
    final contact = row.readTableOrNull(_db.contacts);

    return {
      'id': deal.id,
      'title': deal.title,
      'amount': deal.amount,
      'stage': deal.stage,
      'expected_close_date': deal.expectedCloseDate?.toIso8601String(),
      'created_at': deal.createdAt.toIso8601String(),
      'contact_name': contact?.name,
      'contact_phone': contact?.phone,
      'lead_id': deal.leadId,
      'contact_id': deal.contactId,
      'source': deal.source,
      'owner_id': deal.ownerId,
    };
  }

  Future<Map<String, dynamic>?> getLeadByDealId(String dealId) async {
    final deal = await (_db.select(_db.deals)..where((d) => d.id.equals(dealId))).getSingleOrNull();
    if (deal == null || deal.leadId == null) return null;
    return getLeadById(deal.leadId!);
  }

  Future<List<Map<String, dynamic>>> getDealsByLeadId(String leadId) async {
    final query = _db.select(_db.deals).join([
      drift.leftOuterJoin(_db.contacts, _db.contacts.id.equalsExp(_db.deals.contactId)),
      drift.leftOuterJoin(_db.leads, _db.leads.id.equalsExp(_db.deals.leadId)),
    ])..where(_db.deals.leadId.equals(leadId));

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
        'contact_name': contact?.name,
        'contact_phone': contact?.phone,
        'lead_title': lead?.title,
        'lead_id': deal.leadId,
        'contact_id': deal.contactId,
        'source': deal.source,
        'owner_id': deal.ownerId,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getLeadsByDealFilter(String dealId) async {
    final deal = await (_db.select(_db.deals)..where((d) => d.id.equals(dealId))).getSingleOrNull();
    if (deal == null || deal.leadId == null) return [];
    final leadMap = await getLeadById(deal.leadId!);
    if (leadMap == null) return [];
    return [leadMap];
  }

  Future<void> addLead(Map<String, dynamic> lead) async {
    final activeUserId = await _getActiveUserId();
    final ownerId = lead['owner_id'] ?? activeUserId;
    final updatedLead = Map<String, dynamic>.from(lead)..['owner_id'] = ownerId;

    await _db.into(_db.leads).insert(
          LeadsCompanion.insert(
            id: updatedLead['id'],
            title: updatedLead['title'],
            status: drift.Value(updatedLead['status'] ?? 'new'),
            expectedRevenue: drift.Value(updatedLead['expected_revenue'] ?? 0.0),
            notes: drift.Value(updatedLead['name']),
            contactId: drift.Value(updatedLead['contact_id']),
            source: drift.Value(updatedLead['source'] ?? 'direct'),
            ownerId: drift.Value(ownerId),
            customFields: drift.Value(
              _encodeCustomFields(updatedLead['custom_fields']),
            ),
          ),
        );
    SyncService().queueMutation('leads', 'insert', updatedLead);
  }

  Future<void> updateLeadFull(Map<String, dynamic> leadMap) async {
    final leads = await _db.select(_db.leads).get();
    final lead = leads.firstWhere((l) => l.id == leadMap['id']);
    final activeUserId = await _getActiveUserId();
    final ownerId = leadMap['owner_id'] ?? lead.ownerId ?? activeUserId;
    final updatedLeadMap = Map<String, dynamic>.from(leadMap)..['owner_id'] = ownerId;

    await _db.update(_db.leads).replace(lead.copyWith(
          title: updatedLeadMap['title'],
          status: updatedLeadMap['status'],
          expectedRevenue: updatedLeadMap['expected_revenue'],
          notes: drift.Value(updatedLeadMap['name']),
          contactId: drift.Value(updatedLeadMap['contact_id']),
          source: updatedLeadMap['source'] ?? 'direct',
          ownerId: drift.Value(ownerId),
          customFields: _encodeCustomFields(updatedLeadMap['custom_fields']),
        ));
    SyncService().queueMutation('leads', 'update', updatedLeadMap);
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

  Future<void> convertLeadToDeal(String leadId) async {
    final lead = await (_db.select(_db.leads)..where((l) => l.id.equals(leadId))).getSingleOrNull();
    if (lead == null) throw Exception('Lead not found');

    final existingDeal = await (_db.select(_db.deals)..where((d) => d.leadId.equals(leadId))).getSingleOrNull();
    if (existingDeal != null) {
      if (lead.status != 'qualified' && lead.status != 'won') {
        await updateLeadStatus(leadId, 'qualified');
      }
      return;
    }

    String? contactId = lead.contactId;
    if (contactId == null) {
      final contactName = lead.notes ?? lead.title;
      contactId = 'contact_${DateTime.now().millisecondsSinceEpoch}_${leadId.substring(0, leadId.length < 4 ? leadId.length : 4)}';
      
      final contactMap = {
        'id': contactId,
        'name': contactName,
        'isCustomer': true,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      await _db.into(_db.contacts).insert(
        ContactsCompanion.insert(
          id: contactId,
          name: contactName,
          isCustomer: const drift.Value(true),
        ),
      );
      SyncService().queueMutation('contacts', 'insert', contactMap);

      await _db.update(_db.leads).replace(lead.copyWith(
        contactId: drift.Value(contactId),
      ));
      SyncService().queueMutation('leads', 'update', {
        'id': leadId,
        'contact_id': contactId,
      });
    }

    final activeUserId = await _getActiveUserId();
    final ownerId = lead.ownerId ?? activeUserId;
    final dealId = 'deal_${DateTime.now().millisecondsSinceEpoch}_${leadId.substring(0, leadId.length < 4 ? leadId.length : 4)}';
    final dealMap = {
      'id': dealId,
      'title': lead.title,
      'contact_id': contactId,
      'amount': lead.expectedRevenue,
      'lead_id': leadId,
      'source': lead.source,
      'owner_id': ownerId,
      'stage': 'proposal',
      'created_at': DateTime.now().toIso8601String(),
    };

    await _db.into(_db.deals).insert(
      DealsCompanion.insert(
        id: dealId,
        title: lead.title,
        contactId: contactId,
        amount: lead.expectedRevenue,
        leadId: drift.Value(leadId),
        source: drift.Value(lead.source),
        ownerId: drift.Value(ownerId),
        stage: const drift.Value('proposal'),
      ),
    );
    SyncService().queueMutation('deals', 'insert', dealMap);

    await updateLeadStatus(leadId, 'qualified');
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
        if (event.newStatus == 'qualified' || event.newStatus == 'won') {
          final repo = CrmRepository();
          final existingDeal = await repo.getDealByLeadId(event.leadId);
          if (existingDeal == null) {
            await repo.convertLeadToDeal(event.leadId);
          } else {
            await repo.updateLeadStatus(event.leadId, event.newStatus);
          }
        } else {
          await CrmRepository().updateLeadStatus(event.leadId, event.newStatus);
        }
        final leads = await CrmRepository().getLeads();
        final deals = await CrmRepository().getDeals();
        emit(state.copyWith(leads: leads, deals: deals));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<ConvertLeadToDealEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        await CrmRepository().convertLeadToDeal(event.leadId);
        final leads = await CrmRepository().getLeads();
        final deals = await CrmRepository().getDeals();
        emit(state.copyWith(
          isLoading: false,
          leads: leads,
          deals: deals,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<LoadDealsByLeadIdEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final deals = await CrmRepository().getDealsByLeadId(event.leadId);
        emit(state.copyWith(
          isLoading: false,
          deals: deals,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<LoadLeadsByDealFilterEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final leads = await CrmRepository().getLeadsByDealFilter(event.dealId);
        emit(state.copyWith(
          isLoading: false,
          leads: leads,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });
  }
}
