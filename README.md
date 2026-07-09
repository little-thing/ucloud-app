# CompShare Manager

优云智算 GPU 实例管理（iOS / macOS 通用，Flutter + Cupertino）。

## 功能

- 实例列表与状态轮询
- 多选 / 全选，一键启动、关闭、重启
- 所有启动动作均可选：正常 / 无卡 A（`WithoutGpuSpec=A`，2核4G）/ 无卡 B（`WithoutGpuSpec=B`，8核16G）
- 近 7 天运行日志（设置旁入口，倒序）
- API 密钥本地保存（自用）

## 运行

```bash
flutter pub get
flutter test
flutter run -d macos   # 或 iOS 真机 / 模拟器
```

在 App「设置」中填写控制台 API 公钥与私钥（`https://console.compshare.cn/uaccount/api_manage`）。

不依赖 App 常开的周期任务（每 5 天无卡启动再关闭）见 **[AUTOMATION.md](./AUTOMATION.md)**（Google Apps Script）。
