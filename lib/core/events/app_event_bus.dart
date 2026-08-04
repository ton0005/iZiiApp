import 'dart:async';

/// Standard Domain Event emitted across the client application.
class AppDomainEvent {
  final String eventId;
  final String eventType; // e.g. "mushroom.job_added", "organization.employee_created", "customer.registered"
  final String originTable;
  final Map<String, dynamic> data;
  final String timestamp;

  const AppDomainEvent({
    required this.eventId,
    required this.eventType,
    required this.originTable,
    required this.data,
    required this.timestamp,
  });

  factory AppDomainEvent.fromMap(Map<String, dynamic> map) {
    return AppDomainEvent(
      eventId: map['event_id'] as String? ?? '',
      eventType: map['event_type'] as String? ?? 'unknown',
      originTable: map['origin_table'] as String? ?? '',
      data: (map['data'] as Map<String, dynamic>?) ?? {},
      timestamp: map['timestamp'] as String? ?? '',
    );
  }
}

/// Singleton Event Bus (`AppEventBus`) for decoupling real-time event reactions.
class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();
  factory AppEventBus() => _instance;
  AppEventBus._internal();

  final StreamController<AppDomainEvent> _controller = StreamController<AppDomainEvent>.broadcast();

  /// Stream of all incoming real-time domain events.
  Stream<AppDomainEvent> get stream => _controller.stream;

  /// Emits a new domain event into the application.
  void emit(AppDomainEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Listens to specific event types matching a filter or prefix.
  Stream<AppDomainEvent> on(String eventPrefix) {
    return stream.where((event) => event.eventType.startsWith(eventPrefix) || eventPrefix == '*');
  }

  void dispose() {
    _controller.close();
  }
}
