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
    305602596,
    405186937,
    619249224,
    828171928,
    967114088,
    3837074855,
    1877657286,
    490953625,
    801775702,
    1013978299,
    3077903038,
    2702698208,
    2845486953,
    2229173261,
    765447528,
    4125129827,
    3525859808,
    2820504944,
    3980169777,
    3402299720,
    1647705628,
    3965777644,
    3763177029,
    2650474782,
    2511867347,
    161501707,
    27861103,
    2312439913,
    1494168600,
    2283865209,
    3507607978,
    1451352631,
    2945429906,
    2984306463,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    305602629,
    405186836,
    619249194,
    828172029,
    967114010,
    3837074936,
    1877657258,
    490953712,
    801775653,
    1013978319,
    3077903073,
    2702698116,
    2845486860,
    2229173355,
    765447433,
    4125129750,
    3525859724,
    2820504836,
    3980169838,
    3402299707,
    1647705721,
    3965777551,
    3763177015,
    2650474875,
    2511867303,
    161501780,
    27860996,
    2312439820,
    1494168673,
    2283865126,
    3507607960,
    1451352583,
    2945429920,
    2984306473,
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
