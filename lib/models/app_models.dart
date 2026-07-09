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

/// 启动模式。无卡对应 `StartCompShareInstance.WithoutGpuSpec`：
/// `A`=2核4G，`B`=8核16G；不传则为有卡启动。
enum StartMode {
  normal,
  noGpuA,
  noGpuB;

  String get label => switch (this) {
        StartMode.normal => '正常启动',
        StartMode.noGpuA => '无卡 A (2核4G)',
        StartMode.noGpuB => '无卡 B (8核16G)',
      };

  /// 传给启动接口的规格档位；`null` 表示有卡启动。
  String? get withoutGpuSpec => switch (this) {
        StartMode.normal => null,
        StartMode.noGpuA => 'A',
        StartMode.noGpuB => 'B',
      };

  bool get isWithoutGpu => withoutGpuSpec != null;

  static StartMode fromName(String name) {
    return StartMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => StartMode.normal,
    );
  }
}
