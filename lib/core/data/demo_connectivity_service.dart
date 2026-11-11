import '../domain/connectivity_service.dart';

/// No inspecciona el dispositivo ni simula acceso real a Internet.
final class DemoConnectivityService implements ConnectivityService {
  @override
  Stream<ConnectivityStatus> watchStatus() =>
      Stream.value(ConnectivityStatus.unknown);
}
