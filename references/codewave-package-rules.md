# CodeWave 依赖库封装规则

## 客户本机构建环境检查

打包前先检查客户机器是否具备构建环境。不要默认客户已经安装 Node、JDK、Maven 或 Git。

优先执行：

```powershell
scripts\preflight-check.ps1
```

必须检查：

```text
PowerShell 5.1+ 或 PowerShell 7+
Git
Node.js LTS
npm
JDK 8 或 JDK 11
JAVA_HOME
Maven 3.6+
Maven 仓库网络
npm 仓库网络
zip 读取能力
CodeWave 依赖库上传/发布权限
```

处理规则：

- 缺 Node/npm：先提示客户安装 Node.js LTS，或在确认已有单文件 HTML 后跳过前端构建。
- 缺 JDK/JAVA_HOME：先提示安装 JDK 并配置 JAVA_HOME，JRE 不可替代 JDK。
- 缺 Maven：先提示安装 Maven 并加入 PATH。
- Maven/NPM 网络不可用：先配置公司镜像、代理或私服。
- 无 CodeWave 上传权限：让客户切换有权限账号或找管理员授权。
- 环境检查未通过时，不允许继续输出“可上传依赖库包”。

## CodeWave Maven 元数据插件离线仓库

`nasl-metadata-maven-plugin` 和 `nasl-metadata-collector` 可能不在客户配置的 Maven Central 或公共镜像中。标准案例必须按 Maven 坐标目录内置：

```text
skill/assets/codewave-maven-repository/
  com/netease/lowcode/
    nasl-metadata-maven-plugin/<版本>/插件.jar + 插件.pom
    nasl-metadata-collector/<版本>/采集器.jar + 采集器.pom
```

打包脚本必须执行 `scripts/prepare-codewave-maven-cache.ps1`，复制到项目级 `.codewave-maven-cache`，然后给 Maven 传入：

```text
-Dmaven.repo.local=<项目>/.codewave-maven-cache
```

内置坐标必须与两个模块 `pom.xml` 完全一致。Agent 生成新工程时必须复制这份 Skill 资产。缺任意 JAR/POM 时停止构建并给出中文提示，不得静默切换到手工组包。

依赖库 zip 校验除文件结构外，还必须读取 `nasl-metadata.json` 并检查：

```text
顶层 compilerInfoMap
顶层 logics
顶层 summary
至少一项 concept = Logic
```

缺少 `logics` 时，即使 zip 可以上传，也不能称为合格依赖库，因为 CodeWave 无法展示和调用逻辑。

## 自动化测试浏览器

执行网页自动化测试时使用以下固定降级顺序：

```text
本机 Chrome 可启动 -> 使用本机 Chrome
本机 Chrome 不可用，本机 Edge 可启动 -> 使用本机 Edge
本机 Chrome/Edge 均不可用 -> 自动安装并使用 Playwright Chromium
```

可先运行 `skill/scripts/resolve-test-browser.ps1` 做可执行文件预检。实际 Playwright 测试必须调用 `skill/assets/launch-playwright-browser.js` 中的 `launchPreferredBrowser()`：它会通过 `executablePath` 依次真实启动本机 Chrome、Edge；全部启动失败后，自动安装并使用 Playwright Chromium。不能一开始就执行 `playwright install chromium`。

测试使用独立临时用户数据目录，不读取或锁定客户日常浏览器配置，不弹出影响客户工作的可见窗口。只有本机浏览器不存在或启动失败时，才允许自动下载 Playwright 浏览器。

## 代理接口

标准代理接口：

```text
/simple_proxy/getAppHtml
/simple_proxy/callApi
```

代理依赖库必须同时提供 CodeWave 后端逻辑和 HTTP 路由：

- Facade 中必须有 `@NaslLogic public ... getAppHtml(...)`，逻辑名固定为 `getAppHtml`。
- Facade 中必须有 `@NaslLogic public ... callApi(...)`，逻辑名固定为 `callApi`。
- `nasl-metadata.json` 顶层 `logics` 必须同时包含 `name=getAppHtml` 和 `name=callApi`。
- RawController 中再暴露 `/项目代号_proxy/getAppHtml` 和 `/项目代号_proxy/callApi`。
- 后端逻辑和 HTTP 路由必须复用同一个 handler/service，不要分别写两套业务实现。

如果 CodeWave 的“调用逻辑”列表找不到 `getAppHtml`，即使 HTTP `/xxx_proxy/getAppHtml` 能访问，也属于不合格依赖库；必须修复 `@NaslLogic` 或 Maven 元数据生成流程后重新打包。

首次打包或首次交付时，必须同步输出中文导入使用教程，说明 CodeWave 依赖库导入顺序、承载页创建方式、页面进入事件两步配置、`callApi` 默认参数、`getAppHtml` JS 代码块、开发/生产发布验证清单。标准案例教程文件为 `target/codewave-import-usage.md`。

教程中的 `getAppHtml` JS 代码块必须是 `skill/assets/codewave-page-entry.js` 的完整原文，客户不打开其他文件也能直接复制。代码块内外都不要添加“开始复制/结束复制”、HTML 标记、说明性注释或其他包裹内容。打包前运行 `skill/scripts/validate-page-entry-doc.ps1`；独立文件和教程代码任何一处发生漂移都必须停止打包。

默认交付必须包含两个依赖库包：

```text
service-library/target/library-*.zip
backend-library/target/library-*.zip
```

导入顺序固定为先服务依赖库包，再代理依赖库包。除非用户明确要求单包模式，否则只输出一个代理包属于未完成。

打包脚本还必须把两个依赖库包和导入教程汇总到统一交付目录：

```text
target/packages/
  library-*.zip
  library-*.zip
  codewave-import-usage.md
```

客户导入时优先使用统一交付目录，不要让客户自己去两个模块的 `target` 目录里找包。

可选上传接口：

```text
/simple_proxy/uploadImage
/simple_proxy/uploadVideo
```

先在 CodeWave 中创建一个平台承载页，例如 `simple`。

页面进入事件一般分两步：

1. 先放一个平台“调用逻辑”节点调用 `callApi`，让 CodeWave 上报依赖库接口权限。

```text
reqPath    = /simple
reqMethod  = GET
reqBody    = {}
```

2. 再放 JS 代码块调用 `getAppHtml` 写入页面。

```js
(async function () {
  const res = await fetch('/simple_proxy/getAppHtml', { method: 'POST' }).then(r => r.json());
  const html = res.Data || res.data || '';
  document.open();
  document.write(html);
  document.close();
})();
```

项目内部 API 统一走：

```js
var API_BASE = '/simple_proxy/callApi'
```

这是强制的代理零配置规则：不要在前端写死开发或生产域名，不要让客户填写 CodeWave 平台地址、代理服务器地址、开发环境地址或生产环境地址，也不要增加 `/api` 前缀。`/simple_proxy/callApi` 是相对路径，会跟随当前页面所在环境自动代理。

以下写法都必须在打包前拦截：

```text
/api/simple_proxy/callApi
https://example.com/simple_proxy/callApi
http://127.0.0.1/simple_proxy/callApi
```

`callApi` 请求体只放业务路由参数，例如 `reqPath`、`reqMethod`、`reqBody`，不要增加 `platformUrl`、`baseUrl`、`host`、`domain` 这类平台地址字段。

`reqPath` 不属于浏览器或网关地址，它是依赖库内部路由，因此不带 `/api`：

```text
正确：reqPath=/customers
错误：reqPath=/api/customers
```

前端源码、构建后的 `app.html` 和最终代理依赖库 `source.zip` 必须分别校验，任何一层出现字符串 `/api/...` 都停止打包。

前端的每一次 CRUD 请求都必须继续访问固定入口，不能只在页面进入时调用一次 `callApi`，随后改为直连业务路径：

```text
正确：POST /crm_proxy/callApi，reqPath=/customers
错误：GET  /crm_proxy/customers?keyword=
```

`callApi` 返回 200 仅表示该固定逻辑已注册并可访问，不会自动授权 `/crm_proxy/customers` 等独立 HTTP 路由。打包前必须运行 `skill/scripts/validate-frontend-proxy-usage.ps1` 扫描整个前端目录；扫描到业务直连、裸代理基址、完整域名或 `/api` 前缀时停止交付。

代理前缀可以由开发者改名，但必须全链路一致。把 `/simple_proxy` 改成 `/crm_proxy` 时，至少同步修改：

- `skill/assets/codewave-page-entry.js` 中的 `getAppHtmlUrl`
- 前端 `API_BASE`
- `frontend/vite.config.js` 的本地代理前缀
- Java RawController 的 `@RequestMapping`
- 导入教程中的页面进入 JS 和接口说明

只改页面进入 JS 会让浏览器请求 `/crm_proxy/getAppHtml`，而依赖库仍只暴露 `/simple_proxy/getAppHtml`，CodeWave 会返回 `SystemResourceNotFoundError` 或 `No message available`。打包前运行 `skill/scripts/validate-proxy-path-consistency.ps1`，失败时停止交付。
若打包脚本支持参数，改名后必须用新前缀执行，例如 `scripts\package.ps1 -Version 1.0.1 -ProxyBase '/crm_proxy'`。

生成新项目时不要把示例前缀原样保留。根据用户项目名自动推导代理前缀：

```text
CRM 项目 -> /crm_proxy
OA 系统 -> /oa_proxy
WMS 仓储项目 -> /wms_proxy
```

落地时优先执行：

```powershell
skill\scripts\set-proxy-base.ps1 -ProjectRoot examples\simple-codewave-dependency -ProjectCode crm
```

该脚本会同步页面进入 JS、前端 `API_BASE`、Vite 本地代理、Java `RawController @RequestMapping` 和教程路径，并立即执行一致性校验。
打包后还必须运行 `skill\scripts\inspect-proxy-library.ps1 -ProxyZip <代理library-*.zip> -ProxyBase /crm_proxy` 或由打包脚本自动执行，确认最终上传包内也已经同步。

## 后端地址模式

默认采用“依赖库内置后端”模式：

```text
前端页面 -> /simple_proxy/callApi -> 代理依赖库内部路由 -> 平台 DataSource/服务依赖库
```

这种模式不需要客户再配置一个公网后端地址。CodeWave 发布到开发环境时，请求自然落到开发环境依赖库；发布到生产环境时，请求自然落到生产环境依赖库。
也不需要客户配置 CodeWave 平台自身地址，当前页面的相对路径会自动解析到当前平台环境。

只有用户明确要求复用已有外部后端时，才采用“外部后端转发”模式：

```text
前端页面 -> /simple_proxy/callApi -> 代理依赖库 -> 外部后端 Base URL
```

外部后端 Base URL 只能存放在服务端配置、环境变量或平台配置中，不能写入前端代码、导入教程或公开仓库示例。代理层负责根据开发/生产环境读取不同地址，并统一做超时、错误转换和鉴权处理。

默认不采用该模式。普通业务案例必须把 `reqPath` 分发、CRUD、RBAC 和数据库初始化实现在依赖库 Handler/Service 中，并使用 CodeWave 平台注入的 `DataSource`。打包前运行 `skill/scripts/validate-backend-mode.ps1`，打包后运行 `skill/scripts/inspect-proxy-library.ps1`；任一处发现 `*.backend.base-url`、`BACKEND_BASE_URL`、上游地址变量或“未配置后端地址”提示都停止交付。

只有用户明确要求对接已有独立后端时，才允许打包命令增加 `-AllowExternalBackend`。该开关不是故障绕过参数，不能为了消除校验错误自动启用。

## callApi 请求结构

```json
{
  "reqPath": "/simple",
  "reqMethod": "GET",
  "reqBody": "{}"
}
```

后端返回：

```json
{
  "resultCode": 200,
  "resultMsg": null,
  "data": "{}",
  "success": true
}
```

默认 `reqPath=/simple` 的调用必须能完成两件事：

- 让 CodeWave 上报并放行依赖库接口权限。
- 触发依赖库后端的库表初始化与健康检查。

## getAppHtml

前端应构建成单文件 HTML，避免平台加载 `/assets/*.js` 时出现 MIME 或路径问题。

推荐流程：

1. Vite 构建单文件 HTML。
2. 复制到依赖库 `src/main/resources/static/app.html`。
3. Facade 的 `@NaslLogic getAppHtml` 和 RawController 的 `/getAppHtml` 都读取同一份文件并返回字符串。

强制格式：

- `getAppHtml` 必须是 CodeWave 后端逻辑名，不要改成其他名字。
- `getAppHtml` 必须出现在 `nasl-metadata.json` 的 `compilerInfoMap.java` 和顶层 `logics` 中。
- `data` 必须是字符串，不得返回对象、数组或未定义值。
- 字符串必须是 UTF-8 完整 HTML 文档，包含 `<!doctype html>`、`<html>`、`<head>`、`<body>` 和结束标签。
- 禁止只返回 `<style>`、`<script>`、`<body>` 等页面片段。
- 禁止引用 `/assets/*.js`、`/assets/*.css` 等前端分包资源。
- 内联 JavaScript 必须通过语法检查，禁止存在顶层 `return`。
- 打包前必须执行 `skill/scripts/validate-app-html.ps1 -HtmlPath <app.html路径>`；失败时立即停止打包。

页面进入 JS 必须整体放在异步自执行函数中。不得把函数内部的 `return`、异常分支或响应处理代码拆开粘贴到 CodeWave JS 代码块顶层。响应解析时先判断 `data` 类型，再检查完整文档结构，不能直接读取 `html.length`。

## 上传

上传返回值必须包含可直接访问的 URL：

```json
{
  "url": "https://example.com/uploads/2026/01/01/a.png",
  "relativeUrl": "/uploads/2026/01/01/a.png"
}
```

数据库保存 `url`。不要保存平台内部临时地址。

## 数据库初始化

标准案例必须同时提供自动初始化和手动 SQL 两条路径。

自动初始化：

- 依赖库后端通过平台注入的 `DataSource` 获取连接。
- 首次调用 `callApi` 默认接口或任意业务接口前执行 `ensureSchema` 类逻辑。
- 使用 `CREATE TABLE IF NOT EXISTS` 创建表。
- 使用 `INSERT INTO table (...) SELECT ... WHERE NOT EXISTS (SELECT 1 FROM table WHERE id = ?)` 写入默认数据。这是 CRM 标准案例验证可用的默认格式，Java 自动初始化和 `sql/init.sql` 都应采用同一格式。
- 不要优先使用 `INSERT IGNORE INTO ... VALUES ...` 作为种子数据默认格式；目标平台数据库兼容模式不一致时，可能出现表已创建但数据未插入。
- 初始化完成后必须查询核心表数量并断言默认数据已存在。不能只看到表创建成功就认为初始化完成。
- `callApi(reqPath=/simple, reqMethod=GET, reqBody={})` 必须返回种子数据统计，便于客户判断是“表未创建”“无插入权限”还是“导入了旧包”。
- 初始化完成后可在进程内设置标记，避免每个请求重复执行完整初始化。

事务与落库验收：

- 每个写请求必须使用明确事务边界；如果 JDBC 连接处于手动提交模式，成功路径必须 `commit()`，异常路径必须 `rollback()`。
- 不得因为接口返回生成的自增 ID 或 HTTP 200 就判定数据已落库；必须在同一业务入口再次查询或统计确认，并在交付验收中查询平台当前环境数据库。
- 默认健康接口应返回内置模式标识和核心表数量，便于区分“使用了旧包”“连错环境数据库”和“事务回滚”。

手动初始化：

- 在 `sql/init.sql` 保留同等表结构和默认数据。
- 如果平台数据库账号没有建表权限，导入教程必须提示客户先由管理员手动执行该 SQL。

禁止：

- 在公开案例中写真实 JDBC URL、真实库名、账号或密码。
- 用 `DROP TABLE`、`TRUNCATE` 或清空表的方式初始化。
- 把毫秒时间戳直接写入 datetime 字段。
- 只提供 SQL 文件但没有说明什么时候执行、谁执行、执行失败怎么处理。

## 环境自适应

前端：

- 使用相对路径调用代理。
- 不写死 `dev-` 或生产域名。

后端：

- 通过请求来源或配置识别 baseUrl。
- 上传地址按当前环境拼接。

小程序：

- 生产版固定生产域名。
- 开发版可复制独立目录并配置开发域名。

## 依赖控制

CodeWave 依赖库应尽量轻量。

避免打入：

- Spring Security 完整体系
- MyBatis-Plus 与平台冲突版本
- 完整业务后端服务 jar
- 与平台运行时重复的重量依赖

如果只需要代理和 JDBC，优先使用 JDK、Jackson、Spring Web 的轻依赖组合。

## 版本规则

标准案例源码版本从 `1.0.0` 开始。客户首次打包时直接使用 `1.0.0`，不能继承模板维护过程中的历史版本。

首次打包完成后，每次重新导入平台前必须递增版本号：

```text
1.0.0 -> 1.0.1
1.0.1 -> 1.0.2
```

不要用同版本覆盖，否则平台可能使用缓存旧包。

执行规则：

- 服务依赖库和代理依赖库必须使用同一个新版本号。
- 除首次 `1.0.0` 构建外，新版本号必须大于两个模块当前 `pom.xml` 里的版本号。
- 首次构建且本机不存在同版本产物时，允许 `pom.xml` 和打包参数都使用 `1.0.0`。
- 默认递增最后一位，例如 `1.0.0 -> 1.0.1`。
- 首次构建完成后，打包脚本遇到相同版本或更低版本时必须停止，不允许继续生成交付包。
- 对客户说明时要明确：“每次重新导入 CodeWave 前都要升版本，否则平台可能仍使用旧缓存。”

常用命令：

```powershell
.\scripts\package-standard-case.ps1 -Version "1.0.0"
.\scripts\package-standard-case.ps1 -Version "1.0.1" -SkipPreflight
.\scripts\preflight-check.ps1
.\scripts\install-codewave-scaffold.ps1 -TargetDir ".\codewave-dependency"
```

## 依赖库 zip 格式校验

不要只看文件名。`library-xxx.zip` 只有在包内结构符合 CodeWave 依赖库格式时，才可以提示用户上传。

## CodeWave 脚手架检测与默认安装

在打包前先判断用户项目是否具备 CodeWave 依赖库脚手架。普通 Java/Vue/Node 项目即使能构建成功，也不是 CodeWave 依赖库工程。

最低判断条件：

```text
pom.xml
nasl-metadata-maven-plugin
archive goal
scanPackage
src/main/resources/META-INF/spring.factories
可扫描到的 facade/config Java 类
```

如果用户项目缺少这些内容，默认执行脚手架安装流程：

```powershell
scripts\install-codewave-scaffold.ps1 -TargetDir ".\codewave-dependency"
```

然后把用户代码迁移到脚手架：

1. 前端构建为单文件 HTML，写入代理模块 `src/main/resources/static/app.html`。
2. 后端接口迁移到代理模块 `callApi` 路由或服务模块 facade。
3. 数据库初始化 SQL 放入 `sql/init.sql`。
4. 修改 `pom.xml` 的 `groupId`、`artifactId`、`version`、`scanPackage`。
5. 再执行依赖库打包。

如果未安装脚手架，不允许生成或交付所谓“可上传依赖库包”。

必须打开 zip 检查根目录至少包含：

```text
source.zip
nasl-metadata.json
manifest
library/*.jar
library/*.pom
```

常见错误：

- 只用 `Compress-Archive` 把源码目录压成 zip。
- Maven 没有执行 `nasl-metadata-maven-plugin` 的 `archive` 目标。
- 只生成普通 jar 或普通 zip，却手工改名为 `library-xxx.zip`。
- Agent 只按文件名 `library-*.zip` 输出“可上传”，但没有验包。
- Maven 插件失败后手写只有 `compilerInfoMap` 和 `summary` 的 `nasl-metadata.json`，导致 CodeWave 不展示逻辑。

验包失败时，不要让用户上传，应先修 Maven 插件配置或重新执行标准打包脚本。

## 敏感信息

公开标准案例中必须替换：

- 数据库密码
- AppSecret
- AppKey
- API Key
- 真实域名
- 真实库名
- 客户名称
- 个人手机号

使用占位：

```text
CHANGE_ME_DB_PASSWORD
CHANGE_ME_WX_APPID
CHANGE_ME_WX_SECRET
CHANGE_ME_SMS_APP_KEY
CHANGE_ME_SMS_APP_SECRET
```
