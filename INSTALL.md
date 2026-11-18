# 薪跳 App · 安装指南（iOS · 不上架商店）

按顺序操作即可，全程免费。遇到问题把报错截图发给我。

## 你需要准备

| 东西 | 费用 | 用途 |
|---|---|---|
| GitHub 账号（仓库已建好，需公开） | 免费 | 云构建（GitHub Actions） |
| Apple ID（平时用的就行） | 免费 | 签名（有效期 7 天，自动续签） |
| iPhone + 数据线 | — | 首次安装 AltStore |
| 电脑装 AltServer | 免费 | 签名与续签服务 |

---

## 第一步：代码推到 GitHub

1. 打开 https://github.com 注册 / 登录；
2. 点右上角 **＋ → New repository**，名字填 `xintiao`，选 **Private（私有）**，创建；
3. 电脑安装 Git（https://git-scm.com 一路下一步）；
4. 打开 PowerShell，依次执行：

```powershell
cd 'D:\deepseek工作区\薪跳App'
git init
git add .
git commit -m "薪跳 V1.0"
git branch -M main
git remote add origin https://github.com/你的用户名/xintiao.git
git push -u origin main
```

---

## 第二步：GitHub Actions 云构建（自动进行）

构建已配置为**推送代码即自动开始**，无需你操作：

1. 打开 https://github.com/Aicq111/xintiao/actions 查看构建状态（黄色 = 构建中，绿色 = 成功，红色 = 失败）；
2. 每次构建约 8～15 分钟，免费额度内；
3. 成功后点进该次构建，页面底部 **Artifacts** 区 → 下载 **Runner-app** 压缩包（zip）。

> 若构建失败：把 Actions 里红色报错内容发给我，我修复后推送，构建会自动重跑。
> 若以后想手动重跑：Actions → 选中工作流 → **Run workflow**。

---

## 第三步：AltStore 签名安装（免费 7 天签名）

1. 电脑安装 AltServer：https://altstore.io → 安装后任务栏托盘出现 ◇ 图标，**登录你的 Apple ID**；
2. iPhone 用**数据线**连电脑，并开启「设置 → 隐私与安全性 → 开发者模式」（iOS 16+）；
3. 点托盘 ◇ 图标 → **Install AltStore** → 选择你的 iPhone → 手机上出现 AltStore；
4. 手机上信任证书：**设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID**；
5. 打包安装包：把下载的 `Runner.app` **右键 → 压缩为 ZIP**，再把后缀 `.zip` 改名为 `.ipa`；
6. 把 `.ipa` 传到手机（微信文件传输 / AirDrop / 邮件都可以）；
7. 手机上用 AltStore 打开该文件 → 自动签名安装，桌面出现「薪跳」。

**每 7 天续签**：手机与电脑连同一 WiFi、电脑开着 AltServer 时，AltStore 会自动续签，基本无感。

---

## 添加小组件

1. 先打开一次「薪跳」App（让它把数据写进小组件）；
2. 桌面长按 → 左上角 **＋** → 搜索「薪跳」；
3. 选择 **小（2×2）/ 中（4×2）/ 大（4×4）** 任一尺寸添加；
4. 显示内容可在 App 内「设置 → 小组件设置」里开关，也可长按小组件直接配置。

> 小组件受系统限制无法每秒刷新，但显示金额按时间戳推算，任何时候都是准确的当前值。

---

## 以后想长期用 / 上架商店

- 购买 **Apple 开发者账号**（$99/年 ≈ ¥688/年）：签名有效期变为 1 年，还可通过 TestFlight 邀请朋友测试；
- 想上架 App Store 时，同账号即可提交审核（到时我帮你准备商店素材与审核材料）。

---

## 常见问题

| 问题 | 处理 |
|---|---|
| 提示「不受信任的开发者」 | 设置 → 通用 → VPN 与设备管理 → 信任 |
| 7 天到期没自动续签 | 手机连电脑（或同 WiFi），打开 AltServer 与 AltStore 重新签名即可，App 数据不受影响 |
| Codemagic 构建失败 | 已弃用，构建走 GitHub Actions（见上） |
| 小组件空白 | 先打开一次 App；再在桌面重新添加小组件 |
