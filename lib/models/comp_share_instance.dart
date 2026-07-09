class CompShareInstance {
  const CompShareInstance({
    required this.uHostId,
    required this.name,
    required this.state,
    required this.zone,
    required this.region,
    this.gpu = 0,
    this.gpuType = '',
    this.cpu = 0,
    this.memoryMb = 0,
    this.isSpot = false,
    this.supportWithoutGpuStart = false,
    this.chargeType = '',
    this.osName = '',
    this.remark = '',
    this.schedulerStopTime,
  });

  final String uHostId;
  final String name;
  final String state;
  final String zone;
  final String region;
  final int gpu;
  final String gpuType;
  final int cpu;
  final int memoryMb;
  final bool isSpot;
  final bool supportWithoutGpuStart;
  final String chargeType;
  final String osName;
  final String remark;
  final int? schedulerStopTime;

  bool get isRunning => state == 'Running';
  bool get isStopped => state == 'Stopped';
  bool get isTransitioning =>
      state == 'Starting' ||
      state == 'Stopping' ||
      state == 'Rebooting' ||
      state == 'Install';

  bool get canStart => isStopped;
  bool get canStop => isRunning;
  bool get canReboot => isRunning;

  String get displayGpu {
    if (gpuType.isEmpty && gpu == 0) return '无 GPU 信息';
    if (gpuType.isEmpty) return '$gpu 卡';
    return '$gpuType × $gpu';
  }

  String get memoryGb {
    if (memoryMb <= 0) return '-';
    final gb = memoryMb / 1024;
    return gb == gb.roundToDouble()
        ? '${gb.toInt()} GB'
        : '${gb.toStringAsFixed(1)} GB';
  }

  factory CompShareInstance.fromJson(Map<String, dynamic> json) {
    return CompShareInstance(
      uHostId: (json['UHostId'] ?? '').toString(),
      name: (json['Name'] ?? '').toString(),
      state: (json['State'] ?? '').toString(),
      zone: (json['Zone'] ?? '').toString(),
      region: (json['Region'] ?? '').toString(),
      gpu: _asInt(json['GPU']),
      gpuType: (json['GpuType'] ?? '').toString(),
      cpu: _asInt(json['CPU']),
      memoryMb: _asInt(json['Memory']),
      isSpot: json['IsSpot'] == true,
      supportWithoutGpuStart: json['SupportWithoutGpuStart'] == true,
      chargeType: (json['ChargeType'] ?? '').toString(),
      osName: (json['OsName'] ?? '').toString(),
      remark: (json['Remark'] ?? '').toString(),
      schedulerStopTime: json['SchedulerStopTime'] == null
          ? null
          : _asInt(json['SchedulerStopTime']),
    );
  }

  Map<String, dynamic> toJson() => {
        'UHostId': uHostId,
        'Name': name,
        'State': state,
        'Zone': zone,
        'Region': region,
        'GPU': gpu,
        'GpuType': gpuType,
        'CPU': cpu,
        'Memory': memoryMb,
        'IsSpot': isSpot,
        'SupportWithoutGpuStart': supportWithoutGpuStart,
        'ChargeType': chargeType,
        'OsName': osName,
        'Remark': remark,
        'SchedulerStopTime': schedulerStopTime,
      };

  CompShareInstance copyWith({String? state}) {
    return CompShareInstance(
      uHostId: uHostId,
      name: name,
      state: state ?? this.state,
      zone: zone,
      region: region,
      gpu: gpu,
      gpuType: gpuType,
      cpu: cpu,
      memoryMb: memoryMb,
      isSpot: isSpot,
      supportWithoutGpuStart: supportWithoutGpuStart,
      chargeType: chargeType,
      osName: osName,
      remark: remark,
      schedulerStopTime: schedulerStopTime,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
