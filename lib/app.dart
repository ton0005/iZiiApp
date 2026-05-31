import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/bloc/app_bloc.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/izii_theme.dart';

class IZiiApp extends StatelessWidget {
  const IZiiApp({super.key});

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
          routerConfig: appRouter,
        );
      },
    );
  }
}
