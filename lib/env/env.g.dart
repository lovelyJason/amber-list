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
    1604700900,
    154751325,
    1806694960,
    2460960581,
    2804015228,
    2852590094,
    3375115653,
    843118151,
    3854047530,
    3080931193,
    498456543,
    3442781811,
    2197023895,
    834833520,
    3464455968,
    3427132530,
    2577492403,
    439148701,
    3579303239,
    2571909711,
    2894460123,
    2685464699,
    479154554,
    1785508644,
    3619539989,
    3004361315,
    1058403109,
    1719470575,
    662775664,
    3887437258,
    982302169,
    524759913,
    2795617306,
    3841753402,
  ];

  static const List<int> _envieddatahmacSecretKey = <int>[
    1604700805,
    154751280,
    1806694994,
    2460960544,
    2804015118,
    2852590161,
    3375115753,
    843118126,
    3854047577,
    3080931085,
    498456448,
    3442781719,
    2197023986,
    834833430,
    3464456001,
    3427132423,
    2577492447,
    439148777,
    3579303192,
    2571909692,
    2894460094,
    2685464600,
    479154440,
    1785508673,
    3619540065,
    3004361276,
    1058403150,
    1719470474,
    662775561,
    3887437205,
    982302187,
    524759897,
    2795617320,
    3841753356,
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
