import 'dart:async';

/// Estado observable en memoria, exclusivo de las implementaciones demo.
final class DemoValue<T> {
  DemoValue(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast(sync: true);

  T get value => _value;

  Stream<T> watch() => Stream<T>.multi((listener) {
    final subscription = _changes.stream.listen(
      listener.addSync,
      onError: listener.addErrorSync,
      onDone: listener.closeSync,
    );
    listener.add(_value);
    listener.onCancel = subscription.cancel;
  });

  void update(T value) {
    _value = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
