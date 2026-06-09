import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/bloc/app_bloc.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/izii_theme.dart';
import 'core/localization/app_localizations.dart';

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
          locale: state.locale,
          supportedLocales: const [
            Locale('vi'),
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
