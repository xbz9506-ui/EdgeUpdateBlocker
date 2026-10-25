# Edge Update Blocker

Windows 上**彻底禁止 Microsoft Edge 自动更新**的单文件批处理工具。八层防护可自由组合，每一项都能一键还原。

> 单文件 · 无依赖 · 无安装 · 全中文 · 自动 UAC 提权

---

## 为什么需要它

Edge 的更新不是单一入口，而是三条并行通道：

| 入口 | 说明 |
|---|---|
| `edgeupdate` / `edgeupdatem` 服务 | 由 SCM 拉起，开机即跑 |
| `MicrosoftEdgeUpdateTask*` 计划任务 | 不经过服务，直接触发 |
| Edge 自身 / WebView2 应用 | 启动浏览器时顺带唤起 EdgeUpdater |

再加上 Windows 大版本更新会把服务和计划任务**全部重建**，所以任何单一手段都会被系统"治好"。本工具的做法是把所有通道一次性掐断，并且阻断系统回滚。

---

## 八层防护

| 编号 | 手段 | 强度 | 副作用 |
|---|---|---|---|
| `[1]` | 禁用更新服务 | 中 | 无，但会被系统更新重建 |
| `[2]` | 铲除更新计划任务 | 中 | 无，但会被 Edge 重建 |
| `[3]` | 写入组策略 `UpdateDefault=0` | 强 | 无，微软官方开关 |
| `[4]` | hosts 屏蔽更新端点 | 弱 | 仅拦 DNS 层 |
| `[5]` | 防火墙出站拦截 | 中 | 无 |
| `[6]` | 目录 ACL 锁死 | 强 | 卸载/修复 Edge 会失败，需先还原 |
| `[7]` | 更新器改名 `.bak` | 中 | 大版本升级可能补回原文件 |
| `[8]` | **服务注册表保护** | **最强** | 无，防系统回滚 |

`[8]` 是唯一真正「防回滚」的手段：对服务注册表键追加 Deny 规则，拒绝 `SYSTEM` 的 `SetValue` 权限。此后无论是 Windows 更新、Edge 自己还是系统还原，都无法把服务启动类型改回自动；而管理员仍可通过 `[D]` 正常还原。

设计参考 [Windows Update Blocker](https://www.sordum.org/9470/windows-update-blocker-v1-8/) 的 `Protect Service Settings`。

---

## 用法

双击 `EdgeUpdateBlocker.bat`，会请求 UAC 提权，然后进入菜单。

```
运行权限 : 管理员  |  全部功能可用
------------------------------------------------------------------
服务状态 : 已禁用      更新器文件 : 已改名
服务保护 : 开          目录锁     : 已锁死
策略锁   : 已写入      计划任务   : 已清除
hosts    : 已屏蔽      防火墙     : 已拦截
```

### 命令行

```bat
EdgeUpdateBlocker.bat              交互菜单
EdgeUpdateBlocker.bat --auto       一键叠加八层
EdgeUpdateBlocker.bat --upgrade    解除限制并升级到最新版
EdgeUpdateBlocker.bat --status     只读体检，不改系统
EdgeUpdateBlocker.bat --dryrun     空跑演练，只看不做
EdgeUpdateBlocker.bat --guard      静默加固（供计划任务调用）
EdgeUpdateBlocker.bat --help       帮助
```

### 菜单项

```
[1]-[8]  单项措施，可任意组合
[9]      ★ 一键最强组合（1+2+3+7+6+4+5+8）
[A]      开机自愈守护（SYSTEM 计划任务每小时加固）
[B]      运行状态体检（只读）
[C]      备份当前环境
[D]      恢复还原全部（不升级）
[E]      风险与原理说明
[F]      一键还原升级（还原 → 拉最新版 → 可回锁）
```

---

## 想升级时怎么办

长期不更新有安全风险。需要升级时用 `[F]`：

1. 解除全部限制
2. 把 `disableEdgeUpdate` 目录名改回 `EdgeUpdate`
3. 恢复服务启动类型并拉起服务
4. 触发更新检查，自动打开 `edge://settings/help` 看进度
5. 升级完成后可**一键回锁**

---

## 管理员权限

本工具所有修改类操作**必须**以管理员身份运行。程序启动时用三重检测判定权限：

```
net session  →  fltmc  →  whoami /groups 查 S-1-16-12288
```

非管理员会被直接拦截，自动发起 UAC 提权；提权失败会明确提示手动右键运行，不会静默降级执行。

---

## 已知限制

- **WebView2 默认不冻结**（Teams / Office / 部分 Electron 应用依赖它）。需要冻结在 `[3]` 里选 `Y`。
- `[6]` 目录锁死后，卸载或修复 Edge 会报错，先用 `[D]` 还原。
- `[8]` 开启后 `[1]` 会改不动服务，属正常现象。
- 企业环境请优先用组策略 / Intune 下发，不要用本脚本。
- 长期不更新存在安全风险，建议每季度用 `[F]` 升级一次。

---

## 适配说明

- 支持 Windows 10 / 11（x86 / x64）
- 自动探测更新器目录：`EdgeUpdate` / `disableEdgeUpdate` / x64 三处
- 兼容 Edge 137+ 的 `EdgeCore` 目录结构（不触碰浏览器本体）
- 文件编码 GBK（CP936），中文系统直接双击不乱码

---

## 参考项目

- [Windows Update Blocker](https://www.sordum.org/9470/windows-update-blocker-v1-8/) — `Protect Service Settings` 机制
- [Vikindor/disable-edge-update](https://github.com/Vikindor/disable-edge-update) — 服务 / 任务 / 策略 / ACL 四层与还原顺序
- [jiarandiana0307/edge-update-switch](https://github.com/jiarandiana0307/edge-update-switch) — 更新器改名可逆方案
- [PartakithRC1/Win11-EdgeBGone](https://github.com/PartakithRC1/Win11-EdgeBGone) — GUID 后缀任务清理
- [Microsoft Edge Update 策略文档](https://learn.microsoft.com/deployedge/microsoft-edge-update-policies)

---

## 免责声明

本工具会修改系统服务、注册表、文件权限、防火墙与 hosts，请自行评估风险。建议先执行 `[C]` 备份。作者不对因使用本工具造成的任何损失负责。

## License

MIT
