# 标准案例目录结构

标准案例应能让别人下载后独立理解和二开，同时不能泄露真实项目。

## 推荐结构

```text
codewave-park-standard-case/
  README.md
  docs/
    manual.md
    database.md
    miniprogram.md
    troubleshooting.md
  examples/
    simple-codewave-dependency/
      frontend/
      backend-library/
      service-library/
      docs/
        codewave-import-usage.md
      sql/
      scripts/
      README.md
  reference/
    patterns/
      platform-page-entry.js
      frontend-proxy-request.js
      backend-callapi-handler.java
      upload-url-normalize.js
      miniprogram-request.js
  scripts/
    preflight-check.ps1
    install-codewave-scaffold.ps1
    package-standard-case.ps1
  skill/
    SKILL.md
    references/
      compiler-pipeline.md
      codewave-package-rules.md
      standard-case-layout.md
      troubleshooting.md
  dist/
```

## examples/simple-codewave-dependency

这是最小可运行示例，不应复制真实项目复杂业务。

必须包含：

- 一个简单前端页面
- 一个 service 依赖库模块
- 一个 proxy 代理依赖库模块
- 一个 service 依赖库包
- 一个 proxy 代理依赖库包
- 一个初始化 SQL
- 一个打包脚本
- 一个仓库根目录一键打包脚本
- 一个首次导入使用教程，说明 CodeWave 页面进入事件和 JS 注入方式

当用户输入工程缺少 CodeWave 依赖库脚手架时，应默认从本示例安装脚手架，再把用户业务代码迁移进去。不要直接把普通工程压缩成依赖库包。

生成新项目时，根据用户项目名同步代理前缀。例如“CRM 项目”使用 `/crm_proxy`，“OA 系统”使用 `/oa_proxy`。复制脚手架后先执行：

```powershell
skill\scripts\set-proxy-base.ps1 -ProjectRoot examples\simple-codewave-dependency -ProjectCode crm
```

不要让新项目继续使用 `/simple_proxy`，除非用户明确要求沿用示例名。

## platform/page-entry.js

平台先创建一个承载页面，例如 `simple`。该页面进入事件先调用一次 `callApi` 默认接口，再调用 `getAppHtml` 注入页面。

平台“调用逻辑”节点：

```text
callApi
reqPath    = /simple
reqMethod  = GET
reqBody    = {}
```

入口脚本应保持通用：

```js
(async function () {
  const res = await fetch('/simple_proxy/getAppHtml', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}'
  })
  const json = await res.json()
  let html = json.data
  try { html = JSON.parse(html) } catch (e) {}
  document.open()
  document.write(html)
  document.close()
})()
```

## 打包产物

每个版本输出：

```text
dist/codewave-simple-example-{version}/packages/
```

目录中必须包含可直接导入 CodeWave 的两个依赖库包：

```text
library-*_service-*.zip 或 service-library/target/library-*.zip
library-*_proxy-*.zip 或 backend-library/target/library-*.zip
```

实际文件名由开发者自己的 Maven `artifactId`、依赖库名称和版本决定，不要求固定为本案例名称。GitHub 下载的源码 zip 不是 CodeWave 依赖库包，不能直接导入平台。

默认必须输出两个依赖库包：服务依赖库包和代理依赖库包。只有用户明确要求单包模式时，才允许省略服务依赖库包。

每次打包还必须输出一个统一交付目录，例如：

```text
examples/simple-codewave-dependency/target/packages/
```

该目录至少包含两个 `library-*.zip` 和 `codewave-import-usage.md`。客户导入 CodeWave 时优先使用这个目录，不要去两个模块的 target 目录里自行判断。

## 公开仓库注意事项

可以保留：

- 通用代理模式
- 示例 CRUD
- 示例上传
- 示例登录
- 环境自适应写法
- 打包脚本

不能保留：

- 真实客户业务数据
- 真实数据库导出
- 真实短信、微信、OpenAI 密钥
- 真实域名和库名
- 可反推出客户项目的页面文案或截图
