import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repository.dart';

// --- Events ---
abstract class AccountantEvent extends Equatable {
  const AccountantEvent();

  @override
  List<Object?> get props => [];
}

class LoadAccountantDataEvent extends AccountantEvent {
  const LoadAccountantDataEvent();
}

class AddAccountEvent extends AccountantEvent {
  final Map<String, dynamic> account;
  const AddAccountEvent(this.account);

  @override
  List<Object?> get props => [account];
}

class AddJournalEntryEvent extends AccountantEvent {
  final Map<String, dynamic> entry;
  const AddJournalEntryEvent(this.entry);

  @override
  List<Object?> get props => [entry];
}

class LoadBasReportEvent extends AccountantEvent {
  final DateTime startDate;
  final DateTime endDate;
  const LoadBasReportEvent(this.startDate, this.endDate);

  @override
  List<Object?> get props => [startDate, endDate];
}

class LoadFinancialReportsEvent extends AccountantEvent {
  final DateTime startDate;
  final DateTime endDate;
  const LoadFinancialReportsEvent(this.startDate, this.endDate);

  @override
  List<Object?> get props => [startDate, endDate];
}

class SubmitPayrunEvent extends AccountantEvent {
  final Map<String, dynamic> payrun;
  const SubmitPayrunEvent(this.payrun);

  @override
  List<Object?> get props => [payrun];
}

class GenerateAbaFileEvent extends AccountantEvent {
  final String userFinancialInstitution;
  final String userSupplyingFile;
  final String userApcaNumber;
  final String payDescription;
  final DateTime processDate;
  final String userBsb;
  final String userAccountNumber;
  final List<Map<String, dynamic>> payees;

  const GenerateAbaFileEvent({
    required this.userFinancialInstitution,
    required this.userSupplyingFile,
    required this.userApcaNumber,
    required this.payDescription,
    required this.processDate,
    required this.userBsb,
    required this.userAccountNumber,
    required this.payees,
  });

  @override
  List<Object?> get props => [
        userFinancialInstitution,
        userSupplyingFile,
        userApcaNumber,
        payDescription,
        processDate,
        userBsb,
        userAccountNumber,
        payees,
      ];
}

class ClearAccountantStatusEvent extends AccountantEvent {
  const ClearAccountantStatusEvent();
}

// --- State ---
class AccountantState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> journalEntries;
  final List<Map<String, dynamic>> payrollEvents;
  final Map<String, dynamic>? basReport;
  final Map<String, dynamic>? financialReports;
  final String? abaFileContent;
  final String? successMessage;
  final String? error;

  const AccountantState({
    this.isLoading = false,
    this.accounts = const [],
    this.journalEntries = const [],
    this.payrollEvents = const [],
    this.basReport,
    this.financialReports,
    this.abaFileContent,
    this.successMessage,
    this.error,
  });

  AccountantState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? accounts,
    List<Map<String, dynamic>>? journalEntries,
    List<Map<String, dynamic>>? payrollEvents,
    Map<String, dynamic>? basReport,
    Map<String, dynamic>? financialReports,
    String? abaFileContent,
    String? successMessage,
    String? error,
  }) {
    return AccountantState(
      isLoading: isLoading ?? this.isLoading,
      accounts: accounts ?? this.accounts,
      journalEntries: journalEntries ?? this.journalEntries,
      payrollEvents: payrollEvents ?? this.payrollEvents,
      basReport: basReport ?? this.basReport,
      financialReports: financialReports ?? this.financialReports,
      abaFileContent: abaFileContent ?? this.abaFileContent,
      successMessage: successMessage ?? this.successMessage,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        accounts,
        journalEntries,
        payrollEvents,
        basReport,
        financialReports,
        abaFileContent,
        successMessage,
        error,
      ];
}

// --- Bloc ---
class AccountantBloc extends Bloc<AccountantEvent, AccountantState> {
  final AccountantRepository _repository = AccountantRepository();

  AccountantBloc() : super(const AccountantState()) {
    on<LoadAccountantDataEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null));
      try {
        await _repository.seedTaxRatesAndAccounts();
        final accounts = await _repository.getAccounts();
        final journalEntries = await _repository.getJournalEntries();
        final payrollEvents = await _repository.getPayrollEvents();

        emit(state.copyWith(
          isLoading: false,
          accounts: accounts,
          journalEntries: journalEntries,
          payrollEvents: payrollEvents,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<AddAccountEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, successMessage: null));
      try {
        await _repository.addAccount(event.account);
        final accounts = await _repository.getAccounts();
        emit(state.copyWith(
          isLoading: false,
          accounts: accounts,
          successMessage: 'Account added successfully',
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<AddJournalEntryEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, successMessage: null));
      try {
        await _repository.addJournalEntry(event.entry);
        final accounts = await _repository.getAccounts();
        final journalEntries = await _repository.getJournalEntries();

        emit(state.copyWith(
          isLoading: false,
          accounts: accounts,
          journalEntries: journalEntries,
          successMessage: 'Journal entry posted successfully',
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<LoadBasReportEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null));
      try {
        final basReport = await _repository.calculateBasReport(event.startDate, event.endDate);
        emit(state.copyWith(
          isLoading: false,
          basReport: basReport,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<LoadFinancialReportsEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null));
      try {
        final reports = await _repository.getFinancialReports(event.startDate, event.endDate);
        emit(state.copyWith(
          isLoading: false,
          financialReports: reports,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<SubmitPayrunEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, successMessage: null));
      try {
        await _repository.submitStpPayrollEvent(event.payrun);
        final payrollEvents = await _repository.getPayrollEvents();
        
        emit(state.copyWith(
          isLoading: false,
          payrollEvents: payrollEvents,
          successMessage: 'Payroll STP event submitted to ATO successfully',
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<GenerateAbaFileEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, successMessage: null, abaFileContent: null));
      try {
        final abaContent = _repository.generateAbaFile(
          userFinancialInstitution: event.userFinancialInstitution,
          userSupplyingFile: event.userSupplyingFile,
          userApcaNumber: event.userApcaNumber,
          payDescription: event.payDescription,
          processDate: event.processDate,
          userBsb: event.userBsb,
          userAccountNumber: event.userAccountNumber,
          payees: event.payees,
        );

        emit(state.copyWith(
          isLoading: false,
          abaFileContent: abaContent,
          successMessage: 'ABA direct entry file generated successfully',
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<ClearAccountantStatusEvent>((event, emit) {
      emit(state.copyWith(successMessage: null, error: null, abaFileContent: null));
    });
  }
}
