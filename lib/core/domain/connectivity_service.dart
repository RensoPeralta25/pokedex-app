/// online indica disponibilidad de red, no garantiza acceso al servidor.
enum ConnectivityStatus { unknown, online, offline }

abstract interface class ConnectivityService {
  /// Emite el estado actual y los cambios. unknown evita asumir conexión.
  Stream<ConnectivityStatus> watchStatus();
}
