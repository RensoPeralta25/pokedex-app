import '../domain/connectivity_service.dart';
import 'demo_value.dart';

final class DemoConnectivityService implements ConnectivityService {
  DemoConnectivityService([
    ConnectivityStatus initial = ConnectivityStatus.unknown,
  ]) : _status = DemoValue(initial);

  final DemoValue<ConnectivityStatus> _status;

  @override
  Stream<ConnectivityStatus> watchStatus() => _status.watch();

  void set(ConnectivityStatus status) => _status.update(status);

  Future<void> dispose() => _status.dispose();
}
