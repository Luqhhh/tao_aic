# 参考结果加载失败诊断

检查日期：2026-11-05。本地与远程服务器的逐组审计结果一致；本次检查仅读取源码、配置和结果文件，没有运行 EDA、调用模型或提交训练评估。

结论：当前 `contest-source.tar.gz` 与 `contest-data.tar.gz` 的参考结果接口不兼容。数据中的结果摘要可以读取，但不具备当前源码要求的来源校验证据；概率基线还存在初始候选、评分校准、种子范围及 halo 配置差异。无法仅靠添加一个字段完成修复。

## 错误如何触发

实际调用路径为：

```text
contest2.runner.run
  → Task2Controller.__init__
  → LocalEvaluationMatrix.__init__
  → local_bench.packed_gnn_reference.validate_files
  → ValueError: Packed GNN reference authority is incomplete
```

`local_bench/matrix.py:128` 检测到 `run/reference_summary.json` 后，进入精简参考结果的校验分支。`local_bench/packed_gnn_reference.py:26` 随即读取 `receipt["artifacts"]["packed_reference"]`；当前数据中这个字段不存在，因此在第一道来源检查处停止。这里的 authority 指结果来源的校验证据，与服务器权限、Docker 用户组或 API key 无关。

以 `materials/contest-data/task2/loss_decoder/train/references/bp_fe-ng45/1001/evaluation_result.json` 为例，其 `artifacts` 仅有：

```json
{
  "matrix_cell_contract": {"task": "tp_gnn_loss_decoder_timing"},
  "matrix_reference": true
}
```

这只是结构节选，`matrix_cell_contract` 内其余任务、种子及输入摘要字段已省略，未修改原始回执。

## 全部 30 组的检查结果

两条基线各含 9 组训练参考、6 组验证参考，总共 30 组。

| 检查项 | `loss_decoder`，15 组 | `binary_loss`，15 组 |
| --- | --- | --- |
| `artifacts.packed_reference` | 全部缺失 | 全部缺失 |
| `artifacts.task` | 全部缺失 | 全部缺失 |
| `artifacts.reference_admission`，含生成实现身份 | 全部缺失 | 全部缺失 |
| `candidate_snapshot.json` | 全部缺失 | 全部缺失 |
| 参考摘要与切分 CSV 的摘要一致性 | 15 组通过 | 15 组通过 |
| 参考摘要自身的官方读取函数 `_packed_reference` | 15 组通过 | 15 组通过 |
| 回执中初始候选摘要与当前源码生成的候选一致 | 15 组一致 | 15 组均不一致 |
| 摘要与源码内共同评分校准的文件摘要一致 | 15 组一致 | 13 组不一致；另外 2 组在当前源码校准表中不存在 |

当前精简参考接口要求 `packed_reference` 包含六个字段：`schema_version`、`summary_sha256`、`assignment_sha256`、`candidate_sha256`、`producer_receipt_sha256`、`consumer_implementation_sha256`。其中原始生成回执的身份和生成实现信息不能从几个现有结果摘要中反推得到。来源准入函数还会检查任务、生成模式 `FRESH`、候选快照、上游输入身份及初始候选摘要。

## 概率基线的额外差异

概率基线的每份回执都记录同一个初始候选摘要：

```text
数据回执：b2575a74d03bf3265f1f82e60aa7f41f9198a89bffc782cfb659b1148c0f500b
当前源码：7a96ed71f272e25104187ab2b932529d0bb6e857fae7ef268fc5c57680cf9f20
```

当前源码的 `initial_program.py` 生成结果与其 `initial_candidate/candidate.json` 相互一致，均为第二个摘要。因此不是本机误用了两份初始候选中的另一份。候选摘要也包含元数据；由于数据未附候选快照，无法只凭摘要判定旧候选具体改过哪行代码。

评分校准差异涉及实际测量值，并非只有 JSON 格式不同。例如概率基线 `bp_fe-ng45/1001`：

| 数据来源 | WNS，ns | TNS，ns |
| --- | ---: | ---: |
| 数据包 `reference_summary.json` | -0.6827156810902035 | -449.6972521646297 |
| 源码 `contest2/manifests/common-timing-reference.json` | -0.6980237696535849 | -506.9645255978024 |

此外，当前源码要求概率基线的 Ariane 只使用 seed 1003，但数据训练矩阵包含 1001、1002、1003。seed 1001 和 1003 的 `macro_halo_um` 在数据中为 5.0，源码共同 halo 规则要求 10.0；seed 1003 属于当前源码仍然要求的参考。九组与七组的比赛口径仍需官方明确，不能据此自行修改 PDF 规定的比赛规则。

所有回执的 `matrix_cell_contract` 还多出 `reference_assignment_sha256`、`reference_summary_sha256` 两个字段，而当前 `local_bench.seeds.cell_contract` 不生成这两个字段。现有契约有严格的字典相等检查，也是后续需要官方统一的格式差异。

## 排除迁移和解压问题

已重新计算两份原始归档的 SHA-256，与初次从 Windows 迁移时保存的摘要一致：

```text
contest-data.tar.gz
1451d77c804d105fd4b8672f9ede82a77a64f1d27f30c544e1b4ef6991284210

contest-source.tar.gz
34cda1468a7af955b8cb51f2588d5c4c70b3479629c094f5b9f0597daee848d2
```

直接读取原始数据归档，将全部 90 个参考文件与解压文件逐字节比较，全部相同。归档中没有候选快照，也没有可用于重新打包的完整参考物理流程文件。源码归档中的 12 个关键文件，包括读取器、打包器、矩阵、种子、采样、halo 规则、初始候选与评分校准，也与当前解压源码逐字节一致。

因此，这些缺失和冲突已存在于本次收到的原始包中。无法仅凭当前包断言是打包遗漏、旧数据混入还是发布版本错配；能确认的是它们不满足随包源码的接口要求。

## 官方打包入口与处理办法

`AgenticBench/contest2/pack_references.py` 是官方提供的精简结果打包入口。它要求从主办方完整且已验证的原生参考结果目录开始，保留来源信息、复制 `candidate_snapshot.json`，再生成 `packed_reference`。

对当前两条基线的回执调用其只读转换函数 `packed_receipt`，均被明确拒绝：

```text
Native reference authority is missing; do not pack a reduced receipt
```

需要主办方提供与当前源码匹配的完整精简数据包：补齐来源回执与候选快照，并统一概率基线的初始程序、共同评分校准、Ariane 种子和 halo 规则。主办方若保留了匹配的完整原生参考目录，可以用该官方入口重新打包；否则需重新生成受影响的参考结果。只拿当前精简数据再运行打包器不能恢复已经缺失的来源证据。

官方 `prepare` / `qualify` 可以从冻结输入创建并运行新的原生参考，但这属于重新计算参考结果；它不能直接证明与已发布评分校准等价。本次诊断未启动该流程，也未修改参考结果、评分表或官方校验代码。

本地审计明细：`results/environment/reference-audit.json`；原始归档核对：`results/environment/reference-archive-audit.json`。远程服务器也保存了相同的逐组审计结果。可用以下只读命令重现矩阵入口报错：

```bash
.venv/bin/python scripts/check_materials.py
```
