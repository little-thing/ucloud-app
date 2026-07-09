# CompShare Manager

优云智算 GPU 实例管理（iOS / macOS 通用，Flutter + Cupertino）。

## 功能

- 实例列表与状态轮询
- 多选 / 全选，一键启动、关闭、重启
- 所有启动动作均可选：正常 / 无卡（`WithoutGpu`）
- 本地「每 N 天」批量启动或关闭（启动规则同样可选正常/无卡；已运行则跳过）
- API 密钥本地保存（自用）

## 运行

```bash
flutter pub get
flutter test
flutter run -d macos   # 或 iOS 真机 / 模拟器
```

在 App「设置」中填写控制台 API 公钥与私钥（`https://console.compshare.cn/uaccount/api_manage`）。

## 定时说明

定时规则由 App 进程内调度，**需要软件保持运行**。退出或被系统杀掉后，到点不会执行。

- Mac：保持 App 开着较稳
- iOS：切后台/锁屏后调度不可靠，退出后一定不生效
