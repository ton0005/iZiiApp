import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class AppEvent extends Equatable {
  const AppEvent();
  
  @override
  List<Object?> get props => [];
}

class ToggleThemeEvent extends AppEvent {}

// State
class AppState extends Equatable {
  final ThemeMode themeMode;
  
  const AppState({this.themeMode = ThemeMode.dark});
  
  AppState copyWith({ThemeMode? themeMode}) {
    return AppState(
      themeMode: themeMode ?? this.themeMode,
    );
  }
  
  @override
  List<Object?> get props => [themeMode];
}

// Bloc
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppState()) {
    on<ToggleThemeEvent>((event, emit) {
      final newMode = state.themeMode == ThemeMode.light 
          ? ThemeMode.dark 
          : ThemeMode.light;
      emit(state.copyWith(themeMode: newMode));
    });
  }
}
