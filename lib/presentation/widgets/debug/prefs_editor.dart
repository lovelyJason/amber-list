import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart'; // Add window_manager
import 'dart:io'; // Add dart:io

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
    return _data.entries.where((e) => e.key.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> _editValue(String key, Object value) async {
    final controller = TextEditingController(text: value.toString());
    String typeLabel = 'Unknown';
    if (value is String) typeLabel = 'String';
    if (value is bool) typeLabel = 'bool';
    if (value is int) typeLabel = 'int';
    if (value is double) typeLabel = 'double';
    if (value is List<String>) typeLabel = 'List<String>';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit "$key" ($typeLabel)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value is bool)
              DropdownButton<bool>(
                value: value,
                items: const [
                  DropdownMenuItem(value: true, child: Text('true')),
                  DropdownMenuItem(value: false, child: Text('false')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _saveValue(key, v);
                    Navigator.pop(context);
                  }
                },
              )
            else
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (value is! bool)
            TextButton(
              onPressed: () {
                Object? newValue;
                if (value is int) newValue = int.tryParse(controller.text);
                if (value is double) newValue = double.tryParse(controller.text);
                if (value is String) newValue = controller.text;
                if (value is List<String>) {
                   // Simple CSV parsing for list
                   newValue = controller.text.split(',').map((e) => e.trim()).toList();
                }

                if (newValue != null) {
                  _saveValue(key, newValue);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
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
    String key = '';
    String type = 'String';
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Key-Value'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 TextField(
                   controller: keyController,
                   decoration: const InputDecoration(labelText: 'Key'),
                 ),
                 const SizedBox(height: 8),
                 DropdownButton<String>(
                   value: type,
                   isExpanded: true,
                   items: ['String', 'bool', 'int', 'double', 'List<String>']
                       .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                       .toList(),
                   onChanged: (v) {
                     if (v != null) setDialogState(() => type = v);
                   },
                 ),
                 const SizedBox(height: 8),
                 TextField(
                   controller: valueController,
                    decoration: const InputDecoration(labelText: 'Value'),
                 ),
              ],
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
               TextButton(
                 onPressed: () {
                   key = keyController.text;
                   if (key.isEmpty) return;
                   
                   Object? val;
                   if (type == 'String') val = valueController.text;
                   if (type == 'int') val = int.tryParse(valueController.text);
                   if (type == 'double') val = double.tryParse(valueController.text);
                   if (type == 'bool') val = valueController.text.toLowerCase() == 'true';
                   if (type == 'List<String>') val = valueController.text.split(',');
                   
                   if (val != null) {
                     _saveValue(key, val);
                     Navigator.pop(context);
                   }
                 },
                 child: const Text('Add'),
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
          // Handle macOS traffic lights area
          if (Platform.isMacOS)
            const SizedBox(
              height: 38, // Approx height for traffic lights
              child: DragToMoveArea(
                child: SizedBox(), // Transparent draggable area
              ),
            ),

          // Custom AppBar-like header
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
                IconButton(onPressed: _addNewPair, icon: const Icon(Icons.add)),
                IconButton(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search bar
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
          
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = list[index];
                return ListTile(
                  title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${entry.value} (${entry.value.runtimeType})'),
                  onTap: () => _editValue(entry.key, entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Key?'),
                          content: Text(
                            'Are you sure you want to delete "${entry.key}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _prefs?.remove(entry.key);
                        _refreshData();
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
