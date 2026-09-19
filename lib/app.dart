import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/bloc/app_bloc.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/izii_theme.dart';
import 'core/localization/app_localizations.dart';

import 'core/server/server_manager.dart';
import 'core/enrollment/device_user_service.dart';
import 'core/sync/sync_service.dart';
import 'modules/communication/call/incoming_call_service.dart';
import 'modules/communication/services/chat_websocket_service.dart';

class IZiiApp extends StatefulWidget {
  const IZiiApp({super.key});

  @override
  State<IZiiApp> createState() => _IZiiAppState();
}

class _IZiiAppState extends State<IZiiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _warmUpServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _warmUpServices();
    }
  }

  /// Khởi động ấm các dịch vụ liên lạc và đồng bộ ngay khi mở ứng dụng hoặc khi ứng dụng hoạt động trở lại.
  Future<void> _warmUpServices() async {
    try {
      final deviceUserId = await DeviceUserService().ensureLocalUser();
      await DeviceUserService().syncDirectory();
      if (deviceUserId != null && deviceUserId.isNotEmpty) {
        await IncomingCallService().ensureConnected(deviceUserId);
      }
      ChatWebSocketService().connect();
      SyncService().triggerSync();
    } catch (e) {
      debugPrint('[IZiiApp] Lỗi trong _warmUpServices: $e');
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await ServerManager().stopServer();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        return MaterialApp.router(
          title: 'iZiiApp',
          debugShowCheckedModeBanner: false,
          theme: IZiiTheme.light,
          darkTheme: IZiiTheme.dark,
          themeMode: state.themeMode,
          locale: state.locale,
          supportedLocales: const [
            Locale('en'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: appRouter,
        );
      },
    );
  }
}
