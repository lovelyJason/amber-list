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
    1098624505,
    3407197956,
    3598658290,
    3331598574,
    770786932,
    3437554516,
    2520174934,
    1403705623,
    3705911985,
    2554550240,
    902600021,
    3497227916,
    3518453597,
    2603905815,
    1832041814,
    3304691335,
    1470704472,
    1978498690,
    1124950841,
    1353495862,
    2419735219,
    2079034901,
    2151154934,
    2006355338,
    1652397154,
    356099718,
    2453190751,
    176557899,
    549758342,
    1357602313,
    2650521712,
    3666395153,
    3099953529,
    776304243,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    1098624408,
    3407198057,
    3598658192,
    3331598475,
    770786822,
    3437554443,
    2520174906,
    1403705726,
    3705912002,
    2554550164,
    902599946,
    3497228008,
    3518453560,
    2603905905,
    1832041783,
    3304691442,
    1470704436,
    1978498806,
    1124950886,
    1353495877,
    2419735254,
    2079034998,
    2151154820,
    2006355439,
    1652397078,
    356099801,
    2453190708,
    176557870,
    549758463,
    1357602390,
    2650521666,
    3666395169,
    3099953483,
    776304197,
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

  static const String _dailyTaskHourRaw = '0';
}
