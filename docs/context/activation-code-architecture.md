# 激活码管理功能架构文档

## 概述

激活码功能实现应用的付费授权管理，采用前后端分离架构。后端提供 CRUD 管理接口和校验接口，客户端实现激活流程和状态管理。

**实现时间**: 2025-01-04
**架构模式**: Service + Repository + Provider + UI 分层
**安全机制**: HMAC-SHA256 签名 + 限流 + 离线宽限期

---

## 文件结构

### 后端 (nest-mall-backend)

```
src/hupo/
├── schemas/
│   └── activation-code.schema.ts     # MongoDB Schema + 枚举定义
├── dto/
│   ├── create-activation-code.dto.ts # 创建/更新/查询 DTO
│   └── verify-activation-code.dto.ts # 校验请求 DTO
├── services/
│   ├── activation-code.service.ts    # 核心业务逻辑
│   └── hmac-verifier.service.ts      # HMAC 签名验证
├── hupo.controller.ts                # API 控制器
└── hupo.module.ts                    # 模块注册

src/common/guards/
└── hmac-auth.guard.ts                # HMAC 认证守卫
```

### 客户端 (amber-list)

```
lib/
├── data/
│   ├── models/
│   │   └── activation_code.dart          # 激活码数据模型
│   ├── services/activation/
│   │   ├── activation_service.dart       # 本地存储服务
│   │   └── hmac_signer.dart              # HMAC 签名工具
│   └── repositories/
│       └── activation_repository.dart    # API 调用封装
├── presentation/
│   ├── providers/
│   │   └── activation_provider.dart      # 状态管理 (Riverpod)
│   └── widgets/
│       └── activation_dialog.dart        # 激活弹窗 + 状态卡片
└── env/
    └── env.dart                          # 环境变量 (API URL, HMAC Key)
```

---

## 核心设计原则

### 1. HMAC 签名防护

客户端调用校验接口时需携带签名，防止未授权访问：

```
签名内容: timestamp + code + secretKey
签名算法: HMAC-SHA256
时间戳有效期: 5 分钟
```

请求头格式：
- `X-Timestamp`: 毫秒时间戳
- `X-Signature`: 十六进制签名

### 2. 限流保护

校验接口使用 `@nestjs/throttler` 限流：
- 每 IP 每分钟最多 5 次请求
- 管理接口跳过限流 (`@SkipThrottle()`)

### 3. 离线宽限期

已激活用户在网络异常时可继续使用：
- 宽限期: 7 天
- 每次在线校验成功后重置宽限期
- 宽限期内使用本地缓存的激活状态

### 4. 安全存储

- 激活码: `FlutterSecureStorage` (系统钥匙串)
- 激活信息: `SharedPreferences` (非敏感数据)
- HMAC 密钥: `envied` 编译时注入 (obfuscate: true)

---

## 数据模型

### ActivationCode

```dart
class ActivationCode {
  final String code;              // 激活码
  final ActivationCodeType type;  // 类型: trial/pro/enterprise
  final ActivationCodeStatus status; // 状态: unused/activated/expired/disabled
  final int? validDays;           // 有效天数 (null = 永久)
  final DateTime? activatedAt;    // 激活时间
  final DateTime? expiresAt;      // 过期时间

  bool get isPermanent => validDays == null || validDays == 0;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isValid => status == ActivationCodeStatus.activated && !isExpired;
}
```

### 激活码类型

| 类型 | 说明 |
|------|------|
| `trial` | 试用版 |
| `pro` | 专业版 |
| `enterprise` | 企业版 |

### 激活码状态

| 状态 | 说明 |
|------|------|
| `unused` | 未使用 |
| `activated` | 已激活 |
| `expired` | 已过期 |
| `disabled` | 已禁用 |

---

## API 接口

### 校验接口 (客户端调用)

```
POST /api/v1/hupo/activation-code/verify
Content-Type: application/json
X-Timestamp: 1704326400000
X-Signature: a1b2c3d4...

{
  "code": "AMBER-XXXX-XXXX-XXXX"
}
```

响应：
```json
{
  "code": 0,
  "message": "激活成功",
  "data": {
    "code": "AMBER-XXXX-XXXX-XXXX",
    "type": "pro",
    "status": "activated",
    "validDays": 365,
    "activatedAt": "2025-01-04 12:00:00",
    "expiresAt": "2026-01-04 12:00:00"
  }
}
```

### 管理接口 (需要 BasicAuth)

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/v1/hupo/activation-code` | 创建激活码 |
| `GET` | `/api/v1/hupo/activation-code` | 查询列表 |
| `GET` | `/api/v1/hupo/activation-code/:code` | 查询详情 |
| `PATCH` | `/api/v1/hupo/activation-code/:code` | 更新激活码 |
| `DELETE` | `/api/v1/hupo/activation-code/:code` | 删除激活码 |

---

## 激活流程

### 首次激活

```
用户点击日历
    ↓
检查本地激活状态 → 未激活 → 弹出激活对话框
    ↓
用户输入激活码
    ↓
客户端生成 HMAC 签名
    ↓
调用 /verify 接口
    ↓
后端验证签名 + 校验激活码 + 更新状态
    ↓
返回激活信息 → 保存本地 → 跳转日历
```

### 启动时校验

```
应用启动
    ↓
读取本地激活信息
    ↓
未激活 → 设置 isActivated = false
    ↓
已激活 → 检查是否需要在线校验
    ↓
7天内已校验 → 使用本地缓存
7天外未校验 → 静默在线校验
    ↓
校验成功 → 更新本地缓存
校验失败 → 清除激活状态
网络异常 → 继续使用本地缓存 (宽限期内)
```

---

## 环境配置

### 后端 (.env)

```bash
# HMAC 签名密钥 (生产环境务必修改)
HUPO_HMAC_SECRET_KEY=your_strong_random_key_here
```

### 客户端 (.env)

```bash
# 激活码验证 API 地址
ACTIVATION_API_URL=https://your-api-domain.com/api/v1

# HMAC 签名密钥 (必须与后端一致)
HUPO_HMAC_SECRET_KEY=your_strong_random_key_here
```

修改 `.env` 后需重新生成 `env.g.dart`：
```bash
dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
```

---

## UI 组件

### ActivationDialog

激活码输入弹窗，支持：
- 输入激活码并提交
- 显示加载状态和错误信息
- 激活成功后自动关闭并触发回调

### ActivationStatusCard

设置页面的激活状态卡片，显示：
- 未激活: 橙色提示 + 激活按钮
- 已激活: 绿色状态 + 剩余天数/永久激活 + 注销按钮
- 已过期: 红色提示 + 重新激活按钮

---

## 安全注意事项

1. **生产环境必须使用 HTTPS**，否则签名在网络传输中暴露
2. **HMAC 密钥需要足够复杂**，建议使用 `openssl rand -hex 32` 生成
3. **激活码使用密码学安全随机数生成** (`crypto.randomInt`)
4. **签名使用时序安全比较** (`crypto.timingSafeEqual`) 防止时序攻击

---

## 扩展建议

1. **设备绑定**: 记录设备 ID，限制单码激活设备数
2. **批量生成**: 管理后台支持批量创建激活码
3. **统计分析**: 记录激活来源、地区分布等数据
4. **邮件通知**: 激活码即将过期时发送邮件提醒
