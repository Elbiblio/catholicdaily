/// Base class for singleton services to reduce boilerplate
abstract class BaseService<T> {
  static final Map<Type, dynamic> _instances = {};
  
  /// Get singleton instance
  static T getInstance<T extends BaseService<T>>() {
    final type = T;
    if (!_instances.containsKey(type)) {
      throw UnimplementedError('Service $type must be initialized first');
    }
    return _instances[type] as T;
  }
  
  /// Initialize singleton - call this in concrete class static getter
  static T init<T extends BaseService<T>>(T Function() creator) {
    if (!_instances.containsKey(T)) {
      _instances[T] = creator();
    }
    return _instances[T] as T;
  }
}
