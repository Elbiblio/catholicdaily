import 'dart:io';

/// Serializes file-backed mutations across UI and background isolates/processes.
class InterprocessFileLock {
  InterprocessFileLock({
    File? file,
    this.retryDelay = const Duration(milliseconds: 50),
    this.staleAfter = const Duration(minutes: 30),
  }) : _file =
           file ??
           File(
             '${Directory.systemTemp.path}${Platform.pathSeparator}'
             'catholic-daily-feast-reminder-schedule.lock',
           );

  final File _file;
  final Duration retryDelay;
  final Duration staleAfter;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final owner =
        '$pid-${DateTime.now().microsecondsSinceEpoch}-'
        '${identityHashCode(operation)}';
    await _acquire(owner);
    try {
      return await operation();
    } finally {
      try {
        if (await _file.exists() && await _file.readAsString() == owner) {
          await _file.delete();
        }
      } on FileSystemException {
        // Another isolate can replace a stale lease between the ownership
        // check and delete. Never remove a lease we no longer own.
      }
    }
  }

  Future<void> _acquire(String owner) async {
    while (true) {
      try {
        await _file.create(exclusive: true);
        await _file.writeAsString(owner, flush: true);
        return;
      } on FileSystemException {
        if (await _isStale()) {
          try {
            await _file.delete();
          } on FileSystemException {
            // A competing isolate already replaced or removed the stale file.
          }
        } else {
          await Future<void>.delayed(retryDelay);
        }
      }
    }
  }

  Future<bool> _isStale() async {
    try {
      final modified = await _file.lastModified();
      return DateTime.now().difference(modified) > staleAfter;
    } on FileSystemException {
      return false;
    }
  }
}

/// Backwards-compatible name for the feast reminder schedule lock.
class FeastReminderScheduleLock extends InterprocessFileLock {
  FeastReminderScheduleLock({super.file, super.retryDelay, super.staleAfter});
}
