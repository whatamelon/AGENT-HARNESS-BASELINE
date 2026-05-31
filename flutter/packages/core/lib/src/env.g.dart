// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _AppEnv {
  static const List<int> _enviedkeysupabaseUrl = <int>[];

  static const List<int> _envieddatasupabaseUrl = <int>[];

  static final String supabaseUrl = String.fromCharCodes(List<int>.generate(
    _envieddatasupabaseUrl.length,
    (int i) => i,
    growable: false,
  ).map((int i) => _envieddatasupabaseUrl[i] ^ _enviedkeysupabaseUrl[i]));

  static const List<int> _enviedkeysupabaseAnonKey = <int>[];

  static const List<int> _envieddatasupabaseAnonKey = <int>[];

  static final String supabaseAnonKey = String.fromCharCodes(List<int>.generate(
    _envieddatasupabaseAnonKey.length,
    (int i) => i,
    growable: false,
  ).map(
      (int i) => _envieddatasupabaseAnonKey[i] ^ _enviedkeysupabaseAnonKey[i]));

  static const List<int> _enviedkeysentryDsn = <int>[];

  static const List<int> _envieddatasentryDsn = <int>[];

  static final String sentryDsn = String.fromCharCodes(List<int>.generate(
    _envieddatasentryDsn.length,
    (int i) => i,
    growable: false,
  ).map((int i) => _envieddatasentryDsn[i] ^ _enviedkeysentryDsn[i]));
}
