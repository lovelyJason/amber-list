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
    455948835,
    2889278398,
    3239496456,
    1093985103,
    3843861480,
    1425558703,
    3911255614,
    3949768775,
    447820374,
    1119253239,
    3579621649,
    619213573,
    3421261514,
    2032599531,
    1896798285,
    503410347,
    2285704081,
    831615596,
    932263342,
    1047957292,
    1158760639,
    643031868,
    2962200488,
    1634899013,
    3207347023,
    3651658194,
    3069006271,
    3239147588,
    3583370408,
    616634833,
    725081084,
    2485751609,
    2919064004,
    900371215,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    455948866,
    2889278419,
    3239496554,
    1093985066,
    3843861402,
    1425558768,
    3911255634,
    3949768750,
    447820325,
    1119253123,
    3579621710,
    619213665,
    3421261487,
    2032599437,
    1896798252,
    503410398,
    2285704189,
    831615512,
    932263409,
    1047957343,
    1158760666,
    643031903,
    2962200538,
    1634898976,
    3207347003,
    3651658125,
    3069006292,
    3239147553,
    3583370449,
    616634766,
    725081038,
    2485751561,
    2919064054,
    900371257,
  ];

  static final String hmacSecretKey = String.fromCharCodes(
    List<int>.generate(
      _envieddatahmacSecretKey.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatahmacSecretKey[i] ^ _enviedkeyhmacSecretKey[i]),
  );
}
