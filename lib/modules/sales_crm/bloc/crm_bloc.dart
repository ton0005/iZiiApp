import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';

// Events
abstract class CrmEvent extends Equatable {
  const CrmEvent();
  @override
  List<Object?> get props => [];
}

class LoadLeadsEvent extends CrmEvent {}

// State
class CrmState extends Equatable {
  final bool isLoading;
  final List<dynamic> leads; // Sử dụng Model cụ thể sau
  final String? error;

  const CrmState({
    this.isLoading = false,
    this.leads = const [],
    this.error,
  });

  CrmState copyWith({
    bool? isLoading,
    List<dynamic>? leads,
    String? error,
  }) {
    return CrmState(
      isLoading: isLoading ?? this.isLoading,
      leads: leads ?? this.leads,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, leads, error];
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
    } catch (_) {
      // Ignore invalid older payloads so the CRM screen still loads.
    }
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

    // Sort leads to simulate insertion order (newest first)
    final sortedLeads = List.from(leads)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedLeads
        .map((l) => {
              'id': l.id,
              'title': l.title,
              'status': l.status,
              'name': l.notes ??
                  'Không tên', // Map name to notes for UI compatibility
              'expected_revenue': l.expectedRevenue,
              'custom_fields': _decodeCustomFields(l.customFields),
              'created_at': l.createdAt.toIso8601String(),
            })
        .toList();
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
  }
}
