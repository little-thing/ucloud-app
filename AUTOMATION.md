# CompShare 定时自动化方案

## 目标

对优云智算（CompShare）实例按固定周期执行：

1. 找出所有 **已关机**（`Stopped`）的实例  
2. 以 **无卡模式**（`WithoutGpuSpec=A`，2核4G）启动  
3. 启动成功后再 **关闭**

不依赖本机 App 是否打开；Mac / iOS 退出后定时仍会执行。

## 为什么不用 App 本地定时

App 内「每 N 天」规则跑在进程里（见主 README「定时说明」）：

| 环境 | 行为 |
|------|------|
| macOS | 需保持 App 运行，退出后到点不执行 |
| iOS | 后台/锁屏不可靠，杀掉后一定不执行 |

CompShare 也没有「每 N 天」的平台侧周期任务 API，因此周期调度要放在外部定时环境。

## 选定方案：Google Apps Script

| 项 | 说明 |
|----|------|
| 平台 | [Google Apps Script](https://script.google.com)（免费额度足够自用） |
| 本地目录 | `gas/` |
| CLI | [clasp](https://github.com/google/clasp) |
| 时区 | `Asia/Shanghai` |
| 周期 | 每 **5** 天，约凌晨 **3** 点 |
| API | `https://api.compshare.cn`，地域 `cn-wlcb` |
| 签名 | UCloud 规则：参数按 key 升序拼接 `key+value`，末尾加 PrivateKey，再 SHA1 hex |

已创建的远程项目：

https://script.google.com/d/1QIzj2U-RQB4_TiFGYCf5mDyeEy4zbM8rR04lJ6m37wkygJW-wcD4JzPd/edit

## 执行流程

```text
时间触发（每 5 天 03:00）
        │
        ▼
  DescribeCompShareInstance（拉全量列表）
        │
        ▼
  筛选 State === Stopped
        │
        ▼
  StartCompShareInstance（WithoutGpuSpec=A）
        │
        ▼
  轮询至 Running
        │
        ▼
  StopCompShareInstance
        │
        ▼
  轮询至 Stopped
```

- **已在 Running 的实例不会被改动**（本轮只处理关机实例）。  
- 单次执行有时长上限（约 6 分钟）；实例很多或启停很慢时可能超时，可分批或拉长间隔后再跑。

## 脚本函数

| 函数 | 职责 |
|------|------|
| `setupSecrets` | 将 PublicKey / PrivateKey 写入脚本属性 |
| `testList` | 只列实例，不开关机 |
| `testOneCycle` | 对单个目标实例做无卡开→关冒烟（默认 `uhost-1mafdpxctojn`） |
| `runCycle` | 正式任务：所有 `Stopped` 实例无卡开→关 |
| `installTrigger` | 安装「每 5 天」时间触发器 |

实现文件：`gas/Code.js`。更短的操作备忘见 `gas/README.md`。

## 首次配置

1. 开启 Apps Script API：https://script.google.com/home/usersettings  
2. 本机登录 clasp：`clasp login`  
3. 进入 `gas/`，确认已有 `.clasp.json`（本地忽略，不入库）；若是新环境可 `clasp clone <scriptId>`  
4. 推送代码：`clasp push`  
5. 打开远程编辑器，按下面「手动试跑」执行一次并授权

密钥与 `test_compshare.py` / 控制台 API 密钥一致；`setupSecrets` 会写入脚本属性，首次调 API 时也会自动补写。

## 手动试跑（验证全量）

1. 打开远程编辑器链接（见上）  
2. 运行 `testList`，确认哪些是 `Stopped`  
3. 运行 `runCycle`：对**所有已关机**实例执行无卡启动再关闭  
4. 在「查看 → 执行情况」看日志  

只想动一台时用 `testOneCycle`，不要直接跑 `runCycle`。

确认无误后运行 `installTrigger`，之后按周期自动执行。

## 本地改代码后同步

```bash
cd gas
clasp push
```

刷新网页编辑器即可看到最新代码。`.clasp.json`、本机 `~/.clasprc.json` 已在 `.gitignore` 中忽略。

## 与 Flutter App 的关系

| 能力 | App | Google Apps Script |
|------|-----|-------------------|
| 列表 / 手动启停 / 无卡启动 | ✅ | 定时批量用 |
| 本地「每 N 天」规则 | ✅（需常开） | — |
| 不依赖手机/电脑常开的周期任务 | — | ✅ |

App 继续做人机操作与本机规则；**可靠的周期无卡开→关**以本方案为准。

## 相关文件

| 路径 | 说明 |
|------|------|
| `gas/Code.js` | 自动化脚本 |
| `gas/appsscript.json` | 时区、OAuth 权限 |
| `gas/README.md` | 编辑器操作备忘 |
| `test_compshare.py` | Python API 验证（密钥/地域参考） |
| `lib/services/ucloud_signer.dart` | App 侧同一套签名规则 |
