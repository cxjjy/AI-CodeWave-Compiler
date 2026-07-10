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

- 前端内部使用相对路径，不写死开发或生产域名。
- CodeWave 先创建一个入口页，例如 `simple`。该页面进入事件先用平台“调用逻辑”节点调用 `callApi(reqPath=/simple, reqMethod=GET, reqBody={})` 上报接口权限，再用 JS 代码块通过 `getAppHtml` 注入前端 HTML。
- 业务 API 统一走 `callApi`，由依赖库内部路由分发。
- 如果项目包含上传能力，可扩展 `/simple_proxy/uploadImage`、`/simple_proxy/uploadVideo`；上传返回可直接访问的 HTTPS URL，并保存该 URL。

涉及具体接口形态、包结构、依赖取舍时读取 `references/codewave-package-rules.md`。

### 4. 打包依赖库

每次打包必须递增版本号。

默认产物策略：

- 默认生成和交付 CodeWave 依赖库包，也就是各模块 `target` 目录或标准案例 `dist/.../packages/` 目录下的 `library-*.zip`。
- 只有用户或客户明确要求“源码包”“源码交付”“发源码给别人”时，才额外打源码资料包。
- 源码资料包必须明确标注为“源码资料包”，不得描述为可导入 CodeWave 的依赖库包。

优先使用标准案例脚本：

```powershell
examples\simple-codewave-dependency\scripts\package.ps1 -Version "1.0.xx"
```

手动流程：

1. 执行客户本机基础环境检查；缺工具先提示安装。
2. 检测是否存在 CodeWave 依赖库脚手架。
3. 如果没有脚手架，默认安装脚手架并迁移用户代码。
4. 修改依赖库 `pom.xml` 版本。
5. 构建前端单文件产物。
6. 将前端 HTML 写入后端依赖库静态资源。
7. 使用正确 JDK 构建依赖库。
8. 产出 `library-*-{version}.zip`。
9. 打开 zip 校验 CodeWave 依赖库格式。
10. 扫描包内冲突依赖和敏感信息。

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
- zip 文件存在且版本正确
- zip 根目录包含 `source.zip`、`nasl-metadata.json`、`manifest`、`library/*.jar`、`library/*.pom`
- 不包含 `node_modules`、`target`、`.git` 等无关产物
- 不包含真实 AppSecret、数据库密码、API Key
- 不包含平台冲突依赖
- `getAppHtml` 可返回完整 HTML
- `callApi` 可完成基础 CRUD
- 上传文件 URL 可从浏览器直接访问
- 开发/生产环境路径不写死

### 6. 排障

遇到以下问题时读取 `references/troubleshooting.md`：

- `callApi` 返回 401
- 平台生产发布依赖冲突
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
- 若是打包交付：默认输出可导入 CodeWave 的 `library-*.zip` 依赖库包，并同步输出导入使用教程；仅在用户明确要求源码包时输出源码资料包。
- 若是排障：先给根因，再给修复动作和验证方法。
- 若是写文档：使用中文，避免暴露真实项目路径、域名、密钥和客户隐私。

首次打包或首次交付时，必须附带一份中文使用教程文档，至少包含：

- 依赖库导入顺序：先服务依赖库，再代理依赖库。
- CodeWave 页面创建方式：创建一个承载页面，例如 `simple`。
- 页面进入事件第一步：先用平台“调用逻辑”节点调用 `callApi`，默认参数 `reqPath=/simple`、`reqMethod=GET`、`reqBody={}`。
- 页面进入事件第二步：再添加 JS 代码块，通过相对路径调用 `getAppHtml` 并 `document.write` 注入 HTML。
- 完整 JS 示例，且不允许写死生产域名、开发域名或额外 `/api` 前缀。
- 如果代理路径被开发者改名，教程必须提示把 `/simple_proxy` 替换成实际代理路径。
- 发布开发环境、验证、发布生产环境的检查清单。

标准案例脚本会输出 `target\codewave-import-usage.md`；非标准案例也必须输出等价教程，不得只给 zip 包。

## 质量红线

- 不把真实项目当公开模板。
- 不把真实密钥写入 Skill、示例代码或 README。
- 不把完整业务后端服务包塞进 CodeWave 依赖库。
- 不在平台前端写死 `/api/xxx` 或生产域名，除非用户明确要求。
- 不用 PC 网页截图冒充微信小程序截图。
- 不把 Skill 写成泛泛介绍；必须能指导 Agent 实际完成打包、导入和排障。
