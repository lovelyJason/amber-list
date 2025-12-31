import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pages/sticky_note/sticky_note_registry.dart';

class StickyNoteDebugger extends ConsumerStatefulWidget {
  const StickyNoteDebugger({super.key});

  @override
  ConsumerState<StickyNoteDebugger> createState() => _StickyNoteDebuggerState();
}

class _StickyNoteDebuggerState extends ConsumerState<StickyNoteDebugger> with SingleTickerProviderStateMixin {
  List<int> _osWindowIds = [];
  Map<int, String> _pingResults = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      setState(() {
        _osWindowIds = ids;
        _pingResults.clear();
      });
    } catch (e) {
      debugPrint('Failed to get sub windows: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ping(int windowId) async {
    setState(() => _pingResults[windowId] = 'Pinging...');
    try {
      await DesktopMultiWindow.invokeMethod(windowId, 'ping', null)
          .timeout(const Duration(milliseconds: 500));
      setState(() => _pingResults[windowId] = 'Alive (Pong)');
    } catch (e) {
      setState(() => _pingResults[windowId] = 'Dead (Timeout)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(stickyNoteRegistryProvider);

    return Container(
      width: 600,
      height: 700,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          // === Header ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50), // Dark slate
            ),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  '便签状态监控',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: '刷新状态',
                  child: IconButton(
                    icon: _isLoading 
                        ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: _isLoading ? null : _refresh,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // === Content ===
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Left: Application Registry ---
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('应用注册表 (Registry)', Icons.list_alt, Colors.blue),
                        Expanded(
                          child: registry.isEmpty
                              ? _buildEmptyState('注册表为空')
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: registry.entries.length,
                                  itemBuilder: (context, index) {
                                    final entry = registry.entries.elementAt(index);
                                    return _buildRegistryCard(entry.key, entry.value);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Right: OS Windows ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('系统窗口进程 (OS)', Icons.desktop_mac, Colors.orange),
                      Expanded(
                        child: _osWindowIds.isEmpty
                            ? _buildEmptyState('无子窗口运行')
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _osWindowIds.length,
                                itemBuilder: (context, index) {
                                  final id = _osWindowIds[index];
                                  final isRegistered = registry.containsValue(id);
                                  return _buildWindowCard(id, isRegistered);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRegistryCard(String listId, int windowId) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50.withOpacity(0.5),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text('List: $listId', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        subtitle: Text('Mapped ID: $windowId', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: () {
             ref.read(stickyNoteRegistryProvider.notifier).unregister(listId);
          },
          tooltip: '移除记录',
        ),
      ),
    );
  }

  Widget _buildWindowCard(int windowId, bool isRegistered) {
    final pingStatus = _pingResults[windowId];
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    
    if (pingStatus != null) {
      if (pingStatus.startsWith('Alive')) {
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (pingStatus.startsWith('Dead')) {
        statusColor = Colors.red;
        statusIcon = Icons.error;
      } else {
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
      }
    }

    return Card(
      elevation: 0,
      color: isRegistered ? Colors.green.shade50.withOpacity(0.3) : Colors.orange.shade50.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isRegistered ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               children: [
                 Icon(Icons.window, size: 16, color: Colors.grey.shade700),
                 const SizedBox(width: 8),
                 Text('Window #$windowId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                 const Spacer(),
                 if (isRegistered)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                     child: const Text('已注册', style: TextStyle(color: Colors.white, fontSize: 10)),
                   )
                 else
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                     child: const Text('未注册', style: TextStyle(color: Colors.white, fontSize: 10)),
                   ),
               ],
             ),
             const SizedBox(height: 8),
             Row(
               children: [
                 Icon(statusIcon, size: 14, color: statusColor),
                 const SizedBox(width: 4),
                 Text(pingStatus ?? '未知状态', style: TextStyle(color: statusColor, fontSize: 12)),
                 const Spacer(),
                 SizedBox(
                   height: 24,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(horizontal: 8),
                       backgroundColor: Colors.white,
                       foregroundColor: Colors.black87,
                       elevation: 0,
                       side: BorderSide(color: Colors.grey.shade300),
                     ),
                     onPressed: () => _ping(windowId),
                     child: const Text('Ping', style: TextStyle(fontSize: 12)),
                   ),
                 ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    onPressed: () async {
                      await DesktopMultiWindow.invokeMethod(
                        windowId,
                        'close',
                        null,
                      ); // Soft close
                      await Future.delayed(const Duration(milliseconds: 200));
                      _refresh();
                    },
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
                  ),
                ),
               ],
             ),
          ],
        ),
      ),
    );
  }
}
