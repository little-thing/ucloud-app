# CompShare Manager

优云智算 GPU 实例管理（iOS / macOS 通用，Flutter + Cupertino）。

## 功能

- 实例列表与状态轮询
- 多选 / 全选，一键启动、关闭、重启
- 启动模式：正常 / 无卡（`WithoutGpu`）
- 本地「每 N 天」批量重启或关闭规则
- API 密钥本地保存（自用）

## 运行

```bash
flutter pub get
flutter test
flutter run -d macos   # 或 iOS 真机 / 模拟器
```

在 App「设置」中填写控制台 API 公钥与私钥（`https://console.compshare.cn/uaccount/api_manage`）。

## 说明

定时规则由 App 进程内调度；Mac 保持运行更可靠。平台无「每 N 天」周期 API。
