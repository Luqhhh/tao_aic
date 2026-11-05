# 赛题 2 规则与更新

整理日期：2026-11-05。材料来源为用户提供的规则 PDF、随包 README 和当前官方任务包；保留原始文档，不直接改写 PDF。

## 评估预算更新

用户转述官方修订：**评估次数上限从 30 次调整为 10 次。**

- 每队每条基线分别享有 **10 次训练评估提交**、**15 元模型 API 费用额度**。
- `loss_decoder` 与 `binary_loss` 的次数、费用及断点分别记录。
- 一次提交覆盖该路径规定的全部训练算例与种子；不是每个 case/seed 各占一次。
- 接口或修改范围检查被拒、训练失败、物理流程失败的提交也计入次数。同一请求 ID 的重复查询或重传只计一次。
- 不修改、绕过或重置官方预算、评估逻辑和参考结果。

核对依据：

- [随包 README](official/README.md) 的“任务与评估”部分明确为 10 次。
- 本地官方源码 `materials/contest-source/AgenticBench/contest2/budget.py` 的 `BudgetLedger` 默认上限为 10；`runner.py` 与 `model_gateway.py` 也使用 10。
- [规则 PDF](official/赛题2_面向3D芯片网表切分的优化目标演化.pdf) 第十一节仍写 30 次，该数字由上述修订替代。

## 允许演化的范围

| 基线 | 可提交函数 | 官方开发目录（相对 AgenticBench） |
| --- | --- | --- |
| `loss_decoder`：表征学习 TP-GNN | `compute_tp_gnn_loss`、`decode_tp_gnn_embeddings` | `agent/loss_decoder/` |
| `binary_loss`：概率预测 GNN | `compute_binary_partition_loss` | `agent/binary_loss/` |

保持规定函数签名。图构造、节点特征、GNN 主体、训练配置及下游物理流程由官方固定。参赛方可开发 Agent/harness、提示词、搜索策略和反馈分析逻辑，最终提交的 harness 应能从官方初始算法自动完成演化。

每个原始实例须且仅须分配到一层。上层实例总面积占比为 47%–53%；有宏单元时，上层宏数量及宏面积占比均为 45%–55%。完整候选所需的算例和种子必须全部有效。

## 数据与种子

| 集合 | 算例 |
| --- | --- |
| 公开训练 | `bp_fe-ng45`、`bp-ng45`、`ariane133-ng45` |
| 公开验证 | `swerv_wrapper-ng45`、`bp_fe-asap7` |
| 隐藏评测 | 2 个隐藏算例，由组委会提供 |

按当前随包 README 及源码规则，表征学习路径各算例使用 1001、1002、1003；概率预测路径的 `ariane133-ng45` 仅使用 1003，其余公开算例使用 1001、1002、1003。因此一次完整训练评估应分别包含 9 组和 7 组运行。I/O 种子固定为 1。

**本批材料存在版本不一致：** `materials/contest-data/task2/binary_loss/train/qualified_matrix.json` 实际为 schema 1，共 9 组，仍含 Ariane 的 1001、1002、1003。当前源码 `AgenticBench/contest2/sampling.py` 的 `validate_public_matrix` 要求概率路径 Ariane 仅有 1003，矩阵加载器保留原有的全部组，因此这份训练矩阵不满足当前源码的种子检查。后续运行前需取得相互匹配的官方包或官方修订。本次整理保持原始数据和评估程序原样，不自行删除矩阵行或改写参考结果。

## 物理评估与计分

按当前随包 README，切分和固定布局、PDN、HBT 流程后执行一次 OPT，在 CTS 前读取 WNS、TNS，不运行功耗或温度分析。负时序违例量为 `max(0, -slack)`。

```text
改善率 = (参考负时序违例量 - 候选负时序违例量) / 参考负时序违例量
单组分数 = 100 × (0.4 × WNS 改善率 + 0.6 × TNS 改善率)
```

当前任务包对同一算例的所有种子和两条基线采用共同参考值；先在算例内对规定种子取平均，再在算例间等权平均。共同参考的来源见官方源码 `AgenticBench/contest2/manifests/common-timing-reference.json`。原生配对参考分数属于诊断字段，反馈中的共同参考分数用于该任务包的评分。

## 原材料中的差异

PDF 仍描述每例三个种子、同算例同种子的初始算法参考和七例分数求和；随包 README 则说明概率路径 Ariane 的单种子例外、共同评分参考及按算例平均的反馈分数。以上差异在此分别保留来源，后续实验应核对当前官方任务包及最新赛事通知，报告时标明所用版本与分数口径。

执行公开验证会冻结候选和 Agent，具体行为以官方 `validate` 接口为准。最终材料需包含固定的 harness、算法代码、复现说明、物理结果、演化日志和技术报告，提交要求详见原 PDF 第十三节。
