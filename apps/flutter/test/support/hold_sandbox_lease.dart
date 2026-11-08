import 'dart:io';

/// Helper executed in a *separate Dart VM* by the sandbox lease tests.
/// Only owns an advisory OS file lock. No imports from the application.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Expected sandbox directory');
    exitCode = 2;
    return;
  }
  final file = File('${args.single}${Platform.pathSeparator}exclusive.lock');
  final handle = await file.open(mode: FileMode.append);
  try {
    await handle.lock(FileLock.exclusive);
    stdout.writeln('LOCKED');
    await stdout.flush();
    await stdin.first;
  } finally {
    await handle.unlock();
    await handle.close();
  }
}
