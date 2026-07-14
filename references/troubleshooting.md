# CodeWave 依赖库常见排障

## callApi 401

现象：

```json
{
  "Code": 401,
  "Message": "接口无权限访问"
}
```

排查：

1. 平台页面调用路径是否写成了错误的 `/api/...`。
2. Network Payload 中 `reqPath` 是否误写成 `/api/customers`；正确值是 `/customers`。
3. 浏览器 Network 中失败请求名称是否是 `customers`、`users` 等业务路径，而不是固定的 `callApi`。
4. 前端是否在页面进入时调用过一次 `callApi` 后，又直接请求 `/项目代号_proxy/customers` 等独立路由。
5. 依赖库版本是否被平台缓存。
6. 代理接口是否被平台鉴权拦截。
7. 是否删除了平台需要的兼容依赖或权限配置。

修复：

- 使用标准相对路径。
- 删除 `reqPath` 中的 `/api`，例如把 `/api/customers` 改成 `/customers`。
- 把所有查询、新增、编辑和删除请求统一改为 `POST /项目代号_proxy/callApi`，并将业务路径放入 `reqPath`。
- 运行 `skill/scripts/validate-frontend-proxy-usage.ps1`；校验失败时不要打包。
- 递增依赖库版本重新导入。
- 保留平台要求的兼容包。

## callApi 连接被关闭

现象：Network 显示 `0 B transferred`、`Failed to load response data`，Console 显示 `callApi net::ERR_CONNECTION_CLOSED`。

说明：Chrome 会把 `/crm_proxy/callApi` 相对路径显示成当前页面域名下的完整 URL，这不代表前端配置了平台地址。连接关闭表示网关或运行实例没有返回 HTTP 响应。

排查顺序：

1. 检查 Payload，先把 `reqPath=/api/customers` 改为 `/customers`。
2. 修复 Console 中的 `Illegal return statement`，删除旧页面进入 JS 后完整粘贴标准异步自执行函数。
3. 递增版本重新打包、导入并发布，排除旧依赖库缓存。
4. 仍为 `0 B` 时查看 CodeWave 运行日志和实例状态；不要通过填写平台域名解决。

## 提示“未配置后端地址”

现象：`callApi` 已经到达代理依赖库，但返回“未配置 CRM 后端地址，请设置 `crm.backend.base-url`”等错误。

原因：生成工程被错误实现成了外部后端反向转发模式。CodeWave 平台地址不是外部后端 Base URL，不能填写平台域名解决。

修复：

- 普通 CRUD/RBAC 项目删除 `*.backend.base-url`、`BACKEND_BASE_URL`、`backendBaseUrl`、`upstreamBaseUrl` 和通用转发实现。
- 在依赖库 Handler/Service 内按 `reqPath` 分发业务，使用平台注入的 `DataSource` 完成 CRUD 和幂等初始化。
- 运行 `skill/scripts/validate-backend-mode.ps1`，递增版本重新打包。
- 用 `skill/scripts/inspect-proxy-library.ps1` 检查最终代理 ZIP 后再导入。
- 只有用户明确已有独立后端时，才能使用 `-AllowExternalBackend`；不得把该开关当作错误绕过方式。

## MIME 或静态资源加载失败

原因：

- Vite 输出了 `/assets/*.js`，平台没有按静态资源方式提供。

修复：

- 构建单文件 HTML。
- `getAppHtml` 返回完整 HTML。

## getAppHtml 返回 200 但页面白屏

典型报错：

```text
Uncaught SyntaxError: Illegal return statement
Cannot read properties of undefined (reading 'length')
```

原因：

- 页面进入 JS 在顶层使用了 `return`，没有放在函数体内。
- `getAppHtml.data` 为空、字段层级取错，或返回的不是字符串。
- 返回内容仅以 `<style>`、`<script>` 等片段开头，不是完整 HTML 文档。
- 前端构建结果仍依赖 `/assets/*` 分包资源。

修复：

- 页面进入 JS 整体使用异步自执行函数，禁止顶层 `return`。
- 按 `resultCode` 和 `data` 解析统一响应，不要对未定义值直接读取 `length`。
- 重新构建完整单文件 HTML，并运行 `skill/scripts/validate-app-html.ps1`。
- 校验失败时不要打包或上传 CodeWave；修复后递增两个依赖库版本再重新导入。

## `/crm_proxy/getAppHtml No message available`

典型返回：

```json
{
  "ErrorType": "nasl.error.SystemResourceNotFoundError",
  "Message": "/crm_proxy/getAppHtml No message available",
  "Code": 200
}
```

原因：

- 页面进入 JS 请求了 `/crm_proxy/getAppHtml`，但代理依赖库实际暴露的 HTTP 控制器仍是 `/simple_proxy/getAppHtml`。
- 只在 CodeWave 页面里调用 `callApi` 上报了平台逻辑，没有同步暴露 `getAppHtml` HTTP 路由。
- 重新导入依赖库后没有发布到当前开发或生产环境，页面仍在跑旧版本。

修复：

- 先直接测试当前依赖库真实地址：`/simple_proxy/getAppHtml` 和 `/crm_proxy/getAppHtml` 哪个存在。
- 如果要使用 `/crm_proxy`，同步修改页面进入 JS、前端 `API_BASE`、Vite 代理、Java `RawController @RequestMapping` 和教程文档。
- 递增两个依赖库版本，重新打包、导入并发布当前环境。
- 打包前运行 `skill/scripts/validate-proxy-path-consistency.ps1`，确认代理前缀一致。
- 对最终上传的代理依赖库包运行 `skill/scripts/inspect-proxy-library.ps1 -ProxyZip <代理library-*.zip> -ProxyBase /crm_proxy`，确认包内 `source.zip` 真的包含 `/crm_proxy/callApi`、`@RequestMapping("/crm_proxy")`、`@PostMapping("/getAppHtml")` 和 `@PostMapping("/callApi")`。

## 生产发布依赖冲突

现象：

- `HttpSecurity` 找不到
- Spring Security 冲突
- MyBatis-Plus 启动失败

修复：

- 依赖库避免打入完整业务服务依赖。
- 保留必要兼容包。
- 对平台已有依赖使用 provided 或移除。

## Maven 元数据插件无法下载

原因：

- `nasl-metadata-maven-plugin`、`nasl-metadata-collector` 不在客户当前 Maven Central 或公共镜像中。
- 客户本地 Maven 仓库没有缓存对应版本。

修复：

- 确认 `skill/assets/codewave-maven-repository` 包含与 `pom.xml` 一致的插件、采集器 JAR/POM。
- 执行 `scripts/prepare-codewave-maven-cache.ps1`，由标准打包脚本自动使用 `.codewave-maven-cache`。
- 公共依赖仍可从客户 Maven 镜像下载；CodeWave 专用构件从项目内仓库解析。
- 禁止手工创建 `nasl-metadata.json` 或用普通压缩命令模拟依赖库。

## CodeWave 导入后不显示逻辑

检查依赖库 zip 中的 `nasl-metadata.json`。必须同时存在顶层 `compilerInfoMap`、`logics`、`summary`，并且 `logics` 中至少有一项 `concept: Logic`。

缺少 `logics` 说明包不是由完整 Maven 元数据插件流程生成。修复插件解析后重新执行 `mvn clean package`，递增依赖库版本再导入；不要在旧 zip 中直接补 JSON。

## 数据库插入成功但查询不到

排查：

1. 是否连接了错误数据库。
2. 是否事务未提交。
3. 是否逻辑删除字段过滤。
4. 是否创建接口和列表接口查的是不同表或不同状态。

修复：

- 统一 DataSource。
- 显式提交或使用正确事务边界。
- 如果接口返回生成的 ID 但数据库没有记录，优先检查 `Connection.getAutoCommit()`；手动提交模式下必须在成功路径调用 `commit()`，异常路径调用 `rollback()`，然后重新递增版本并发布新包。
- 在 CodeWave 中调用 `/simple`，确认返回 `mode=embedded-backend` 和核心表计数，再在同一发布环境数据库执行查询；不要用本地 MySQL 代替平台数据库验证。
- 查询条件包含逻辑删除和状态字段。

## datetime 字段报时间戳错误

现象：

```text
Incorrect datetime value: '1780243200000'
```

原因：

- 前端把毫秒时间戳直接写入 MySQL datetime。

修复：

- 提交前统一格式化为 `yyyy-MM-dd HH:mm:ss`。
- 后端写入使用 `LocalDateTime` 或 SQL `now()`。

## 图片上传后不回显

排查：

1. 返回 URL 是否能浏览器直接访问。
2. 数据库是否保存了新 URL。
3. 编辑保存是否被 datetime 或其他字段错误回滚。
4. 前端是否显示旧缓存。

修复：

- 上传接口返回 HTTPS URL。
- 保存接口成功后重新查询详情。
- 修复保存事务中的其他字段错误。

## 小程序环境混乱

规则：

- 正式版小程序走生产域名。
- 开发版或体验版如果要走开发环境，使用独立小程序目录或独立配置。
- 体验版启动页在微信开发者工具上传时设置。

不要用 PC 端网页截图冒充小程序截图。小程序操作手册截图应来自微信开发者工具模拟器或真实手机。

## 自动化测试重复下载 Chromium

原因：

- 测试流程一开始就执行了 `playwright install chromium`。
- Playwright 没有通过 `executablePath` 尝试本机 Chrome 或 Edge。

修复：

- 使用 `skill/assets/launch-playwright-browser.js` 的 `launchPreferredBrowser()` 启动测试浏览器。
- 固定顺序为本机 Chrome、本机 Edge、Playwright Chromium。
- 本机浏览器不存在或实际启动失败时，辅助脚本会自动安装 Playwright Chromium。
- 如果 Playwright 运行库本身不存在，先安装运行库；不要在确认本机浏览器不可用前安装浏览器二进制。

## 新客户版本号从历史版本开始

原因：模板 `pom.xml` 保存了维护者最后一次打包版本，例如 `1.0.17`。

修复：

- 对外模板的两个 `pom.xml` 都固定为 `1.0.0`。
- 客户首次构建允许使用 `1.0.0`。
- 本机已经生成过 `1.0.0` 后，再次打包必须使用 `1.0.1` 或更高版本。
