import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../settings/settings_service.dart';
import '../localization/app_localizations.dart';
import '../localization/translations/vi.dart';
import '../localization/translations/en.dart';

// Events
abstract class AppEvent extends Equatable {
  const AppEvent();
  
  @override
  List<Object?> get props => [];
}

class ToggleThemeEvent extends AppEvent {}

class LoadSettingsEvent extends AppEvent {}

class ChangeLocaleEvent extends AppEvent {
  final Locale locale;
  const ChangeLocaleEvent(this.locale);

  @override
  List<Object?> get props => [locale];
}

// State
class AppState extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;
  
  const AppState({
    this.themeMode = ThemeMode.dark,
    this.locale = const Locale('vi'),
  });
  
  AppState copyWith({ThemeMode? themeMode, Locale? locale}) {
    return AppState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
    );
  }
  
  @override
  List<Object?> get props => [themeMode, locale];
}

// Bloc
class AppBloc extends Bloc<AppEvent, AppState> {
  final SettingsService _settingsService = SettingsService();

  AppBloc() : super(const AppState()) {
    // Register default translations
    AppLocalizations.registerDefaultTranslations(
      vi: viTranslations,
      en: enTranslations,
    );

    on<ToggleThemeEvent>((event, emit) {
      final newMode = state.themeMode == ThemeMode.light 
          ? ThemeMode.dark 
          : ThemeMode.light;
      emit(state.copyWith(themeMode: newMode));
    });

    on<LoadSettingsEvent>((event, emit) async {
      final lang = await _settingsService.getLanguage();
      emit(state.copyWith(locale: Locale(lang)));
    });

    on<ChangeLocaleEvent>((event, emit) async {
      await _settingsService.saveLanguage(event.locale.languageCode);
      emit(state.copyWith(locale: event.locale));
    });
  }
}
