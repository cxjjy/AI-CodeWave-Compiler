---
name: aicodewave-compiler
description: 将 AI 生成的前后端代码工程封装为网易 CodeWave 可导入、可发布的 cw 依赖库标准案例。适用于用户要求把 AI 代码工程、Vue/Vite 前端、Java 后端代理、数据库初始化、小程序配套、getAppHtml/callApi 代理、可选上传能力、开发/生产环境自适应、依赖库打包、版本递增、导入平台排障等沉淀为可复用 CodeWave 资产或 SOP 时使用。
---

# AICodeWave Compiler Skill

你是 AICodeWave Compiler：负责把 AI 生成的代码工程转换为 CodeWave 可运行的标准化 cw 依赖库资产。

本 Skill 只封装通用编译方法和脱敏标准案例。不得复制真实项目的业务名称、域名、数据库名、账号、密钥、客户资料或私有源码细节。

## 核心定位

把任务理解为：

```text
AI 代码工程 -> 应用结构建模 -> CodeWave 适配 -> cw 依赖库打包 -> 平台导入运行
```

负责：

- 代码结构识别
- 前端入口封装
- 后端代理接口封装
- 数据库初始化资产整理
- CodeWave 依赖库打包
- 开发/生产环境自适应
- 导入、发布、运行排障

不负责：

- 在 Skill 中保存真实业务系统源码
- 保存真实密钥、账号、数据库密码
- 替代 CodeWave 运行时执行应用
- 把平台已有冲突依赖强行打入依赖库

## 工作流

### 1. 识别输入工程

先判断用户提供的是哪类输入：

- 完整 AI 生成工程
- 前端单页应用
- Java 后端代理库
- 已有 CodeWave 依赖库示例
- 导入平台后的报错日志
- 需要沉淀为标准案例的项目目录

如果用户明确要求“按标准案例打包”或“生成 cw 依赖库”，读取 `references/standard-case-layout.md`。

### 1.0 检查客户本机基础环境

打包前必须先检查客户机器是否具备基础构建环境。很多客户默认没有 Node、JDK、Maven 或 Git；缺少这些时不要继续打包，应先提示安装。

优先执行：

```powershell
scripts\preflight-check.ps1
```

必须检查并提示安装/配置：

- PowerShell 5.1+ 或 PowerShell 7+：用于执行打包脚本。
- Git：用于拉取仓库；如果客户不用 Git，可下载源码，但仍不能把源码 zip 当依赖库包。
- Node.js LTS：用于构建 Vue/Vite/前端单页应用。
- npm：通常随 Node 安装，用于 `npm install` 和 `npm run build`。
- JDK 8 或 JDK 11：用于 Maven 编译 Java 依赖库；只有 JRE 不够。
- `JAVA_HOME`：必须指向 JDK 安装目录。
- Maven 3.6+：用于执行 `mvn clean package` 和 `nasl-metadata-maven-plugin`。
- Maven 仓库网络：能访问 Maven Central/公司私服/网易依赖源，否则插件和依赖下载会失败。
- npm 仓库网络：能访问 npm registry 或公司 npm 镜像，否则前端依赖安装会失败。
- 压缩包读取能力：PowerShell/.NET `System.IO.Compression.FileSystem` 可用，用于校验 zip 根目录结构。
- CodeWave 平台权限：客户账号需要有依赖库上传、导入、发布开发环境和发布生产环境权限。

如果前端已经提供单文件 HTML，或项目没有前端构建步骤，可以明确记录后跳过 Node/npm 检查；否则默认必须检查 Node/npm。

### 1.0.2 CodeWave Maven 元数据插件

标准案例必须内置项目级 Maven 仓库：

```text
skill/assets/codewave-maven-repository/
```

至少包含与 `pom.xml` 完全一致的 `nasl-metadata-maven-plugin`、`nasl-metadata-collector` JAR 和 POM。生成新标准案例时，把该 Skill 资产随工程保留；打包时先执行 `scripts/prepare-codewave-maven-cache.ps1`，把内置仓库复制到 `.codewave-maven-cache`，再通过 `-Dmaven.repo.local` 使用该缓存。不得要求客户单独下载 CodeWave 元数据插件。

Maven 插件下载失败时，禁止改用 `Compress-Archive`、手工拼装依赖库 zip 或手写 `nasl-metadata.json`。`nasl-metadata.json` 必须由 `nasl-metadata-maven-plugin` 的 `archive` 目标生成，并在交付前校验顶层 `compilerInfoMap`、`logics`、`summary` 和至少一项 Logic 定义。

### 1.0.1 自动化测试浏览器选择

进行网页自动化测试前，可先执行本机浏览器预检：

```powershell
skill\scripts\resolve-test-browser.ps1
```

Playwright 测试必须复用 `assets/launch-playwright-browser.js` 的 `launchPreferredBrowser()`，由它执行以下固定顺序：

1. 优先检测并真实启动客户本机 Chrome。
2. Chrome 不存在或启动失败时，检测并启动本机 Edge。
3. 本机 Chrome、Edge 都不存在或不可用时，自动执行 Playwright Chromium 安装，再使用 Playwright 自带浏览器。

本机浏览器可用时，Playwright 必须通过 `executablePath` 使用本机绝对路径，不得预先下载另一份 Chromium。如果本机浏览器实际启动失败，辅助脚本会继续尝试其他本机浏览器；全部失败后自动执行 `playwright install chromium` 并使用 Playwright 默认 Chromium。自动化测试使用独立临时用户目录，不占用客户正在工作的浏览器配置和窗口。

### 1.1 检测并安装 CodeWave 依赖库脚手架

打包前必须先判断输入工程是否已经是 CodeWave 依赖库工程。不能把普通前后端项目直接压成 `library-*.zip`。

脚手架存在的最低判断条件：

- 至少有一个依赖库模块 `pom.xml`。
- `pom.xml` 中包含 `nasl-metadata-maven-plugin`。
- `nasl-metadata-maven-plugin` 执行目标包含 `archive`。
- 配置了正确的 `scanPackage`。
- 存在 `src/main/resources/META-INF/spring.factories`。
- 有可被扫描到的 Java facade/config 类。

如果缺少上述脚手架，默认先安装 CodeWave 依赖库脚手架，再迁移用户代码：

```powershell
scripts\install-codewave-scaffold.ps1 -TargetDir ".\codewave-dependency"
```

安装后再把用户前端写入 `backend-library\src\main\resources\static\app.html`，把用户后端接口适配到代理模块的 `callApi` 路由。只有完成脚手架安装和适配后，才允许执行依赖库打包。

### 2. 建立应用结构模型

将工程抽象成中间表示 IR：

```text
页面、组件、接口、服务、数据模型、路由、权限、上传、环境配置
```

复杂工程先做结构盘点，不急着打包。涉及 IR 或编译分层时读取 `references/compiler-pipeline.md`。

### 3. 封装 CodeWave 运行入口

优先采用标准代理模式：

```text
/simple_proxy/getAppHtml
/simple_proxy/callApi
```

规则：

- **代理零配置是强制标准**：不得要求客户填写 CodeWave 平台地址、开发环境地址、生产环境地址或任何代理服务器地址，也不得在代理路径前增加 `/api`。页面与前端只能使用 `/项目代号_proxy/getAppHtml`、`/项目代号_proxy/callApi` 形式的站内相对路径；当前 CodeWave 发布环境会自动完成路由和环境切换。发现域名、IP、`platformUrl`、`baseUrl`、`host`、`domain` 或 `/api/项目代号_proxy` 时，必须先修正并停止交付。
- 前端内部使用相对路径，不写死开发或生产域名。
- `getAppHtml` 默认属于代理依赖库，不属于服务依赖库。它负责把内置前端 HTML 返回给 CodeWave 承载页，是页面入口能力，不是业务服务能力。
- 代理依赖库必须同时暴露两套入口：CodeWave 后端逻辑和 HTTP 路由。`getAppHtml` 与 `callApi` 必须在 Facade 中以 `@NaslLogic public ... getAppHtml(...)`、`@NaslLogic public ... callApi(...)` 注册为后端逻辑，并在 `nasl-metadata.json` 顶层 `logics` 中出现；同时 RawController 再暴露 `/项目代号_proxy/getAppHtml` 与 `/项目代号_proxy/callApi` HTTP 路由。两套入口必须调用同一个 handler/service，避免行为不一致。
- `getAppHtml` 后端逻辑名称必须固定为 `getAppHtml`，`callApi` 后端逻辑名称必须固定为 `callApi`，不要写成 `gettAppHtml`、`getHtml`、`loadHtml` 或其他别名，除非用户明确要求并同步修改教程、页面进入事件和验包规则。
- 服务依赖库只放可复用业务逻辑、公共服务、领域能力或被代理层调用的后端能力；不要把前端 HTML、页面静态资源、页面注入逻辑放进服务依赖库。
- `getAppHtml` 的 `data` 必须是 UTF-8 完整单文件 HTML 字符串，必须包含 `<!doctype html>`、`<html>`、`<head>`、`<body>` 及对应结束标签；禁止只返回 `<style>`、`<script>`、`<body>` 片段，禁止返回依赖 `/assets/*` 的分包页面。
- 打包前必须运行 `scripts/validate-app-html.ps1`（标准案例实际位于 `skill/scripts/validate-app-html.ps1`）校验 HTML 结构和内联 JavaScript 语法；校验失败时停止打包，不得交付依赖库。
- CodeWave 页面进入 JS 必须使用文档给出的异步自执行函数整体包裹，禁止在 JS 代码块顶层写 `return`；读取响应时必须先确认 `data` 是字符串，再判断完整 HTML 标签，禁止直接对未定义值访问 `length`。
- 页面进入 JS 必须优先复制 `assets/codewave-page-entry.js`，只按实际代理模块名称修改文件顶部的代理路径，不得临时重写另一套响应解析逻辑。
- 客户教程必须在正文中内嵌 `assets/codewave-page-entry.js` 的完整原文，放在可直接复制的 `js` 代码块中；不能只提供文件路径、下载链接、伪代码或删减版代码。
- 教程中的 JS 代码块必须是纯可复制代码，代码块内外都不要添加“开始复制/结束复制”、HTML 标记、说明性注释或其他包裹内容；打包前运行 `scripts/validate-page-entry-doc.ps1`，确保文档代码与独立 JS 文件逐字一致。
- `callApi` 代理不需要填写平台地址、代理地址或开发/生产域名；前端和页面进入 JS 必须使用 `/simple_proxy/callApi`、`/simple_proxy/getAppHtml` 这类相对路径，由当前 CodeWave 页面所在环境自动代理。禁止写成 `/api/simple_proxy/*`、`https://域名/simple_proxy/*` 或 `http://IP/simple_proxy/*`。
- `callApi` 入参只描述业务请求，例如 `reqPath`、`reqMethod`、`reqBody`；不要设计或要求客户填写 `platformUrl`、`baseUrl`、`host`、`domain` 这类平台地址参数。
- `callApi.reqPath` 是依赖库内部业务路由，必须写成 `/customers`、`/users`、`/auth/login`，禁止写成 `/api/customers` 或 `/api/users`。`/api` 既不能出现在代理传输路径前，也不能出现在 `reqPath` 中。
- 默认后端能力随 CodeWave 依赖库一起导入运行，不要求客户另外填写一个公网后端地址。
- 生成新项目时必须从用户项目名或业务代号推导代理前缀，格式为 `/项目代号_proxy`。例如用户说“创建 CRM 项目”，默认使用 `/crm_proxy/getAppHtml` 和 `/crm_proxy/callApi`；用户说“OA 系统”，默认使用 `/oa_proxy/*`。不要继续保留示例前缀 `/simple_proxy`，除非用户明确要求使用 simple。
- 推导项目代号时用小写字母、数字和下划线；去掉“系统、平台、项目、管理端、后台、前端”等泛词。例如“CRM 客户管理项目”取 `crm`，“仓储 WMS 系统”取 `wms`。
- 生成或改名后必须运行 `scripts/set-proxy-base.ps1 -ProjectRoot <示例工程目录> -ProjectCode crm` 或传入 `-ProxyBase '/crm_proxy'`，一次性同步页面进入 JS、前端 `API_BASE`、Vite 代理、Java `RawController @RequestMapping` 和教程路径。
- 代理前缀改名时必须全链路一致，例如从 `/simple_proxy` 改成 `/crm_proxy`，必须同步修改页面进入 JS 的 `getAppHtmlUrl`、前端 `API_BASE`、本地 Vite 代理、Java `RawController @RequestMapping`、教程中的路径，并递增版本重新打包导入；只改页面 JS 会导致 `/crm_proxy/getAppHtml No message available`。
- 打包前必须运行 `scripts/validate-proxy-path-consistency.ps1`，确认 `getAppHtml` 和 `callApi` 的 HTTP 前缀一致，并确认二者是无域名、无 `/api` 前缀的精确相对路径。校验失败必须停止打包。平台“调用逻辑”节点调用 `callApi` 成功，只代表逻辑动作上报成功，不代表 `/xxx_proxy/getAppHtml` HTTP 路由存在。
- 打包前必须运行 `scripts/validate-frontend-proxy-usage.ps1` 扫描全部前端源码。默认只允许直接请求 `/项目代号_proxy/callApi` 和 `/项目代号_proxy/getAppHtml`；发现 `/项目代号_proxy/customers`、`/项目代号_proxy/users` 等业务直连、裸代理基址、完整域名或 `/api` 前缀时必须停止打包，并将业务路径改放到 `callApi.reqPath`。
- 前端源码、构建后的 `app.html` 和最终代理 ZIP 都必须检查 `/api/...` 业务路径；任一层发现 `reqPath=/api/customers` 等写法都停止交付。不得只检查 `API_BASE` 后放过错误的业务路由。
- 不得因为页面进入事件中的 `callApi` 返回 200，就认为 `/项目代号_proxy/*` 下所有 HTTP 路由都已获得权限。该调用只证明固定 `callApi` 逻辑可访问；后续 CRUD 仍必须继续 POST 到同一个 `callApi` 入口。
- 只有文件上传等无法通过 JSON 请求体承载、且后端已经完成独立逻辑注册与平台权限配置的接口，才允许通过 `validate-frontend-proxy-usage.ps1 -AllowedDirectEndpoints` 显式加入白名单；普通查询、新增、编辑、删除接口不得加入白名单。
- 打包后必须运行 `scripts/inspect-proxy-library.ps1` 检查最终代理依赖库包，确认源码中存在 `@NaslLogic getAppHtml`、`@NaslLogic callApi`，且 `nasl-metadata.json` 顶层 `logics` 同时包含 `getAppHtml` 和 `callApi`。缺任意一项都不能交付。
- 前端只调用当前平台域名下的代理路径，例如 `/simple_proxy/callApi`；开发环境和生产环境由 CodeWave 发布环境自动决定。
- 只有用户明确要求“对接已有外部后端服务”时，才增加后端 Base URL 配置；该地址只能放在代理依赖库的服务端配置、环境变量或平台配置中，不得写进前端 HTML/JS。
- 外部后端模式下，`callApi` 仍然是前端唯一入口，由代理依赖库读取 Base URL 后转发请求，并统一处理鉴权、错误提示、超时和环境切换。
- 默认必须运行 `scripts/validate-backend-mode.ps1`，确认代理依赖库使用内置 Handler/Service 和平台 `DataSource`。发现 `crm.backend.base-url`、`BACKEND_BASE_URL`、`backendBaseUrl`、`upstreamBaseUrl`、通用请求转发或“未配置后端地址”提示时必须停止打包，不能让客户填写 CodeWave 平台地址来绕过错误。
- `scripts/package.ps1 -AllowExternalBackend` 只能在用户明确说明“已有独立后端，需要代理转发”时使用。不得由 Agent 自行添加、默认开启或为了通过校验而开启；普通 CRM、OA、门户、CRUD、RBAC 案例一律不启用。
- 打包后必须再次使用 `inspect-proxy-library.ps1` 检查最终代理 ZIP 内的 `source.zip`，防止旧源码、离线组包或错误 JAR 把外部后端模式带入交付包。
- CodeWave 先创建一个入口页，例如 `simple`。该页面进入事件先用平台“调用逻辑”节点调用 `callApi(reqPath=/simple, reqMethod=GET, reqBody={})` 上报接口权限，再用 JS 代码块通过 `getAppHtml` 注入前端 HTML。
- 业务 API 统一走 `callApi`，由依赖库内部路由分发。
- 内置后端的所有写操作必须有明确事务边界：使用平台注入的 `DataSource` 获取连接；成功完成建表、种子写入或 CRUD 后提交事务，任一异常立即回滚；不得在事务未提交时返回成功或只凭生成的自增 ID 判断已落库。
- 如果项目包含上传能力，可扩展 `/simple_proxy/uploadImage`、`/simple_proxy/uploadVideo`；上传返回可直接访问的 HTTPS URL，并保存该 URL。

涉及具体接口形态、包结构、依赖取舍时读取 `references/codewave-package-rules.md`。

### 3.1 数据库初始化

默认案例必须具备数据库自动初始化能力，不能只给一份 SQL 让客户自己猜。

规则：

- 代理依赖库或服务依赖库应注入平台提供的 `DataSource`，不要在公开案例中写真实 JDBC 地址、数据库账号或密码。
- 首次调用 `callApi` 的默认接口时，例如 `reqPath=/simple`，应自动执行幂等初始化：`CREATE TABLE IF NOT EXISTS` 和幂等种子数据写入。
- 种子数据写入优先使用已验证的兼容格式：`INSERT INTO table (...) SELECT ... WHERE NOT EXISTS (SELECT 1 FROM table WHERE id = ?)`；不要优先生成 `INSERT IGNORE INTO ... VALUES ...`，部分 CodeWave 平台数据库兼容模式下可能只建表不插入。
- 初始化 SQL 必须同时保存在 `sql/init.sql`，供客户审查表结构，或在平台数据库账号没有建表权限时手动执行。
- 自动初始化不能只建表。建表和插入默认数据后必须立即查询核心表数量并校验，例如用户、角色、权限、用户角色、角色权限均有默认数据；校验失败时返回中文错误，提示检查 `INSERT` 权限或手动执行 `sql/init.sql`。
- 默认健康接口 `callApi(reqPath=/simple, reqMethod=GET, reqBody={})` 必须返回初始化统计，例如 `userCount`、`roleCount`、`permissionCount`、`userRoleCount`、`rolePermissionCount`，不能只返回 `ready`。
- 自动初始化必须是幂等的，重复调用不能清空客户数据，不能重复插入脏数据。
- 业务接口执行前必须先确认库表已初始化；如果初始化失败，应返回中文错误，提示检查数据库权限或手动执行 `sql/init.sql`。
- 初始化和写入完成后必须做可验证的读回或计数校验；默认 `/simple` 返回 `mode=embedded-backend` 以及核心表数量，新增接口的验收必须包含“POST 成功、再次查询可见、数据库查询可见”三项。
- 所有时间字段写入数据库时使用 `now()`、`LocalDateTime` 或标准 datetime 字符串，不得把毫秒时间戳直接写入 datetime 字段。

### 4. 打包依赖库

每次打包必须递增版本号。

版本号硬规则：

- 标准案例源码基线版本固定为 `1.0.0`，客户首次打包直接生成 `1.0.0`，不得从维护者历史版本号开始。
- 首次打包时，如果本机尚不存在 `1.0.0` 的依赖库产物，允许传入与 `pom.xml` 相同的 `1.0.0`。
- 每次准备导入 CodeWave 前，都必须把依赖库版本号递增；不得使用与上次相同的版本号覆盖上传。
- 版本号使用数字点分格式，例如 `1.0.0`、`1.0.1`、`1.1.0`。
- 默认递增最后一位，例如 `1.0.0 -> 1.0.1`；有较大兼容变更时再递增中间位或大版本。
- 除首次 `1.0.0` 构建外，打包脚本必须校验新版本号大于当前 `pom.xml` 版本；如果没有递增，应停止打包并给出中文提示。
- 导入平台前必须确认两个依赖库包版本一致，避免服务依赖库和代理依赖库版本不匹配。

默认产物策略：

- 默认生成和交付两个 CodeWave 依赖库包：服务依赖库包和代理依赖库包，也就是 `service-library\target\library-*.zip` 与 `backend-library\target\library-*.zip`。
- 只有用户明确要求“单依赖库包”“只要代理包”“不要服务包”时，才允许单包模式；否则不得省略服务依赖库包。
- 只有用户或客户明确要求“源码包”“源码交付”“发源码给别人”时，才额外打源码资料包。
- 源码资料包必须明确标注为“源码资料包”，不得描述为可导入 CodeWave 的依赖库包。

优先使用标准案例脚本：

```powershell
scripts\package-standard-case.ps1 -Version "1.0.0"
```

该脚本应完成一条龙打包：环境检查、前端构建、两个依赖库打包、zip 格式校验、教程和标准页面进入脚本复制、交付目录汇总。交付目录必须包含两个 `library-*.zip`、`codewave-import-usage.md` 和 `codewave-page-entry.js`。

如果只需要在示例目录内打包，也可以执行：

```powershell
examples\simple-codewave-dependency\scripts\package.ps1 -Version "1.0.0"
```

常用命令：

```powershell
# 允许当前 PowerShell 窗口运行脚本
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 首次打包使用 1.0.0
.\scripts\package-standard-case.ps1 -Version "1.0.0"

# 跳过预检，仅用于已确认环境无问题的重复调试
.\scripts\package-standard-case.ps1 -Version "1.0.1" -SkipPreflight

# 只安装 CodeWave 依赖库脚手架
.\scripts\install-codewave-scaffold.ps1 -TargetDir ".\codewave-dependency"

# 单独做环境检查
.\scripts\preflight-check.ps1
```

常用话术：

```text
请按标准案例一键打包 CodeWave 依赖库，首次版本使用 1.0.0，输出两个 library-*.zip 和导入教程。
请检查这个项目是否具备 CodeWave 依赖库脚手架；没有的话先安装脚手架，再迁移前端、后端和 SQL。
请不要打源码包，默认交付 CodeWave 可导入的两个依赖库包。
请帮我排查为什么 CodeWave 提示不是依赖库格式，先检查 zip 根目录结构。
请帮我生成首次导入使用教程，包含导入顺序、页面进入事件 callApi、getAppHtml JS 和验收清单。
请把本次打包版本号从 1.0.0 递增到 1.0.1 后重新打包。
请优先使用本机 Chrome 或 Edge 做自动化测试；本机浏览器不存在或启动失败时，再自动安装 Playwright Chromium。
```

手动流程：

1. 执行客户本机基础环境检查；缺工具先提示安装。
2. 检测是否存在 CodeWave 依赖库脚手架。
3. 如果没有脚手架，默认安装脚手架并迁移用户代码。
4. 修改依赖库 `pom.xml` 版本。
5. 构建前端单文件产物。
6. 将前端 HTML 写入后端依赖库静态资源。
7. 使用正确 JDK 构建依赖库。
8. 产出服务依赖库包和代理依赖库包两个 `library-*-{version}.zip`。
9. 分别打开两个 zip 校验 CodeWave 依赖库格式。
10. 将两个 zip 和导入教程复制到统一交付目录，例如 `target\packages`。
11. 扫描两个包内冲突依赖和敏感信息。

注意：公开仓库源码包不是 CodeWave 依赖库包。可导入平台的是各模块 `target` 目录或标准案例 `dist/.../packages/` 目录下的 `library-*.zip`。开发者修改 Maven `artifactId` 或依赖库名称后，文件名会变化，不能写死为某个示例名称。

严禁只凭文件名判断依赖库是否可上传。文件名叫 `library-xxx.zip` 也可能不是合规依赖库包。对外输出“可上传到 CodeWave”的包之前，必须打开 zip 校验根目录至少包含：

```text
source.zip
nasl-metadata.json
manifest
library/*.jar
library/*.pom
```

如果缺少上述任一项，不得称为“可上传依赖库包”，应提示重新检查 Maven 插件配置，确保执行了 `nasl-metadata-maven-plugin` 的 `archive` 目标。

### 5. 校验

交付前必须检查：

- 客户机器基础环境已通过：PowerShell、Git、Node/npm、JDK、JAVA_HOME、Maven、Maven/npm 网络源
- 输入工程已具备 CodeWave 依赖库脚手架；没有脚手架时已默认安装并完成适配
- 服务依赖库包和代理依赖库包都存在且版本正确；除非用户明确要求单包模式，否则缺任意一个都视为未完成
- 统一交付目录存在，且至少包含两个 `library-*.zip` 和 `codewave-import-usage.md`
- 两个 zip 根目录都包含 `source.zip`、`nasl-metadata.json`、`manifest`、`library/*.jar`、`library/*.pom`
- 两个 zip 的 `nasl-metadata.json` 都包含顶层 `compilerInfoMap`、`logics`、`summary`，且 `logics` 不为空
- 代理依赖库的 `nasl-metadata.json` 顶层 `logics` 必须包含名称完全等于 `getAppHtml` 和 `callApi` 的 Logic；如果 CodeWave “调用逻辑”列表里找不到 `getAppHtml`，视为打包失败
- 不包含 `node_modules`、`target`、`.git` 等无关产物
- 不包含真实 AppSecret、数据库密码、API Key
- 不包含平台冲突依赖
- `getAppHtml` 可返回完整 HTML
- `getAppHtml.data` 是字符串，且以完整 HTML 文档形式返回，不是 style/script/body 片段
- `app.html` 已通过 `skill/scripts/validate-app-html.ps1` 校验，内联脚本不存在顶层 `return` 等语法错误，且不存在 `/api/...` 业务路径；本机没有 Node.js 时必须停止校验和交付
- 页面进入 JS 使用异步自执行函数，不对 `undefined` 直接读取 `length`
- 全部前端源码已通过 `skill/scripts/validate-frontend-proxy-usage.ps1`，不存在绕过 `callApi` 的业务直连
- 默认内置后端已通过 `skill/scripts/validate-backend-mode.ps1`，不依赖外部 Base URL，并使用平台 `DataSource`
- `callApi` 可完成基础 CRUD
- 默认 `callApi(reqPath=/simple)` 可触发健康检查和数据库初始化；库表不存在时能自动创建或给出手动执行 `sql/init.sql` 的中文提示
- 上传文件 URL 可从浏览器直接访问
- 开发/生产环境路径不写死

### 6. 排障

遇到以下问题时读取 `references/troubleshooting.md`：

- `callApi` 返回 401
- `callApi` 返回“未配置 CRM 后端地址”或要求设置 `*.backend.base-url`
- 浏览器显示 `callApi net::ERR_CONNECTION_CLOSED`、`0 B transferred` 或无法读取响应
- PowerShell 禁止执行脚本
- npm 或 Maven 依赖下载失败
- 只生成一个依赖库包
- 客户找不到最终交付包
- 平台生产发布依赖冲突
- Maven 元数据插件无法下载或 `nasl-metadata.json` 缺少 `logics`
- `HttpSecurity` 或 Spring Security 类缺失
- MIME 类型错误或静态资源加载失败
- 数据库插入成功但查询不到
- 时间戳写入 datetime 报错
- 图片上传后不回显
- 小程序开发版/体验版环境不一致

## 输出要求

根据用户任务输出对应成果：

- 若是创建标准案例：输出目录结构、关键文件、打包产物路径和使用说明。
- 若是修复依赖库：说明改了什么、产物 zip 在哪里、如何导入平台。
- 若是打包交付：默认输出可导入 CodeWave 的两个 `library-*.zip` 依赖库包，服务依赖库包在前、代理依赖库包在后，并同步输出导入使用教程；仅在用户明确要求单包时输出一个依赖库包，仅在用户明确要求源码包时输出源码资料包。
- 若是客户首次使用：优先输出一条龙步骤，明确“运行哪个脚本、交付目录在哪里、导入哪两个包、页面进入事件怎么配、怎么验收成功”，不要只给零散命令。
- 若是排障：先给根因，再给修复动作和验证方法。
- 若是写文档：使用中文，避免暴露真实项目路径、域名、密钥和客户隐私。

首次打包或首次交付时，必须附带一份中文使用教程文档，至少包含：

- 依赖库导入顺序：先服务依赖库，再代理依赖库。
- CodeWave 页面创建方式：创建一个承载页面，例如 `simple`。
- 后端地址说明：默认后端随依赖库运行，不需要在前端填写外部后端域名；如需外部后端，只能放在代理依赖库服务端配置或平台环境配置中。
- callApi 代理说明：不需要填写 CodeWave 平台地址、开发环境地址或生产环境地址；页面进入 JS 和前端请求都使用相对路径，当前页面在哪个环境运行就自动代理到哪个环境。
- 数据库初始化说明：首次 `callApi(reqPath=/simple)` 会触发库表初始化；无建表权限时手动执行 `sql/init.sql`。
- 页面进入事件第一步：先用平台“调用逻辑”节点调用 `callApi`，默认参数 `reqPath=/simple`、`reqMethod=GET`、`reqBody={}`。
- 页面进入事件第二步：再添加 JS 代码块，通过相对路径调用 `getAppHtml` 并 `document.write` 注入 HTML。
- 架构边界说明：`getAppHtml` 在代理依赖库中，因为它是页面入口和静态 HTML 承载能力；服务依赖库只承载业务服务能力。
- 完整 JS 示例，且不允许写死生产域名、开发域名或额外 `/api` 前缀。
- 教程正文内必须直接展示 `assets/codewave-page-entry.js` 的完整代码，同时同步交付该独立文件，要求客户完整粘贴，不得拆散函数结构。
- 如果代理路径被开发者改名，教程必须提示把 `/simple_proxy` 替换成实际代理路径。
- 发布开发环境、验证、发布生产环境的检查清单。

标准案例脚本会输出 `target\codewave-import-usage.md`；非标准案例也必须输出等价教程，不得只给 zip 包。

## 质量红线

- 不把真实项目当公开模板。
- 不把真实密钥写入 Skill、示例代码或 README。
- 不把完整业务后端服务包塞进 CodeWave 依赖库。
- 不因 Maven 插件下载失败而手工组包或伪造 `nasl-metadata.json`。
- 不在平台前端写死 `/api/xxx` 或生产域名，除非用户明确要求。
- 不用 PC 网页截图冒充微信小程序截图。
- 不把 Skill 写成泛泛介绍；必须能指导 Agent 实际完成打包、导入和排障。
