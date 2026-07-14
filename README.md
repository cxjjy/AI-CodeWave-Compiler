# AI-CodeWave-Compiler

将 AI 生成的前后端工程封装为网易 CodeWave 可导入、可发布的 `cw` 依赖库。

## 能做什么

- 识别前端页面、路由、接口、数据模型和环境配置
- 将 Vue/Vite 或单页 HTML 封装为 `getAppHtml` 入口
- 将业务 API 统一封装为 `callApi` 代理
- 按 CodeWave 依赖库脚手架构建 Java 代理模块
- 生成 NASL 元数据和标准 `library-*.zip`
- 校验包结构、依赖冲突、敏感信息和开发/生产路径
- 提供依赖库导入、发布和常见问题排查指导

## 目录

```text
.
├── SKILL.md
├── assets/
│   ├── codewave-maven-repository/
│   ├── codewave-page-entry.js
│   └── launch-playwright-browser.js
├── references/
    ├── codewave-package-rules.md
    ├── compiler-pipeline.md
    ├── standard-case-layout.md
    └── troubleshooting.md
└── scripts/
    └── validate-*.ps1
```

## 使用方式

将本项目作为 Codex skill 安装到 `$CODEX_HOME/skills/aicodewave-compiler`，然后提出类似请求：

```text
按照 aicodewave-compiler skill，把这个前后端项目打包成可以上传到 CodeWave 的依赖库。
```

打包前应准备：Node.js/npm（如果需要构建前端）、JDK 8 或 JDK 11、Maven 3.6+、Git，以及可访问 Maven/npm 仓库的网络环境。

## CodeWave 依赖库包要求

最终可上传的依赖库包必须由 Maven 的 `nasl-metadata-maven-plugin` `archive` 目标生成，并且 zip 根目录至少包含：

```text
source.zip
nasl-metadata.json
manifest
library/*.jar
library/*.pom
```

不能把 GitHub 源码压缩包直接改名为 `library-*.zip`。每次重新导入平台都应递增版本号。

`assets/codewave-maven-repository/` 用于保存标准案例所需的 CodeWave Maven 元数据依赖缓存；`scripts/` 提供前后端代理路径、运行模式和页面入口校验脚本。

## 标准入口

推荐使用以下代理入口：

```text
/simple_proxy/getAppHtml
/simple_proxy/callApi
```

前端使用相对路径，不写死开发环境、生产环境域名或额外 `/api` 前缀。CodeWave 页面进入事件通常先调用一次 `callApi` 上报接口权限，再通过 `getAppHtml` 注入单文件 HTML。

## 安全要求

不要将真实的数据库密码、AppSecret、API Key、客户资料、真实域名或私有源码写入公开案例和 skill。示例中使用 `CHANGE_ME_*` 占位符，并在交付前扫描压缩包。

## 许可证

本项目用于 CodeWave 依赖库封装流程和标准案例指导。具体项目代码、第三方依赖和 CodeWave 平台使用应分别遵守其适用许可证与平台规则。
