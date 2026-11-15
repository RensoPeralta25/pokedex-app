import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/domain/connectivity_service.dart';
import '../core/domain/sync_activity_monitor.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/catalog/domain/catalog_snapshot.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({
    super.key,
    required this.connectivity,
    required this.syncActivity,
    required this.catalog,
    this.now,
  });

  final ConnectivityService connectivity;
  final SyncActivityMonitor syncActivity;
  final CatalogRepository catalog;
  final DateTime Function()? now;

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  late Stream<ConnectivityStatus> _status;
  late Stream<SyncActivity> _activity;
  late Stream<CatalogSnapshot> _catalog;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ConnectivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectivity != widget.connectivity ||
        oldWidget.syncActivity != widget.syncActivity ||
        oldWidget.catalog != widget.catalog) {
      _subscribe();
    }
  }

  void _subscribe() {
    _status = widget.connectivity.watchStatus();
    _activity = widget.syncActivity.watchActivity();
    _catalog = widget.catalog.watchCatalog();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ConnectivityStatus>(
    stream: _status,
    builder: (context, status) => StreamBuilder<SyncActivity>(
      stream: _activity,
      builder: (context, activity) => StreamBuilder<CatalogSnapshot>(
        stream: _catalog,
        builder: (context, catalog) => _IndicatorBar(
          state: IndicatorState.from(
            status.data ?? ConnectivityStatus.unknown,
            activity.data ?? SyncActivity.idle,
          ),
          detail: dataFreshnessLabel(
            catalog.data?.lastUpdated,
            (widget.now ?? DateTime.now)(),
          ),
        ),
      ),
    ),
  );
}

enum IndicatorState {
  checking('Verificando conexión…', Icons.wifi_find, _grey),
  online('En línea', Icons.cloud_done_outlined, _green),
  syncing('Sincronizando…', Icons.sync, _blue),
  offline('Sin conexión', Icons.cloud_off_outlined, _grey),
  serviceUnavailable('Servicio no disponible', Icons.warning_amber, _amber);

  const IndicatorState(this.label, this.icon, this.colors);

  final String label;
  final IconData icon;
  final ({Color background, Color foreground}) colors;

  static IndicatorState from(
    ConnectivityStatus status,
    SyncActivity activity,
  ) => switch (status) {
    ConnectivityStatus.unknown => checking,
    ConnectivityStatus.offline => offline,
    ConnectivityStatus.serviceUnavailable => serviceUnavailable,
    ConnectivityStatus.online =>
      activity == SyncActivity.syncing ? syncing : online,
  };
}

const _grey = (background: Color(0xFFECEFF1), foreground: Color(0xFF37474F));
const _green = (background: Color(0xFFE6F4EA), foreground: Color(0xFF1E5631));
const _blue = (background: Color(0xFFE3F0FB), foreground: Color(0xFF0B4F8A));
const _amber = (background: Color(0xFFFFF4E5), foreground: Color(0xFF7A4100));

String dataFreshnessLabel(DateTime? lastUpdated, DateTime now) {
  if (lastUpdated == null) return 'Sin datos guardados';
  final local = lastUpdated.toLocal();
  final today = now.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  final when = sameDay ? time : '${two(local.day)}/${two(local.month)} $time';
  return 'Última actualización: $when';
}

class _IndicatorBar extends StatelessWidget {
  const _IndicatorBar({required this.state, required this.detail});

  final IndicatorState state;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = state.colors;
    final textTheme = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Estado de conexión: ${state.label}. $detail',
        child: ExcludeSemantics(
          child: Material(
            color: colors.background,
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  key: ValueKey(state),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: state == IndicatorState.syncing
                            ? Padding(
                                padding: const EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.foreground,
                                ),
                              )
                            : Icon(
                                state.icon,
                                size: 20,
                                color: colors.foreground,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.label,
                              style: textTheme.labelLarge?.copyWith(
                                color: colors.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              detail,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
