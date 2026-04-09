# F{nn} {Feature Name} — Technical Design

> 技术方案是 Worker 执行的前置条件。Worker 只做方案内定义的事。
> 
> 来源：
>   - 自动生成：从 Feature YAML + PROJECT.md + Backend Code Scan
>   - 外部导入：技术负责人直接提供
>   - 混合：自动生成骨架，人工补充细节
>
> Path: `{project}/{version}/designs/F{nn}-{name}.md`

## 1. 概述

- **Feature**: F{nn} - {name}
- **类型**: {ui_weight} (heavy / light / logic-only)
- **影响平台**: iOS / Android / Backend
- **设计者**: {auto / 外部导入 / 人名}
- **状态**: draft / reviewed / approved

## 2. API 契约 (跨端对齐)

> 这是 iOS、Android、Backend 三端的共同约定。
> 任何端的 Worker 都必须严格遵循此契约。

### 2.1 接口定义

#### {接口名称}
```
POST /path/to/endpoint

Request:
{
  "field_1": type,     // 说明
  "field_2": type      // 说明
}

Response:
{
  "code": int,         // 0=成功
  "data": {
    "field_a": type,   // 说明
    "field_b": type    // 说明
  }
}

Error:
  400: 参数错误
  401: 未登录
  500: 服务端异常
```

> 重复此结构，列出所有相关接口。

### 2.2 数据模型 (共享)

```
Model: {ModelName}
{
  id:          int64    // 主键
  field_1:     string   // 说明
  field_2:     int64    // 说明
  status:      int      // 0=x, 1=y, 2=z
  create_time: string   // ISO8601
}
```

### 2.3 状态枚举 (跨端统一)

| 值 | 含义 | iOS 常量 | Android 常量 | 后台常量 |
|----|------|----------|-------------|----------|
| 0 | {状态A} | .stateA | STATE_A | StatusA |
| 1 | {状态B} | .stateB | STATE_B | StatusB |

### 2.4 业务规则 (跨端一致)

> 各端必须实现一致的业务逻辑。

- 规则 1: {描述}
- 规则 2: {描述}
- 边界条件: {描述}

## 3. 各端实现方案

### 3.1 Backend

- **改动类型**: modify_constants / modify_structure / new_endpoint / new_field
- **关键文件**: {路径}
- **改动点**:
  1. {具体改什么}
  2. {具体改什么}
- **数据库变更**: 无 / {DDL}
- **配置变更**: 无 / {描述}

### 3.2 iOS

- **关键模块**: {路径}
- **改动点**:
  1. {具体改什么}
  2. {具体改什么}
- **新增文件**: {列表}
- **UI 组件**: {复用现有 / 新建}
- **网络层**: 调用 {接口}，使用 {API client pattern}

### 3.3 Android

- **关键模块**: {路径}
- **改动点**:
  1. {具体改什么}
  2. {具体改什么}
- **新增文件**: {列表}
- **UI 组件**: {复用现有 / 新建}
- **网络层**: 调用 {接口}，使用 {API client pattern}

## 4. 关键决策

| 决策点 | 选择 | 备选方案 | 理由 |
|--------|------|----------|------|
| | | | |

## 5. 风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| | | |

## 6. 验收标准 (对齐 Feature YAML AC)

- [ ] AC01: {描述}
- [ ] AC02: {描述}

## 7. 外部资源 (如有)

> 技术方案可以引用或附加外部文档。

- 外部设计文档: {URL / 文件路径}
- 接口文档: {Swagger URL / proto 文件}
- 相关 PR / 代码参考: {链接}
