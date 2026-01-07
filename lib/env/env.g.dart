// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _Env {
  static const String _secretStorageTypeRaw = 'shared_preferences';

  static const String appUpdateUrl = 'https://cdn.qdovo.com/hupo/update.json';

  static const String activationApiUrl = 'https://mall.qdovo.com/api/v1';

  static const List<int> _enviedkeyhmacSecretKey = <int>[
    3329949512,
    2684096146,
    695416634,
    3003921970,
    866316641,
    933840382,
    2524161398,
    1431154399,
    1672491974,
    2441594254,
    1458476647,
    737259538,
    1515252779,
    3974803718,
    1962377474,
    1975333068,
    1890219352,
    121873180,
    3733655569,
    2758364164,
    3098923113,
    4203039665,
    1700078776,
    3867157821,
    1933369367,
    2847678521,
    3347742283,
    1688011790,
    1686868084,
    2439565041,
    3990504950,
    3947824134,
    2649955525,
    3830978134,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    3329949481,
    2684096255,
    695416664,
    3003922007,
    866316563,
    933840289,
    2524161306,
    1431154358,
    1672491957,
    2441594362,
    1458476600,
    737259638,
    1515252814,
    3974803808,
    1962377571,
    1975333049,
    1890219316,
    121873256,
    3733655630,
    2758364279,
    3098923020,
    4203039698,
    1700078794,
    3867157848,
    1933369443,
    2847678566,
    3347742240,
    1688011883,
    1686867981,
    2439564974,
    3990504900,
    3947824182,
    2649955575,
    3830978144,
  ];

  static final String hmacSecretKey = String.fromCharCodes(
    List<int>.generate(
      _envieddatahmacSecretKey.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatahmacSecretKey[i] ^ _enviedkeyhmacSecretKey[i]),
  );

  static const String _stickyNoteNativeModeRaw = '3';
}
