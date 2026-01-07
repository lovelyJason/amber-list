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
    773291782,
    1091926162,
    3184080467,
    2791061238,
    4053212415,
    2754595679,
    854170985,
    1432270551,
    1391752333,
    3551735799,
    1829484744,
    2091417439,
    562545473,
    203429803,
    3204030476,
    3482118731,
    661886427,
    200291465,
    956111980,
    3733632594,
    832306789,
    2071410300,
    2188843595,
    2738364299,
    2603278128,
    1933553089,
    3943313139,
    1412833784,
    3822325481,
    618937256,
    4109371258,
    4268256879,
    3192712983,
    3994298227,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    773291879,
    1091926271,
    3184080433,
    2791061139,
    4053212301,
    2754595584,
    854170885,
    1432270526,
    1391752446,
    3551735683,
    1829484695,
    2091417403,
    562545444,
    203429837,
    3204030573,
    3482118718,
    661886391,
    200291581,
    956111923,
    3733632545,
    832306688,
    2071410207,
    2188843577,
    2738364398,
    2603278148,
    1933553054,
    3943313048,
    1412833693,
    3822325392,
    618937335,
    4109371208,
    4268256863,
    3192712997,
    3994298181,
  ];

  static final String hmacSecretKey = String.fromCharCodes(
    List<int>.generate(
      _envieddatahmacSecretKey.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatahmacSecretKey[i] ^ _enviedkeyhmacSecretKey[i]),
  );
}
