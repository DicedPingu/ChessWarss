import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final result = await Process.run('flutter', ['pub', 'outdated', '--json']);
  if (result.exitCode != 0) {
    stderr.writeln('Failed to run "flutter pub outdated --json".');
    stderr.write(result.stderr);
    exitCode = result.exitCode;
    return;
  }

  final stdoutText = (result.stdout as String).trim();
  if (stdoutText.isEmpty) {
    stderr.writeln('No JSON output returned by pub outdated.');
    exitCode = 2;
    return;
  }

  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(stdoutText) as Map<String, dynamic>;
  } on FormatException catch (error) {
    stderr.writeln('Could not parse pub outdated JSON: $error');
    stderr.writeln(stdoutText);
    exitCode = 2;
    return;
  }

  final packages = (payload['packages'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .toList();

  final discontinued = <Map<String, dynamic>>[];
  final retracted = <Map<String, dynamic>>[];
  final advisoryAffected = <Map<String, dynamic>>[];

  for (final pkg in packages) {
    if (pkg['isDiscontinued'] == true) {
      discontinued.add(pkg);
    }
    if (pkg['isCurrentRetracted'] == true) {
      retracted.add(pkg);
    }
    if (pkg['isCurrentAffectedByAdvisory'] == true) {
      advisoryAffected.add(pkg);
    }
  }

  if (discontinued.isEmpty && retracted.isEmpty && advisoryAffected.isEmpty) {
    stdout.writeln(
      'Dependency check passed: no discontinued, retracted, or advisory-affected packages in current lockfile.',
    );
    return;
  }

  void printSet(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return;
    }
    stderr.writeln(title);
    for (final pkg in items) {
      final name = pkg['package'] as String? ?? 'unknown';
      final kind = pkg['kind'] as String? ?? 'unknown';
      final version =
          (pkg['current'] as Map<String, dynamic>?)?['version'] ?? 'unknown';
      stderr.writeln('- $name ($kind) current=$version');
    }
  }

  printSet('Discontinued packages found:', discontinued);
  printSet('Retracted current versions found:', retracted);
  printSet('Security advisory affected versions found:', advisoryAffected);
  exitCode = 1;
}
