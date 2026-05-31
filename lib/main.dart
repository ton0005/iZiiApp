import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/bloc/app_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup DI later (GetIt)
  
  runApp(
    BlocProvider(
      create: (_) => AppBloc(),
      child: const IZiiApp(),
    ),
  );
}
