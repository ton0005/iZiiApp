import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/bloc/app_bloc.dart';
import 'modules/communication/bloc/chat_bloc.dart' as comm;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup DI later (GetIt)
  
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppBloc()..add(LoadSettingsEvent())),
        BlocProvider(create: (_) => comm.ChatBloc()),
      ],
      child: const IZiiApp(),
    ),
  );
}

