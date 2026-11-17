# 薪跳 App（V1.0 开发中）

把收入换算成每秒增长的钱，像看时钟一样看着工资一秒一秒上涨。

- 产品需求文档：`../薪跳App-产品需求文档-V0.6.md`（当前版本 V0.9）
- UI 原型：`../薪跳App-UI原型-v2.html`、`../薪跳App-小组件原型-v1.html`、`../薪跳App-日历页原型-v1.1.html`、`../薪跳App-收尾页面原型-v1.html`

## 项目结构

```
薪跳App/
├── pubspec.yaml            # Flutter 工程配置
├── lib/
│   ├── main.dart           # 入口 + 主页（演示配置直连引擎，每秒跳动）
│   └── core/
│       └── engine.dart     # 核心计薪引擎（排班/倍率/请假/多收入）
├── test/
│   └── engine_test.dart    # 引擎单元测试（13 项，与 Node 镜像同源）
└── verify/
    └── engine_check.mjs    # 引擎 JS 镜像 + 数学验证（已全部通过）
```

## 核心引擎说明

- 金额以「毫」为最小单位（1 元 = 10000 毫），整数累计避免浮点误差；
- 时间以「分钟」为最小单位，跨天夜班用 endMin > 1440 表示；
- 基准速率 = 月薪 ÷ 当月**纯排班**计薪秒数（加班费/请假扣款按固定日薪基数核算，与真实工资一致）；
- 特殊日（加班倍率 / 请假时段 / 调休）只影响当天区间：倍率放大或计薪 0；
- 全天候收入（副业/理财）不受排班与特殊日影响；
- `verify/engine_check.mjs` 与 `test/engine_test.dart` 为同一算法的双实现，13 项数学验证已通过（Node）。

## 如何编译与安装（iOS 不上架）

本机是 Windows，无法直接编译 iOS。两种方式：

1. **云构建（推荐）**：把本目录推送到 Git 仓库，用 Codemagic（免费额度）连接构建，产出 .ipa；
2. **Mac**：`flutter build ios --release` 后签名导出。

**安装（AltStore，免费 7 天签名）**：
1. 电脑装 AltServer（Windows 版）；
2. iPhone 装 AltStore（数据线连接，AltServer → 安装 AltStore）；
3. 把 .ipa 传到手机（同一 WiFi 下 AltStore 自动续签）；
4. 首次信任开发者证书：设置 → 通用 → VPN 与设备管理 → 信任。

> 之后若想长期稳定使用或上架商店，购买 Apple 开发者账号（$99/年 ≈ ¥688/年），签名有效期 1 年。

## 版本计划

| 阶段 | 内容 | 状态 |
|---|---|---|
| V1.0a | 核心 7 页 + 主题 + 字体跟随 + 本地持久化 | ✅ 代码完成（待云构建验证） |
| V1.0b | 三尺寸 iOS 小组件（WidgetKit） | ✅ 代码完成（App Group 数据共享 + SwiftUI 三尺寸） |
| V1.1 | 险金模块（五险一金/六险二金等）+ 攒钱计划 | 待开发 |
| V1.2+ | AI 助手（需 API Key）、数据导出、优化池 | 待开发 |

> 完整安装步骤见 **INSTALL.md**（GitHub → Codemagic 云构建 → AltStore 签名安装 → 添加小组件）。

## 云构建（Codemagic）

1. 注册 [codemagic.io](https://codemagic.io)（用 GitHub 登录，免费额度够用）；
2. 把本目录推送到 GitHub 仓库；
3. Codemagic → Add application → 选择该仓库 → 自动读取 `codemagic.yaml`；
4. 点 `ios-build` 工作流构建，产物为 `Runner.app`（未签名）；
5. 用 AltStore 签名安装（见下文）。

## 本地验证

引擎数学验证（Windows 可跑，无需 Flutter）：

```
node verify/engine_check.mjs
```

Flutter 测试（需 Flutter SDK）：

```
flutter test
```
