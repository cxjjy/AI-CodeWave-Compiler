# AICodeWave Compiler 编译流程

## 目标

把 AI 生成的代码工程转换为 CodeWave 可运行资产。核心不是“搬运代码”，而是把工程语义翻译成平台能识别、能导入、能发布的依赖库。

## 分层

```text
AI 代码工程
-> 代码解析层
-> 中间表示层 IR
-> CodeWave 适配层
-> cw 打包层
-> 校验层
-> CodeWave 运行时
```

## 代码解析层

解析内容：

- 前端页面结构
- 路由结构
- 组件依赖
- API 调用
- 上传逻辑
- 登录与权限
- 后端接口
- 数据表与初始化 SQL

输出应用结构图。

## IR 中间表示

建议用以下结构表达：

```json
{
  "appName": "",
  "pages": [],
  "components": [],
  "apis": [],
  "services": [],
  "models": [],
  "routes": [],
  "permissions": [],
  "uploads": [],
  "environments": []
}
```

IR 的作用：

- 统一不同技术栈表达
- 识别平台入口和运行边界
- 为 CodeWave 包映射提供稳定输入

## CodeWave 适配层

常见映射：

| AI 工程内容 | CodeWave 资产 |
|---|---|
| 前端单页应用 | `getAppHtml` 返回的入口 HTML |
| 前端 API 请求 | `callApi` 代理调用 |
| 后端 Controller | 依赖库内部路由分发 |
| 数据模型 | SQL 初始化脚本和 CRUD 映射 |
| 上传组件 | 可选扩展 `uploadImage` / `uploadVideo` |
| 登录态 | token 参数透传或依赖库内 token |
| 权限菜单 | 后端权限数据 + 前端菜单控制 |

## cw 打包层

输出结构建议：

```text
dist/
  codewave-simple-example-{version}/
    packages/
      library-*.zip
      library-*.zip
    platform/
      page-entry.js
    sql/
      init.sql
    README.md
```

`packages/` 中放的是可直接导入 CodeWave 的依赖库 zip。不要把 GitHub 下载的源码 zip 或外层说明包当作依赖库导入。

## 校验层

必须验证：

- 包能被 CodeWave 导入
- 生产环境发布不冲突
- `getAppHtml` 返回完整 HTML
- `callApi` 基础接口返回 200
- CRUD 事务成功提交
- 上传 URL 可直接访问
- 开发/生产环境路径自适应

## 编译判断

如果用户只是要“解释方案”，输出架构说明。

如果用户要“把项目做成标准案例”，输出完整目录、示例工程、打包脚本和 Skill。

如果用户要“修复包”，优先修包并打新版 zip。
