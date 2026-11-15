import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/connectivity_service.dart';
import 'graphql_health_check.dart';

typedef ServiceCheck = Future<ConnectivityStatus> Function();

final class ApiConnectivityService implements ConnectivityService {
  ApiConnectivityService({
    required this.networkChanges,
    required this.hasNetwork,
    required this.checkService,
    this.pollInterval = const Duration(seconds: 30),
    this.confirmDelay = const Duration(seconds: 3),
  });

  factory ApiConnectivityService.forDevice(Uri endpoint) {
    final connectivity = Connectivity();
    bool available(List<ConnectivityResult> results) =>
        results.any((result) => result != ConnectivityResult.none);
    return ApiConnectivityService(
      networkChanges: connectivity.onConnectivityChanged.map(available),
      hasNetwork: () => connectivity.checkConnectivity().then(available),
      checkService: () => checkGraphqlService(endpoint),
    );
  }

  final Stream<bool> networkChanges;
  final Future<bool> Function() hasNetwork;
  final ServiceCheck checkService;
  final Duration pollInterval;
  final Duration confirmDelay;

  final _changes = StreamController<ConnectivityStatus>.broadcast(sync: true);
  ConnectivityStatus _status = ConnectivityStatus.unknown;
  bool _started = false;
  bool _disposed = false;
  bool _networkAvailable = false;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _pollTimer;
  Timer? _confirmTimer;
  Future<ConnectivityStatus>? _pendingCheck;

  ConnectivityStatus get current => _status;

  @override
  Stream<ConnectivityStatus> watchStatus() {
    _start();
    return Stream<ConnectivityStatus>.multi((listener) {
      final subscription = _changes.stream.listen(listener.addSync);
      listener.add(_status);
      listener.onCancel = subscription.cancel;
    });
  }

  void _start() {
    if (_started) return;
    _started = true;
    _networkSubscription = networkChanges.listen(_onNetwork);
    hasNetwork().then(_onNetwork, onError: (Object _) => _onNetwork(true));
  }

  void _onNetwork(bool available) {
    if (_disposed) return;
    _networkAvailable = available;
    if (!available) {
      _stopTimers();
      _set(ConnectivityStatus.offline);
      return;
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => _check());
    _check();
  }

  Future<void> _check({bool confirming = false}) async {
    final result = await _runCheck();
    if (_disposed || !_networkAvailable) return;

    // Perder `online` exige dos fallos seguidos para evitar parpadeos.
    if (result == ConnectivityStatus.online ||
        _status != ConnectivityStatus.online ||
        confirming) {
      _confirmTimer?.cancel();
      _confirmTimer = null;
      _set(result);
      return;
    }
    _confirmTimer ??= Timer(confirmDelay, () {
      _confirmTimer = null;
      _check(confirming: true);
    });
  }

  Future<ConnectivityStatus> _runCheck() {
    return _pendingCheck ??= checkService()
        .catchError((Object _) => ConnectivityStatus.serviceUnavailable)
        .whenComplete(() => _pendingCheck = null);
  }

  void _set(ConnectivityStatus status) {
    if (status == _status) return;
    _status = status;
    _changes.add(status);
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _confirmTimer?.cancel();
    _confirmTimer = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _stopTimers();
    await _networkSubscription?.cancel();
    await _changes.close();
  }
}
