// lib/modules/communication/call/incoming_call_service.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/navigation/app_router.dart';
import 'call_bloc.dart';
import 'call_screen.dart';

/// Điểm nhận cuộc gọi đến của TOÀN ỨNG DỤNG.
///
/// VÌ SAO PHẢI CÓ FILE NÀY: trước đây `CallBloc` chỉ được tạo bên trong
/// `_startCall()` của màn hình hội thoại — nghĩa là kênh tín hiệu chỉ mở khi
/// người dùng BẤM GỌI. Máy bên kia không hề mở `/call/ws`, cũng không có
/// `CallBloc` nào đang lắng nghe, nên gói `call_invite` về tới nơi rồi rơi vào
/// hư không. Cả hai máy đều gọi được đi, không máy nào nhận được.
///
/// Quy tắc đúng: **kênh tín hiệu phải sống bằng tuổi thọ của phiên đăng nhập,
/// không phải bằng tuổi thọ của màn hình.** Ai cũng có thể bị gọi bất cứ lúc
/// nào, kể cả khi đang ở màn hình Kho hay Kế toán.
class IncomingCallService {
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  CallBloc? _bloc;
  String? _connectedUserId;
  StreamSubscription<CallState>? _stateSub;
  bool _screenOpen = false;

  /// Bloc dùng chung cho cả gọi đi lẫn gọi đến.
  ///
  /// Màn hình hội thoại PHẢI dùng cái này thay vì `CallBloc()` mới: hai bloc
  /// nghĩa là hai kết nối `/call/ws/{cùng một id}`, server chỉ giữ cái sau và
  /// cái trước thành mồ côi.
  CallBloc get bloc => _bloc ??= CallBloc();

  bool get isConnected => _connectedUserId != null;

  /// Mở kênh tín hiệu cho [userId]. Gọi lại nhiều lần vô hại.
  ///
  /// Gọi ngay khi ứng dụng biết mình là ai — đăng nhập, đổi user, hoặc khởi
  /// động lại kết nối chat.
  Future<void> ensureConnected(String userId) async {
    if (userId.isEmpty) return;
    if (_connectedUserId == userId) return;

    _connectedUserId = userId;
    final b = bloc;
    await b.initSignaling(userId);

    _stateSub?.cancel();
    _stateSub = b.stream.listen(_onCallState);

    debugPrint('[Call] Kênh tín hiệu đã mở cho "$userId" — sẵn sàng nhận cuộc gọi.');
  }

  /// Đổi người dùng: đóng kênh cũ rồi mở kênh mới.
  Future<void> switchUser(String userId) async {
    if (_connectedUserId == userId) return;
    _connectedUserId = null;
    await ensureConnected(userId);
  }

  void _onCallState(CallState state) {
    if (state is CallRingingIncomingState) {
      _openCallScreen();
    } else if (state is CallEndedState) {
      _screenOpen = false;
    }
  }

  /// Mở màn hình gọi từ bất kỳ đâu trong app.
  ///
  /// Dùng `rootNavigatorKey` chứ không dùng context của màn hình đang mở —
  /// cuộc gọi đến phải đè lên trên mọi thứ, kể cả bottom navigation.
  void _openCallScreen() {
    if (_screenOpen) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[Call] Chưa có Navigator — bỏ qua việc mở màn hình gọi.');
      return;
    }

    _screenOpen = true;
    navigator
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: const CallScreen(),
          ),
        ))
        .whenComplete(() => _screenOpen = false);
  }

  /// Đánh dấu màn hình gọi đã mở sẵn (dùng khi người dùng chủ động gọi đi,
  /// màn hình do `_startCall` đẩy lên chứ không phải service này).
  void markScreenOpen() => _screenOpen = true;

  void markScreenClosed() => _screenOpen = false;

  Future<void> dispose() async {
    await _stateSub?.cancel();
    _stateSub = null;
    await _bloc?.close();
    _bloc = null;
    _connectedUserId = null;
    _screenOpen = false;
  }
}
