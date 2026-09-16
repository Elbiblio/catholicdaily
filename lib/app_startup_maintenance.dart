/// Runs startup maintenance at most once and isolates failures from first
/// frame rendering. The retained Future lets callers observe lifecycle work
/// without making a second request start duplicate platform operations.
class AppStartupMaintenance {
  AppStartupMaintenance(this._task, {this.onError});

  final Future<void> Function() _task;
  final void Function(Object error, StackTrace stackTrace)? onError;
  Future<void>? _run;

  Future<void> run() => _run ??= _runGuarded();

  Future<void> _runGuarded() async {
    try {
      await _task();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }
}
