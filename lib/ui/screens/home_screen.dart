import "package:flutter/material.dart";
import "package:sms_sync/services/sync_service.dart";
import "package:sms_sync/ui/screens/settings_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sync = SyncService.instance;

  @override
  void initState() {
    super.initState();
    _sync.start();
  }

  @override
  void dispose() {
    _sync.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_sync.isRunning) {
      await _sync.stop();
    } else {
      await _sync.start();
    }
  }

  Future<void> _syncNow() async {
    await _sync.syncNow();
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return "Never";
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${diff.inDays}d ago";
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(String? result, ColorScheme cs) {
    switch (result) {
      case "success":
        return Colors.green;
      case "no_server":
      case "skipped":
        return cs.onSurfaceVariant;
      case null:
        return cs.onSurfaceVariant;
      default:
        return cs.error;
    }
  }

  String _statusLabel(String? result) {
    switch (result) {
      case "success":
        return "Synced";
      case "no_server":
        return "No server found";
      case "skipped":
        return "Skipped";
      case "permission_denied":
        return "Permission denied";
      case "failed":
        return "Failed";
      case "error":
        return "Error";
      default:
        return "—";
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SMS Sync"),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<Widget>(
                builder: (context) => const SettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _sync,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: .max,
              children: [
                const Spacer(),

                // Status Indicator
                Center(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _sync.isRunning
                              ? Icons.sync_outlined
                              : Icons.sync_disabled_outlined,
                          key: ValueKey(_sync.isRunning),
                          size: 64,
                          color: _sync.isRunning
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sync.isRunning ? "Sync Running" : "Sync Stopped",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _sync.isRunning
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (_sync.isRunning) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Last sync: ${_formatTimestamp(_sync.lastSyncTimestamp)}",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _statusColor(_sync.lastSyncResult, cs),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // ── Error banner ──────────────────────────────────────────────
                if (_sync.error != null)
                  Card(
                    margin: EdgeInsets.zero,
                    color: cs.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _sync.error!,
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Background sync error from last run ───────────────────────
                if (_sync.isRunning &&
                    _sync.lastSyncError != null &&
                    _sync.lastSyncResult != "success")
                  Card(
                    margin: EdgeInsets.zero,
                    color: cs.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, color: cs.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _sync.lastSyncError!,
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Sync instructions ────────────────────────────────────────
                Card(
                  margin: const EdgeInsets.all(0),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Background Sync:",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _statusColor(_sync.lastSyncResult, cs),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Status: ${_statusLabel(_sync.lastSyncResult)}",
                            ),
                          ],
                        ),
                        if (_sync.isRunning) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                "Interval: ${_sync.syncIntervalMinutes} min",
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    // ── Manual sync button ───────────────────────────────────────
                    Expanded(
                      flex: 1,
                      child: FilledButton(
                        onPressed: _syncNow,
                        child: const Icon(Icons.sync, size: 24),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ── Start / Stop button ───────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: FilledButton.icon(
                        onPressed: _toggle,
                        icon: Icon(
                          _sync.isRunning
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outlined,
                        ),
                        label: Text(
                          _sync.isRunning ? "Stop Sync" : "Start Sync",
                        ),
                        style: _sync.isRunning
                            ? FilledButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
