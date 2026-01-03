import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// ============================================================
/// SharedPreferences 调试编辑器
/// ============================================================
/// 用于查看和编辑 SharedPreferences 数据的调试工具
///
/// 功能特性：
/// - 搜索过滤 key
/// - 布尔值下拉选择
/// - JSON 自动格式化和语法高亮编辑
/// - 长文本多行显示
/// - 新增/删除键值对
/// ============================================================
class PrefsEditor extends StatefulWidget {
  const PrefsEditor({super.key});

  @override
  State<PrefsEditor> createState() => _PrefsEditorState();
}

class _PrefsEditorState extends State<PrefsEditor> {
  SharedPreferences? _prefs;
  Map<String, Object> _data = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _refreshData();
  }

  void _refreshData() {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys();
    final newData = <String, Object>{};
    for (var key in keys) {
      final value = _prefs!.get(key);
      if (value != null) {
        newData[key] = value;
      }
    }
    setState(() {
      _data = newData;
    });
  }

  List<MapEntry<String, Object>> get _filteredData {
    if (_searchQuery.isEmpty) return _data.entries.toList();
    return _data.entries
        .where((e) => e.key.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  /// 判断字符串是否是 JSON 格式
  bool _isJsonString(String value) {
    if (value.isEmpty) return false;
    final trimmed = value.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }

  /// 格式化 JSON 字符串（美化显示）
  String _formatJson(String jsonStr) {
    try {
      final parsed = jsonDecode(jsonStr);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (e) {
      return jsonStr; // 解析失败返回原字符串
    }
  }

  /// 压缩 JSON 字符串（保存时去除格式）
  String _compactJson(String jsonStr) {
    try {
      final parsed = jsonDecode(jsonStr);
      return jsonEncode(parsed);
    } catch (e) {
      return jsonStr;
    }
  }

  /// 获取值的类型标签
  String _getTypeLabel(Object value) {
    if (value is String) return 'String';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is List<String>) return 'List<String>';
    return 'Unknown';
  }

  /// 获取值的预览文本（截断长文本）
  String _getPreviewText(Object value) {
    final text = value.toString();
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  /// 编辑值的对话框
  Future<void> _editValue(String key, Object value) async {
    final typeLabel = _getTypeLabel(value);

    // 布尔值：使用专门的对话框
    if (value is bool) {
      await _editBoolValue(key, value);
      return;
    }

    // 字符串：检查是否是 JSON
    if (value is String && _isJsonString(value)) {
      await _editJsonValue(key, value);
      return;
    }

    // 长字符串：使用多行编辑
    if (value is String && value.length > 50) {
      await _editLongStringValue(key, value, typeLabel);
      return;
    }

    // 其他类型：使用简单输入框
    await _editSimpleValue(key, value, typeLabel);
  }

  /// 编辑布尔值
  Future<void> _editBoolValue(String key, bool value) async {
    bool currentValue = value;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('编辑 "$key"'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('类型: bool', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                // 使用 Switch 更直观
                Row(
                  children: [
                    const Text('值: '),
                    const SizedBox(width: 8),
                    Switch(
                      value: currentValue,
                      onChanged: (v) => setDialogState(() => currentValue = v),
                    ),
                    Text(
                      currentValue ? 'true' : 'false',
                      style: TextStyle(
                        color: currentValue ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  _saveValue(key, currentValue);
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 编辑 JSON 值
  Future<void> _editJsonValue(String key, String value) async {
    final formattedJson = _formatJson(value);
    final controller = TextEditingController(text: formattedJson);
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('编辑 "$key"'),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型标签和格式化按钮
                  Row(
                    children: [
                      const Text('类型: JSON (String)',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.format_align_left, size: 16),
                        label: const Text('格式化'),
                        onPressed: () {
                          try {
                            final formatted = _formatJson(controller.text);
                            controller.text = formatted;
                            setDialogState(() => errorText = null);
                          } catch (e) {
                            setDialogState(() => errorText = 'JSON 格式错误');
                          }
                        },
                      ),
                    ],
                  ),
                  // JSON 编辑区域
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(
                          color: errorText != null ? Colors.red : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(12),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (text) {
                          try {
                            jsonDecode(text);
                            if (errorText != null) {
                              setDialogState(() => errorText = null);
                            }
                          } catch (e) {
                            if (errorText == null) {
                              setDialogState(() => errorText = 'JSON 格式错误');
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  // 错误提示
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: errorText != null
                    ? null
                    : () {
                        final compacted = _compactJson(controller.text);
                        _saveValue(key, compacted);
                        Navigator.pop(context);
                      },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 编辑长字符串值
  Future<void> _editLongStringValue(
      String key, String value, String typeLabel) async {
    final controller = TextEditingController(text: value);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑 "$key"'),
        content: SizedBox(
          width: 450,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('类型: $typeLabel', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              _saveValue(key, controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 编辑简单值（短字符串、数字等）
  Future<void> _editSimpleValue(
      String key, Object value, String typeLabel) async {
    final controller = TextEditingController(text: value.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑 "$key"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类型: $typeLabel', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              width: 300,
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: value is int || value is double
                    ? TextInputType.number
                    : TextInputType.text,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Object? newValue;
              if (value is int) newValue = int.tryParse(controller.text);
              if (value is double) newValue = double.tryParse(controller.text);
              if (value is String) newValue = controller.text;
              if (value is List<String>) {
                newValue =
                    controller.text.split(',').map((e) => e.trim()).toList();
              }

              if (newValue != null) {
                _saveValue(key, newValue);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveValue(String key, Object value) async {
    if (value is String) await _prefs?.setString(key, value);
    if (value is bool) await _prefs?.setBool(key, value);
    if (value is int) await _prefs?.setInt(key, value);
    if (value is double) await _prefs?.setDouble(key, value);
    if (value is List<String>) await _prefs?.setStringList(key, value);
    _refreshData();
  }

  Future<void> _addNewPair() async {
    String type = 'String';
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('新增键值对'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['String', 'bool', 'int', 'double', 'List<String>']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                const SizedBox(height: 12),
                if (type == 'bool')
                  DropdownButtonFormField<String>(
                    initialValue: 'true',
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['true', 'false']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      valueController.text = v ?? 'true';
                    },
                  )
                else
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: 'Value',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: type == 'List<String>' ? '逗号分隔' : null,
                    ),
                    maxLines: type == 'String' ? 3 : 1,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final key = keyController.text;
                  if (key.isEmpty) return;

                  Object? val;
                  if (type == 'String') val = valueController.text;
                  if (type == 'int') val = int.tryParse(valueController.text);
                  if (type == 'double') {
                    val = double.tryParse(valueController.text);
                  }
                  if (type == 'bool') {
                    val = valueController.text.toLowerCase() == 'true';
                  }
                  if (type == 'List<String>') {
                    val = valueController.text.split(',').map((e) => e.trim()).toList();
                  }

                  if (val != null) {
                    _saveValue(key, val);
                    Navigator.pop(context);
                  }
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredData;

    return Scaffold(
      body: Column(
        children: [
          // macOS 窗口顶部间距（红黄绿按钮区域）
          if (Platform.isMacOS)
            const SizedBox(
              height: 38,
              child: DragToMoveArea(child: SizedBox()),
            ),

          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: kToolbarHeight,
            child: Row(
              children: [
                const BackButton(),
                const SizedBox(width: 8),
                const Text(
                  'Preferences',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _addNewPair,
                  icon: const Icon(Icons.add),
                  tooltip: '新增',
                ),
                IconButton(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search keys',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // 列表
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = list[index];
                final isJson =
                    entry.value is String && _isJsonString(entry.value as String);

                return ListTile(
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${_getPreviewText(entry.value)} (${_getTypeLabel(entry.value)}${isJson ? ' / JSON' : ''})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 类型图标
                      _buildTypeIcon(entry.value),
                      const SizedBox(width: 8),
                      // 删除按钮
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        tooltip: '删除',
                        onPressed: () => _confirmDelete(entry.key),
                      ),
                    ],
                  ),
                  onTap: () => _editValue(entry.key, entry.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类型图标
  Widget _buildTypeIcon(Object value) {
    IconData icon;
    Color color;

    if (value is bool) {
      icon = value ? Icons.check_circle : Icons.cancel;
      color = value ? Colors.green : Colors.red;
    } else if (value is int || value is double) {
      icon = Icons.tag;
      color = Colors.blue;
    } else if (value is String && _isJsonString(value)) {
      icon = Icons.data_object;
      color = Colors.orange;
    } else if (value is List) {
      icon = Icons.list;
      color = Colors.purple;
    } else {
      icon = Icons.text_fields;
      color = Colors.grey;
    }

    return Icon(icon, size: 20, color: color);
  }

  /// 确认删除对话框
  Future<void> _confirmDelete(String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要删除 "$key" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _prefs?.remove(key);
      _refreshData();
    }
  }
}
