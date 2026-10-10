# Lead 决策记录（对 docs/design-research.md §5 开放问题的裁定）

日期：2026-10-02

## 产品 / 视觉
1. **收支颜色**：做成设置项，三档：`expenseRed`（支出红 / 收入绿）、`incomeRed`（收入红 / 支出绿）、`mono`（单色，只用 +/− 号）。默认值按系统语言：zh → `incomeRed`，其他 → `expenseRed`。**不弹**首次选择卡片，在 Settings 里可改。
2. **导航**：Home / Journal / [中间凸起「记一笔」按钮] / Reports / Accounts。预算不单独成 tab，放在 Reports 里作为一个分段（P1）。Settings 从 Home app bar 的齿轮进入。
3. **类目宫格不默认选中**；未选类目时保存键禁用并给出提示。
4. **类目图标只存本地**：按账户名关键词（中英）映射到 Material icon，用户可在本地覆盖（P1）。不往 `open` 指令写 meta。
5. **记一笔三种模式**（支出 / 收入 / 转账）生成两条显式金额的 posting；「高级」多 posting 编辑器属于 P1。
6. **保存后不做乐观更新**：POST 成功后刷新 journals 第 1 页与 summary（服务器写入异步，id 不稳定）。

## 鉴权
7. zhang 原生只有 HTTP Basic。Bearer 与自定义 Header 是给反向代理 / 网关（如 Cloudflare Access、Caddy forward_auth）用的，可与 Basic 叠加（同时启用多种时全部附加）。

## 范围
8. **MVP = design-research §4 的 P0 全部 12 项**，分三条并行线实现：
   - A「记账流」：S03 AddTransactionSheet + AmountKeypad + 类目宫格 / 子类目 chips，S04 AccountPickerSheet，S05 payee / narration 补全（frecency）与 payee 自动填表，类目→资金账户记忆。
   - B「浏览」：S02 HomeScreen，S07 JournalScreen（分页、月头 / 日头、`classify()`、类型 chips、keyword / tag 过滤），S08 TransactionDetailScreen。
   - C「账户与报表」：S12 AccountsScreen（树 + 净资产），S13 AccountDetailScreen（余额 + 流水 + running balance），S10 ReportsScreen（期间选择、KPI、趋势柱、分类排行 + 下钻）。
   - 全局状态（骨架屏、空态、卡片级错误、401 banner）由各线在自己屏幕内使用 foundation 提供的共享 widget。
9. P1 / P2 按 design-research §4 顺序排期，不在本轮实现。

## 上游 zhang API 缺口（需要在 zhang 仓库解决，记录给作者）
- 缺 `DELETE /api/transactions/:id`（无法做滑动删除 / 撤销）。
- `POST /api/transactions` 不返回新交易 id（附件上传要绕路）。
- ~~posting 不支持 cost / price~~：v0.2 已支持写 cost / price / comment / metas（App 尚未使用）。
- 无幂等键（离线重试可能重复记账）。
- `/api/journals` 仍不支持按日期 / 账户 / 金额过滤；v0.2 可用 BQL（`POST /api/query`、`postings.between` 等内置查询）代替。
- 无预算写接口（budget-add / budget-transfer）。
- 表单建议（`journals.payees`）无使用频次信号；账户不暴露允许的币种。
- 2026-10-10 起 App 只支持 zhang ≥ 0.2（内置查询 API），见 docs/compat-v0.2.md；仍存在的服务器问题见 docs/zhang-api.md §5。
