import 'package:flutter/foundation.dart';

/// 激活码类型
enum ActivationCodeType {
  /// 试用版
  trial('trial', '试用版'),

  /// 专业版
  pro('pro', '专业版'),

  /// 企业版
  enterprise('enterprise', '企业版');

  final String value;
  final String displayName;

  const ActivationCodeType(this.value, this.displayName);

  static ActivationCodeType fromString(String value) {
    return ActivationCodeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivationCodeType.pro,
    );
  }
}

/// 激活码状态
enum ActivationCodeStatus {
  /// 未使用
  unused('unused', '未使用'),

  /// 已激活
  activated('activated', '已激活'),

  /// 已过期
  expired('expired', '已过期'),

  /// 已禁用
  disabled('disabled', '已禁用');

  final String value;
  final String displayName;

  const ActivationCodeStatus(this.value, this.displayName);

  static ActivationCodeStatus fromString(String value) {
    return ActivationCodeStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivationCodeStatus.unused,
    );
  }
}

/// 激活码数据模型
/// 与后端返回的数据结构对应
@immutable
class ActivationCode {
  /// 激活码
  final String code;

  /// 激活码类型
  final ActivationCodeType type;

  /// 激活码状态
  final ActivationCodeStatus status;

  /// 有效天数（0 表示永久）
  final int validDays;

  /// 激活时间
  final DateTime? activatedAt;

  /// 过期时间
  final DateTime? expiresAt;

  /// 备注
  final String? remark;

  /// 创建时间
  final DateTime? createdAt;

  /// 更新时间
  final DateTime? updatedAt;

  const ActivationCode({
    required this.code,
    required this.type,
    required this.status,
    this.validDays = 0,
    this.activatedAt,
    this.expiresAt,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  /// 是否永久有效
  bool get isPermanent => validDays == 0;

  /// 是否已过期
  bool get isExpired {
    if (status == ActivationCodeStatus.expired) return true;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 是否有效（已激活且未过期）
  bool get isValid => status == ActivationCodeStatus.activated && !isExpired;

  /// 剩余天数（永久有效返回 -1）
  int get remainingDays {
    if (isPermanent) return -1;
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inDays > 0 ? diff.inDays : 0;
  }

  /// 从 JSON 创建
  factory ActivationCode.fromJson(Map<String, dynamic> json) {
    return ActivationCode(
      code: json['code'] ?? '',
      type: ActivationCodeType.fromString(json['type'] ?? 'pro'),
      status: ActivationCodeStatus.fromString(json['status'] ?? 'unused'),
      validDays: json['validDays'] ?? 0,
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      remark: json['remark'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'type': type.value,
      'status': status.value,
      'validDays': validDays,
      'activatedAt': activatedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'remark': remark,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// 复制并修改
  ActivationCode copyWith({
    String? code,
    ActivationCodeType? type,
    ActivationCodeStatus? status,
    int? validDays,
    DateTime? activatedAt,
    DateTime? expiresAt,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivationCode(
      code: code ?? this.code,
      type: type ?? this.type,
      status: status ?? this.status,
      validDays: validDays ?? this.validDays,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ActivationCode(code: $code, type: ${type.displayName}, status: ${status.displayName}, isPermanent: $isPermanent)';
  }
}
