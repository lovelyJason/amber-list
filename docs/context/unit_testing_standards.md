# Flutter 单元测试规范与最佳实践

本文档总结了 Amber List 项目的单元测试标准、目录结构及最佳实践。

## 1. 目录结构规范 (Directory Structure)

测试目录结构应严格**镜像（Mirror）** `lib` 目录。

```text
amber_list/
├── lib/
│   ├── data/
│   │   ├── models/
│   │   │   └── task.dart          <-- 实体类
│   │   └── repositories/
│   ├── core/
│   │   └── services/
│   │       └── pomodoro_timer.dart <-- 业务服务
│   └── presentation/
│       └── providers/
│           └── pomodoro_provider.dart <-- 状态管理
└── test/                          <-- 测试根目录
    ├── data/
    │   ├── models/
    │   │   └── task_test.dart     <-- 对应测试
    ├── core/
    │   └── services/
    │       └── pomodoro_timer_test.dart
    └── presentation/
        └── providers/
            └── pomodoro_controller_test.dart
```

*   **原则**：`lib/path/to/foo.dart` 对应 `test/path/to/foo_test.dart`。
*   **命名**：必须以 `_test.dart` 结尾。

## 2. 编写规范 (Coding Standards)

### A. AAA 模式 (Arrange-Act-Assert)

所有单元测试内部必须遵循 AAA 模式：

*   **Arrange (准备)**: 初始化对象，设置 Mock 行为。
*   **Act (执行)**: 调用被测方法。
*   **Assert (断言)**: 验证结果。

```dart
test('Should return formatted date', () {
  // Arrange
  final date = DateTime(2023, 1, 1);
  final formatter = DateFormatter();

  // Act
  final result = formatter.format(date);

  // Assert
  expect(result, '2023-01-01');
});
```

### B. 命名规范

使用 BDD 风格描述测试用例，清晰表达"行为"和"条件"。
Format: `Should [expected result] when [condition]`

*   ✅ `Should toggle isCompleted when toggleComplete is called`
*   ❌ `test toggle`

### C. 依赖隔离与 Mocking

*   **工具**: `mocktail` (配合 `flutter_test`)。
*   **原则**: 单元测试绝不依赖真实数据库、网络或原生 API。
*   **示例**:

```dart
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements TaskRepository {}

void main() {
  late MockRepository mockRepo;
  late TaskController controller;

  setUp(() {
    mockRepo = MockRepository();
    controller = TaskController(mockRepo);
  });

  test('Should load tasks on init', () async {
    // Arrange
    when(() => mockRepo.getTasks()).thenAnswer((_) async => []);

    // Act
    await controller.loadTasks();

    // Assert
    verify(() => mockRepo.getTasks()).called(1);
  });
}
```

## 3. 常用测试命令

*   运行所有测试: `flutter test`
*   运行指定文件: `flutter test test/path/to/file_test.dart`
*   生成覆盖率: `flutter test --coverage`
