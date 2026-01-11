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
    2616455526,
    3153723760,
    2686399290,
    1104170040,
    336870040,
    1347844740,
    3257898022,
    1681217029,
    2361182587,
    2306281121,
    2378686638,
    370409205,
    3364155593,
    3494500600,
    313789367,
    2808842602,
    373570056,
    2997388943,
    1875470137,
    4163257812,
    2826530520,
    314330095,
    2994878521,
    3772323229,
    2682819603,
    2824083863,
    671584702,
    3367585645,
    3836139100,
    3024712857,
    1370840068,
    466463391,
    1829339178,
    2897417695,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    2616455431,
    3153723677,
    2686399320,
    1104170077,
    336870122,
    1347844827,
    3257898058,
    1681217132,
    2361182472,
    2306281173,
    2378686705,
    370409105,
    3364155564,
    3494500510,
    313789398,
    2808842527,
    373570148,
    2997389051,
    1875470182,
    4163257767,
    2826530493,
    314329996,
    2994878539,
    3772323320,
    2682819687,
    2824083912,
    671584725,
    3367585544,
    3836139045,
    3024712902,
    1370840118,
    466463407,
    1829339160,
    2897417705,
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
