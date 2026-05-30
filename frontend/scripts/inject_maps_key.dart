// key.properties 에서 API 키를 읽어 web/index.html 을 치환합니다.
// (프로젝트 루트에서 실행)
//
// 사용법:
//   개발 시 (flutter run):  dart run scripts/inject_maps_key.dart run
//   빌드 시 (build web):   dart run scripts/inject_maps_key.dart build
//                          또는  dart run scripts/inject_maps_key.dart

import 'dart:io';

const PLACEHOLDER = 'MAPS_API_KEY_PLACEHOLDER';
const KEY_PROPERTIES_PATH = 'key.properties';
const INDEX_HTML_PATH = 'web/index.html';

void main(List<String> args) async {
  final isRunMode = args.isEmpty || args.first == 'run';
  final isBuildMode = args.isNotEmpty && args.first == 'build';

  final projectRoot = Directory.current;
  final keyPropertiesFile = File('${projectRoot.path}/$KEY_PROPERTIES_PATH');
  final indexHtmlFile = File('${projectRoot.path}/$INDEX_HTML_PATH');

  if (!keyPropertiesFile.existsSync()) {
    stderr.writeln('오류: $KEY_PROPERTIES_PATH 파일이 없습니다.');
    stderr.writeln(
        'key.properties.example 을 복사하여 key.properties 를 만들고 API 키를 입력하세요.');
    exit(1);
  }

  if (!indexHtmlFile.existsSync()) {
    stderr.writeln('오류: $INDEX_HTML_PATH 파일이 없습니다.');
    exit(1);
  }

  final keyProperties = keyPropertiesFile.readAsStringSync();
  final match = RegExp(r'MAPS_API_KEY=(.+)').firstMatch(keyProperties);
  final mapsApiKey = match != null ? match.group(1)?.trim() ?? '' : '';

  if (mapsApiKey.isEmpty) {
    stderr.writeln('오류: key.properties 에 MAPS_API_KEY 가 정의되어 있지 않습니다.');
    exit(1);
  }

  var indexHtml = indexHtmlFile.readAsStringSync();
  if (!indexHtml.contains(PLACEHOLDER)) {
    stderr.writeln('경고: $INDEX_HTML_PATH 에 $PLACEHOLDER 가 없습니다.');
    exit(0);
  }

  // 1. 플레이스홀더를 실제 키로 치환
  indexHtml = indexHtml.replaceAll(PLACEHOLDER, mapsApiKey);
  indexHtmlFile.writeAsStringSync(indexHtml);

  void restoreFile() {
    final current = indexHtmlFile.readAsStringSync();
    final restored = current.replaceAll(mapsApiKey, PLACEHOLDER);
    indexHtmlFile.writeAsStringSync(restored);
    stdout.writeln('완료: web/index.html 이 플레이스홀더로 복원되었습니다.');
  }

  try {
    if (isRunMode) {
      stdout.writeln('flutter run 실행 중... (종료 시 Ctrl+C)');
      final process = await Process.start(
        'flutter',
        ['run', '-d', 'chrome'],
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
        workingDirectory: projectRoot.path,
      );
      await process.exitCode;
    } else {
      stdout.writeln('flutter build web 실행 중...');
      final result = await Process.run(
        'flutter',
        ['build', 'web'],
        runInShell: true,
        workingDirectory: projectRoot.path,
      );
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      exit(result.exitCode);
    }
  } finally {
    restoreFile();
  }
}
