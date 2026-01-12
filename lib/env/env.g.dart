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
    1535824605,
    1470583309,
    2393980525,
    1731916911,
    3200851898,
    2146049733,
    734146942,
    3222607563,
    2454935457,
    786064305,
    2216912876,
    2979858482,
    4289166924,
    1904939140,
    1877418392,
    679973755,
    2592038626,
    2494773419,
    3033561598,
    1008432034,
    1431190496,
    4217405899,
    3306339273,
    1615258413,
    1212876939,
    204968844,
    2451796429,
    976873294,
    716667517,
    4237733093,
    3765074871,
    4161414680,
    527777530,
    3716300681,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    1535824572,
    1470583392,
    2393980431,
    1731916810,
    3200851912,
    2146049690,
    734146834,
    3222607522,
    2454935506,
    786064325,
    2216912819,
    2979858518,
    4289166889,
    1904939234,
    1877418489,
    679973646,
    2592038542,
    2494773471,
    3033561505,
    1008432081,
    1431190405,
    4217405864,
    3306339259,
    1615258440,
    1212877055,
    204968915,
    2451796390,
    976873259,
    716667396,
    4237733050,
    3765074821,
    4161414696,
    527777480,
    3716300735,
  ];

  static final String hmacSecretKey = String.fromCharCodes(
    List<int>.generate(
      _envieddatahmacSecretKey.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatahmacSecretKey[i] ^ _enviedkeyhmacSecretKey[i]),
  );

  static const String _stickyNoteNativeModeRaw = '3';

  static const String _syncThrottleMinutesRaw = '10';
}
