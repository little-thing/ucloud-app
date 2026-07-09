# CompShare Google Apps Script

每 5 天对所有已关机实例：无卡启动 → 再关机。

项目已创建并 push：  
https://script.google.com/d/1QIzj2U-RQB4_TiFGYCf5mDyeEy4zbM8rR04lJ6m37wkygJW-wcD4JzPd/edit

本地 Node 冒烟已通过（`uhost-1mafdpxctojn` 无卡开→关）。

## 在网页编辑器测试（推荐）

1. 打开上面链接（用 `zc1107589563@gmail.com` 登录）
2. 顶部函数下拉选 `testList` → 点「运行」→ 首次授权「查看权限」
3. 再运行 `testOneCycle`（单实例无卡开→关，约 1 分钟）
4. 确认无误后运行 `installTrigger`（每 5 天，Asia/Shanghai 凌晨 3 点）

正式批量：`runCycle`（会处理**所有** Stopped 实例）。

`setupSecrets` 已内置与 `test_compshare.py` 相同的密钥；首次调 API 时也会自动写入脚本属性。

## 本地更新代码

```bash
cd gas
clasp push
```

## 函数

| 函数 | 作用 |
|------|------|
| `setupSecrets` | 保存密钥到脚本属性 |
| `testList` | 列出实例 |
| `testOneCycle` | 单实例冒烟 |
| `runCycle` | 全部 Stopped 无卡开→关 |
| `installTrigger` | 安装每 5 天定时 |
