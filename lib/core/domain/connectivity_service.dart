/// `serviceUnavailable`: hay red, pero la API no responde correctamente.
enum ConnectivityStatus { unknown, online, offline, serviceUnavailable }

abstract interface class ConnectivityService {
  Stream<ConnectivityStatus> watchStatus();
}
