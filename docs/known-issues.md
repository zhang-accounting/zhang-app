# 已知问题与下一步（审查结论，2026-10-02）

来源：合并 A/B/C 三条线后的 fresh-eyes 审查（15 个修复已合入 feat/mvp，257 个测试通过，4 个真机集成测试通过）。

## 必须先修（日常使用前）
1. **写入后刷新是固定 600 ms 一次**（lib/data/ledger_revision.dart）。大账本 reload 超过 600 ms 时，保存后各屏会显示旧数据。建议：监听 `/api/sse` 的 `{"type":"Reload"}` 再刷新，或轮询到新交易出现为止。
2. **切换 profile 时 Riverpod 仍短暂保留上一个账本的值**（所有 ledger provider）。已修「出错时不再显示旧账本数据」，但加载窗口内仍可能用上一个账本的账户名保存。建议：在 `bootstrap()` 里按 active profile id 重建 ProviderScope，或把数据 provider 按 profile 做 family。
3. **账本请放在 git 下**：zhang server 写入时不做任何校验（金额、账户是否存在、是否已 close 都不查）。

## P1
- 鉴权类型互斥：decisions.md §7 要求 Basic 可与自定义 Header 叠加（Cloudflare Access + zhang Basic），现在 `authHeaders()` 只按单一类型发（lib/data/profiles/server_profile.dart）。需要改表单与模型。
- 月份/期间按设备时区计算，服务器按账本 `timezone` 切日，两者不同时边界日会偏。需要 timezone 数据库（`timezone` 包）。
- 明文 http 发送凭据没有提示（S01 要求显式 opt-in）。
- 收入模式不能选 Liabilities 作为入账账户。

## P2
- 切换币种后不重新校验已输入的小数位（可输入 12.34 JPY）。
- 键盘：`3−5=` 之后再输数字会变成 −20。
- 罕见标签过滤会把整个账本翻一遍（服务器不支持 `tags[]`，客户端过滤）。
- 报表净额线画到了未来日期。
- 两个 `formatAmount` helper 重复；`journal_providers` 直接 import main.dart。

## 已修（供参考）
标签转义（未转义会把账本文件写坏，P0）、切换账本残留数据/筛选、删除 profile 不清偏好、U+2212 负号、商品 rounding、写入按币种精度、类目名换行、FAB 遮挡最后一行、funding 默认账户跨币种、测试 retry policy、重复 accounts provider。

## zhang server 侧（见 decisions.md 末尾与 zhang-api.md §5）
缺 DELETE 交易、POST 不返回 id、posting 无 cost/price、无幂等键、journals 不支持日期/账户过滤、`size=0` 崩溃、`tags[]` 查询被 Dart 编码后被忽略、换算用最早价格而非最新。
