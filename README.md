# AI 记账（多人账本 Demo）

单人/多人共享账本 + AI 对话记账 + 固定薪资自动记账 + 月度统计报表。

## 架构

```
Flutter App (Android)          FastAPI (Python 3.12)
┌──────────────────┐   HTTP    ┌──────────────────────────┐
│  mobile/lib/     │ ────────> │  backend/app/            │
│  dio + fl_chart  │  JWT      │  FastAPI + SQLAlchemy    │
└──────────────────┘           │  + APScheduler(发薪任务)  │
                               └───────────┬──────────────┘
                                           │ OpenAI 兼容接口
                                   ┌───────▼────────┐
                                   │  aihubmix 中转  │
                                   │  GLM (可换模型) │
                                   └────────────────┘
```

- 数据库：SQLite（`backend/jizhang.db`，零配置；后续可平滑换 PostgreSQL）
- AI：目前开发使用aihubmix 中转 + GLM 系列模型（如有其他AI接口需要，得改一下.env），Function Calling 强制输出结构化 JSON
- 认证：开发者贫穷TAT，没有接入运营商，手机号 + 密码（代替短信验证码，字段已按手机号设计，接入短信时只改 auth 路由）

## 功能清单

| 功能      | 说明                                                 |
| ------- | -------------------------------------------------- |
| 注册/登录   | 手机号+密码，JWT 有效期 30 天                                |
| 多账本     | 注册自带个人账本；可新建共享账本、6 位邀请码加入                          |
| AI 对话记账 | 输入"今天午饭花了35"→ AI 解析金额/分类/日期 → 卡片确认后入库；支持一句话多笔      |
| 手动记账    | 明细页 "+" 按钮，表单记账                                    |
| 固定薪资    | 设置金额+发薪日，每天 09:00 定时检查自动入账（31 号规则在短月自动取月末，停机重启会补录） |
| 额外收入    | 对话输入"闲鱼卖了旧手机800"，AI 判断为收入                          |
| 明细管理    | 按月查看、筛选收支类型、点击编辑、长按删除                              |
| 统计      | 月汇总、支出分类饼图、每日趋势折线、成员对比                             |
| 权限      | 创建者可改删全部记录，普通成员只能改删自己记的                            |

## 目录结构

> **克隆本仓库后先做两件事**（敏感配置均不上传）：
>
> 1. `cp backend/.env.example backend/.env`，填入你的 `AIHUBMIX_API_KEY`
> 2. `cp mobile/lib/app_config.template.dart mobile/lib/app_config.dart`，改成你的后端地址

```
backend/
├── app/
│   ├── main.py            # 入口：建表/预置分类/启动定时任务
│   ├── config.py          # 配置（读 .env）
│   ├── database.py        # SQLAlchemy + SQLite
│   ├── models.py          # 6 张表：users/ledgers/ledger_members/categories/transactions/salary_rules
│   ├── schemas.py         # Pydantic 请求/响应模型
│   ├── security.py        # bcrypt 密码 + JWT
│   ├── deps.py            # 登录校验、账本成员校验
│   ├── ai_parser.py       # AI 解析（Function Calling）
│   ├── scheduler.py       # 发薪日自动记账任务
│   ├── seed.py            # 预置分类（18 个）
│   └── routers/           # auth/ledgers/categories/transactions/ai/salary/stats
├── requirements.txt
├── .env.example
├── smoke_test.py          # 26 项 API 冒烟测试
└── salary_test.py         # 薪资任务验证（含幂等）

mobile/
├── pubspec.yaml
├── analysis_options.yaml
└── lib/
    ├── main.dart          # 入口 + 主题
    ├── api_client.dart    # Dio 封装 + 全局状态 AppState
    ├── models.dart        # 数据模型
    ├── pages/
    │   ├── login_page.dart       # 登录/注册
    │   ├── home_page.dart        # 底部导航壳 + 首页汇总
    │   ├── chat_page.dart        # AI 对话记账（核心）
    │   ├── transactions_page.dart# 明细列表
    │   ├── stats_page.dart       # 统计图表
    │   └── settings_page.dart    # 账本/邀请码/薪资/服务器设置
    └── widgets/
        └── tx_edit_sheet.dart    # 记账编辑表单（手动/AI草稿共用）
```

## 启动后端

```powershell
cd d:\traeproj\JZproject\backend

# 1. 创建虚拟环境（已创建则跳过）
python -m venv .venv

# 2. 安装依赖
.venv\Scripts\pip install -r requirements.txt

# 3. 配置
copy .env.example .env
#    编辑 .env：填入 AIHUBMIX_API_KEY（https://aihubmix.com 获取）
#    SECRET_KEY 改成随机串；AI_MODEL 默认 glm-4.9-flash，可随时换

# 4. 启动
.venv\Scripts\python -m uvicorn app.main:app --port 8000
```

- 接口文档（Swagger）：<http://127.0.0.1:8000/docs>
- 首次启动自动建表 + 写入 18 个预置分类
- 不填 AIHUBMIX\_API\_KEY 也能跑：手动记账、统计全部可用，AI 对话会返回提示

### 测试

```powershell
.venv\Scripts\python smoke_test.py    # 26 项 API 冒烟（自动清库重建）
.venv\Scripts\python salary_test.py   # 验证薪资自动记账 + 幂等
```

## 启动 Flutter App（Android）

本机环境已搭好（无需 Android Studio），工具链都在项目内 `.tools\` 目录：

```
.tools\
├── flutter\           # Flutter 3.47.2 SDK
├── android-sdk\       # Android SDK（platform-tools / android-36 / build-tools 36.0.0）
└── pub-cache\         # Dart 包缓存
```

一键构建（推荐）：直接双击项目根目录的 `build_apk.cmd`（已配好 JAVA\_HOME / Android SDK / PUB\_CACHE 等全部环境变量）：

```
产物：mobile\build\app\outputs\flutter-apk\app-release.apk
```

手动构建命令（PowerShell）：

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
$env:Path = "D:\traeproj\JZproject\.tools\flutter\bin;$env:JAVA_HOME\bin;$env:Path"
$env:PUB_CACHE = "D:\traeproj\JZproject\.tools\pub-cache"
$env:ANDROID_HOME = "D:\traeproj\JZproject\.tools\android-sdk"
$env:ANDROID_SDK_ROOT = "D:\traeproj\JZproject\.tools\android-sdk"

cd D:\traeproj\JZproject\mobile

flutter pub get      # 拉依赖（首次/改 pubspec 后）
flutter analyze      # 静态检查
flutter test         # 单元测试
flutter build apk --release   # 出 APK
```

> 国内网络注意：`android/gradle/wrapper/gradle-wrapper.properties` 的发行版地址已改为腾讯镜像（services.gradle.org 直连会 SSL 失败）。

### Windows 路径补丁（重要）

Gradle 调用 `flutter assemble` 时传给 Dart 编译器的 Windows 反斜杠路径会在批处理/PowerShell 链路中被破坏（`lib\main.dart` → 报错找不到 `/main.dart`）。已在 Flutter SDK 内打补丁修复：

`.tools\flutter\packages\flutter_tools\gradle\src\main\kotlin\tasks\BaseFlutterTaskHelper.kt`
（搜索 `PATCH(win)`，共两处：`-dTargetFile`、`--depfile`/`--output` 的路径统一 `replace('\\', '/')`）

**注意**：`flutter upgrade` 或重装 SDK 会覆盖此文件，届时需重新打补丁，否则 APK 构建会复现上述报错。

真机安装：USB 连接手机开调试模式后 `adb install app-release.apk`，或直接把 APK 传到手机点击安装。

### 连后端地址

- **Android 模拟器**：默认 `http://10.0.2.2:8000`（模拟器访问宿主机），无需修改
- **真机（同局域网）**：App「我的 → 服务器地址」改成电脑局域网 IP（如 `http://192.168.1.100:8000`），后端启动加 `--host 0.0.0.0`
- **公网服务器（裸 IP + HTTP）**：App「我的 → 服务器地址」填 `http://你的服务器IP:端口`。App 已在 manifest 声明 `usesCleartextTraffic`，release 包也可直连 HTTP

## 公网服务器部署（HTTP demo，端口 7012）

无需域名/HTTPS/任何付费服务。已备好三个脚本（`backend/setup.sh` / `start.sh` / `stop.sh`）和干净部署包 `backend_deploy.tar.gz`（项目根目录，仅 13KB，不含本地测试库和虚拟环境）。

**第 1 步：本机 PowerShell 上传部署包**（Windows 10+ 自带 scp，会提示输服务器密码）：

```powershell
scp backend_deploy.tar.gz root@你的服务器IP:/root/
```

**第 2 步：SSH 登录服务器，解压并初始化**（一次性）：

```bash
ssh root@你的服务器IP          # Windows PowerShell 直接这样连，输密码

mkdir -p /opt/jizhang
tar -xzf /root/backend_deploy.tar.gz -C /opt/jizhang
cd /opt/jizhang
bash setup.sh                  # 装依赖（清华镜像）+ 生成 .env（随机密钥 + 端口 7012）
```

**第 3 步：填 aihubmix key 并启动**：

```bash
nano .env                      # 把 AIHUBMIX_API_KEY= 后面填上 key（Ctrl+O 回车保存，Ctrl+X 退出）
bash start.sh                  # 后台常驻启动，自动健康检查
```

看到「启动成功」后，浏览器打开 `http://你的服务器IP:7012/docs` 能看到 Swagger 页面即部署完成。

**第 4 步：放行端口**（连不上就查这里）：云厂商控制台 → 安全组/防火墙 → 添加入站规则：TCP、端口 7012、来源 0.0.0.0/0。

日常运维：

```bash
cd /opt/jizhang
bash stop.sh                   # 停止
bash start.sh                  # 重启（改完 .env 后执行）
tail -f app.log                # 看实时日志（Ctrl+C 退出查看，不影响服务）
```

注意事项：

- HTTP 明文传输，密码和 JWT 裸奔在公网上，**仅限自用 demo**，切记不要给别人注册使用
- SQLite 数据在 `/opt/jizhang/jizhang.db`，备份：`scp root@你的服务器IP:/opt/jizhang/jizhang.db .`
- 服务器重启后需手动 `bash start.sh`（想开机自启可配 systemd，需要再说）
- AI 解析依赖服务器能访问 aihubmix（境外服务器无障碍；国内服务器一般也通）

## 数据流：AI 记账怎么工作

1. 用户在对话框输入：`昨天买菜50，水果30`
2. App 调 `POST /api/ai/parse`（附当前账本的分类列表）
3. 后端组装 system prompt（今天日期+星期、收支分类枚举、解析规则）发给 aihubmix 的 GLM
4. 模型通过 Function Calling 返回两次 `save_transaction` 调用（每笔一次）
5. 后端聚合为草稿数组返回（**不入库**）
6. App 展示草稿卡片 → 用户可修改（金额/分类/日期/备注）→ 点「确认入账」
7. App 调 `POST /api/transactions`（source=ai）正式入库

## Demo 范围与后续路线

后续考虑的功能：

- 预算与超支提醒、周期性支出（房租/订阅）
- 数据导出 CSV、消息推送、多币种
- HTTPS/生产部署（当前 CORS 全开、SQLite 单文件）
- 刷新 token 机制（30 天后需重新登录）

