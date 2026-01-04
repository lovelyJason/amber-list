// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _Env {
  static const String _secretStorageTypeRaw = 'keychain';

  static const String appUpdateUrl = 'https://cdn.qdovo.com/hupo/update.json';

  static const String activationApiUrl = 'https://mall.qdovo.com/api/v1';

  static const List<int> _enviedkeyhmacSecretKey = <int>[
    2191800675,
    3509106344,
    2679947957,
    515602318,
    3851374547,
    3537727281,
    773097195,
    149365436,
    2680858007,
    950956105,
    3790213761,
    2814117167,
    1662572118,
    3983272384,
    4176645881,
    2083444797,
    1249242231,
    521369455,
    2286379509,
    4096215863,
    3390427101,
    1049190959,
    3909600247,
    785400705,
    3784400138,
    589645106,
    1105715809,
    3143657350,
    3552526044,
    2461337808,
    4115866324,
    1434879071,
    3219221034,
    2585135111,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    2191800578,
    3509106373,
    2679947991,
    515602411,
    3851374497,
    3537727342,
    773097095,
    149365461,
    2680858084,
    950956093,
    3790213854,
    2814117195,
    1662572083,
    3983272358,
    4176645784,
    2083444808,
    1249242139,
    521369371,
    2286379434,
    4096215876,
    3390427064,
    1049190988,
    3909600133,
    785400804,
    3784400254,
    589645165,
    1105715722,
    3143657443,
    3552525989,
    2461337743,
    4115866342,
    1434879087,
    3219221016,
    2585135153,
  ];

  static final String hmacSecretKey = String.fromCharCodes(
    List<int>.generate(
      _envieddatahmacSecretKey.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatahmacSecretKey[i] ^ _enviedkeyhmacSecretKey[i]),
  );
}
