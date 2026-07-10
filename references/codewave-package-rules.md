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

## 代理接口

标准代理接口：

```text
/simple_proxy/getAppHtml
/simple_proxy/callApi
```

首次打包或首次交付时，必须同步输出中文导入使用教程，说明 CodeWave 依赖库导入顺序、承载页创建方式、页面进入事件两步配置、`callApi` 默认参数、`getAppHtml` JS 代码块、开发/生产发布验证清单。标准案例教程文件为 `target/codewave-import-usage.md`。

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

不要在前端写死开发或生产域名。

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

## getAppHtml

前端应构建成单文件 HTML，避免平台加载 `/assets/*.js` 时出现 MIME 或路径问题。

推荐流程：

1. Vite 构建单文件 HTML。
2. 复制到依赖库 `src/main/resources/static/app.html`。
3. `getAppHtml` 读取该文件并返回字符串。

## 上传

上传返回值必须包含可直接访问的 URL：

```json
{
  "url": "https://example.com/uploads/2026/01/01/a.png",
  "relativeUrl": "/uploads/2026/01/01/a.png"
}
```

数据库保存 `url`。不要保存平台内部临时地址。

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

每次重新导入平台前必须递增版本号：

```text
1.0.14 -> 1.0.15
1.1.27 -> 1.1.28
```

不要用同版本覆盖，否则平台可能使用缓存旧包。

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
