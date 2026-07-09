class ApiCredentials {
  const ApiCredentials({
    required this.publicKey,
    required this.privateKey,
    this.region = 'cn-wlcb',
    this.baseUrl = 'https://api.compshare.cn',
  });

  final String publicKey;
  final String privateKey;
  final String region;
  final String baseUrl;

  bool get isConfigured =>
      publicKey.trim().isNotEmpty && privateKey.trim().isNotEmpty;

  ApiCredentials copyWith({
    String? publicKey,
    String? privateKey,
    String? region,
    String? baseUrl,
  }) {
    return ApiCredentials(
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      region: region ?? this.region,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}

class BatchOpResult {
  const BatchOpResult({
    required this.succeeded,
    required this.skipped,
    required this.failed,
  });

  final List<String> succeeded;
  final List<String> skipped;
  final List<({String id, String reason})> failed;

  int get total => succeeded.length + skipped.length + failed.length;

  String summary(String actionLabel) {
    final parts = <String>[
      '$actionLabel完成 ${succeeded.length} 台',
    ];
    if (skipped.isNotEmpty) parts.add('跳过 ${skipped.length}');
    if (failed.isNotEmpty) parts.add('失败 ${failed.length}');
    return parts.join(' · ');
  }
}

enum StartMode {
  normal,
  noGpu;

  String get label => switch (this) {
        StartMode.normal => '正常启动',
        StartMode.noGpu => '无卡模式',
      };

  bool get withoutGpu => this == StartMode.noGpu;
}
