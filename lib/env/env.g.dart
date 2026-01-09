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
    1613912539,
    227691128,
    2853694512,
    1428690914,
    3200724914,
    3046710671,
    2030494764,
    3430451500,
    1692782561,
    3750291021,
    2596331292,
    3912681722,
    3489343272,
    667289018,
    1165821360,
    1558788628,
    2918360537,
    2704495115,
    2557582637,
    2965299739,
    3882936668,
    3154282798,
    2615032758,
    1185360784,
    3291409849,
    151472141,
    2584489385,
    2263570879,
    2596136315,
    851505184,
    165977631,
    2285630161,
    153574814,
    2267253277,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    1613912506,
    227691029,
    2853694546,
    1428690823,
    3200724928,
    3046710736,
    2030494784,
    3430451525,
    1692782482,
    3750291001,
    2596331331,
    3912681630,
    3489343309,
    667289052,
    1165821393,
    1558788705,
    2918360501,
    2704495231,
    2557582706,
    2965299816,
    3882936633,
    3154282829,
    2615032772,
    1185360885,
    3291409869,
    151472210,
    2584489410,
    2263570906,
    2596136194,
    851505279,
    165977645,
    2285630177,
    153574828,
    2267253291,
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
