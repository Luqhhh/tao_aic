# 赛题 2：3D 芯片网表切分目标演化

在解压后的赛题代码目录中，运行表征学习 TP-GNN 的默认 Codex Agent：

```sh
cd AgenticBench
python3 -m contest2 run --baseline loss_decoder
```

概率预测 GNN 的入口为 `python3 -m contest2 run --baseline binary_loss`。两条基线各有独立的 Agent 开发目录和 Codex 会话，评估次数和模型费用分别计账。

评估在一次 OPT 后测量时序，不运行功耗或温度分析。

## 赛题背景

3D 芯片网表切分决定每个实例位于上层还是下层。不同的切分会改变跨层连接、后续布局和时序。本赛题固定图构造、GNN 主体、训练配置及下游物理设计流程，参赛队伍开发 Agent，反复提出函数修改，根据完整物理评估的反馈改进切分方法。

赛题提供两条研究路径。表征学习 TP-GNN 先学习实例的嵌入，再通过聚类分配层，开放训练损失函数和聚类解码函数。概率预测 GNN 直接预测实例位于上层的概率，开放训练损失函数。两条路径使用共同的时序评分参考值。

概率预测基线采用可微图切分、软面积平衡和二值间隔正则项。面积平衡直接使用预测概率计算期望上层面积，权重为 200。Adam 学习率为 0.003，训练 400 次全图更新，温度从 1 降至 0.1，二值正则权重从 0 增至 10。最终按 0.5 阈值切分，并执行固定的面积与宏单元平衡修复。训练参数由外层 harness 固定。概率路径的 Ariane133/ng45 固定使用 seed 1003，其余算例使用三个种子。

## 配置环境

赛题材料分为三个压缩包：`contest-source.tar.gz` 包含 Agent 开发入口、物理设计源码和评估程序，`open3dbench-contest-runtime.tar.gz` 包含 Docker 运行镜像，`contest-data.tar.gz` 包含公开算例与两条基线经过核验的参考摘要。将三个文件放在同一目录，解压源码和数据并加载镜像：

```sh
tar -xzf contest-source.tar.gz
tar -xzf contest-data.tar.gz
docker load -i open3dbench-contest-runtime.tar.gz
```

解压后的目录结构为：

```text
赛题目录/
├── contest-source.tar.gz
├── contest-data.tar.gz
├── open3dbench-contest-runtime.tar.gz
├── contest-source/
│   ├── README.md
│   ├── AgenticBench/
│   ├── Place-3D/
│   └── open3dbench/
└── contest-data/
    └── task2/
        ├── runtime.json
        ├── binary_loss/
        │   ├── train/qualified_matrix.json
        │   └── validation/qualified_matrix.json
        └── loss_decoder/
            ├── train/qualified_matrix.json
            └── validation/qualified_matrix.json
```

`runtime.json` 指定运行镜像。Agent 与评估使用同一镜像的独立容器。运行主机需具备 Linux、Docker、NVIDIA GPU 和 Python 环境，默认 Agent 还需要在主机安装 Codex CLI。自定义 Agent 可通过受控模型接口直接调用模型。Python 环境需安装 `PyYAML`：

```sh
python3 -m pip install PyYAML
```

启动检查按镜像配置和完整文件层核对运行环境，兼容 Docker 的配置摘要与镜像清单摘要。检查还会执行一个小型 DREAMPlace CUDA 算子并记录 GPU 型号、计算能力及运行库版本。

从代码目录的 `AgenticBench` 子目录检查数据、参考摘要和镜像：

```sh
python3 -m contest2 check --baseline loss_decoder
python3 -m contest2 check --baseline binary_loss
```

启动默认 Agent 时，按提示输入 DeepSeek API key，也可通过运行主机的 `DEEPSEEK_API_KEY` 环境变量提供。外层 harness 负责模型调用和费用记录，密钥不进入 Agent 的可写目录。

自动运行时，可用 `--api-key-file /私有目录/deepseek.key` 或 `DEEPSEEK_API_KEY_FILE` 指定密钥文件。文件应放在源码、数据和工作目录之外。启动前会检查 DeepSeek 连接与密钥，并确认所用模型可用。使用代理的主机可通过 `HTTPS_PROXY` 配置模型服务的网络出口。

## 运行默认基线

在代码目录的 `AgenticBench` 子目录运行：

```sh
python3 -m contest2 run --baseline loss_decoder
python3 -m contest2 run --baseline binary_loss
```

每条命令调用对应目录中的 `Agent.run(context)`。默认 Agent 每轮先让 Codex 修改函数并返回，再提交候选、等待完整训练评估，并将实际结果交给下一轮 Codex。评估等待位于模型调用之外。默认 Agent 持续迭代至评估次数用完，或剩余模型费用不足以预留下一次 API 请求，返回当前基线已验证候选中得分最高的一版。普通候选被拒绝或评估失败时，会把原因作为下一轮反馈；评估状态无法确认时，外层 harness 持续核查原进程、容器与结果，确认后返回成功或失败。核查期间保持等待，不重复提交。单次模型调用失败后，Agent 保留评估反馈并尝试下一轮。训练评估覆盖三个算例。表示学习路径每例三个种子，共九组。概率路径的 BP_FE、BP 各三个种子，Ariane133 仅使用 seed 1003，共七组。运行记录保存在代码目录同级的 `contest-work/task2/<基线>/`。Agent 总会话按评估次数和模型费用额度运行，不设总时长上限。仅单次模型 API 请求设置超时，Agent 会话、容器内命令、资源排队和物理评估均不设执行时限。长命令返回 `running` 和 `session_id`，Agent 可继续轮询结果。

可先运行一次自动闭环自检：

```sh
python3 -m contest2 smoke --baseline binary_loss
```

外层 harness 启动与正式运行相同的默认 Agent，自动执行两轮 Codex 调用。自检首轮指定一个微小数值改动。第一轮修改代码，在 `bp_fe-ng45`、seed `1003` 上完成原生物理评估，第二轮根据实际分数与时序反馈提出并写入下一版代码。自检只评估第一版，结果保存在 `contest-work/smoke/` 下新建的目录中。`session-result.json` 给出三步检查结果，成功退出码为 0。测试记录和预算与正式训练分别保存，正式验证只接受完整训练评估的候选。网关、通信服务及容器由外层 harness 管理其启动和结束。

选定最终候选后，使用返回的候选 ID 运行公开验证集：

```sh
python3 -m contest2 validate --baseline loss_decoder --candidate-id <候选ID>
```

概率预测 GNN 的公开验证将 `--baseline` 改为 `binary_loss`。

评估按主机配额并行调度 case/seed。切分和布局完成、前端容器退出后释放 GPU，PDN、HBT 和 OPT 在 CPU 容器中继续执行，两阶段使用同一固定镜像。

默认清理模式下，训练评估和单算例自检按 case/seed 自动回收存储空间。每组物理流程完成、评估容器退出且结果写入后，外层 harness 保留候选源码、原始指标、切分归属、GNN 训练曲线、阶段配置、清单和诊断日志，删除该组的临时源码副本、运行环境副本及大型物理中间文件。文本日志和报告完整保留，较大的日志、JSON、YAML 文件以 `.gz` 格式无损压缩保存。结果目录中的 `retained_artifacts/` 保存这些材料，`storage-retention.json` 记录回收明细。

公开验证与最终评估同样遵循存储配置。需要导出完整物理结果时，使用 `--retain-physical-files`。训练过程若需重新核验物理数据库，应使用保存的候选重新运行。执行状态仍在核查中的任务保留全部文件。回收异常会记录到 `storage-maintenance-error.json`，已有评分和评估次数保持不变。Agent 的开发文件、会话历史和自行生成的局部实验文件由参赛队伍管理。

模型调用中断时，外层 harness 保留编辑现场和会话记录。重启后先确认原调用进程已退出，再恢复会话。已取得的模型用量会自动结算，缺少用量回执的请求继续占用其预留费用，并在状态中标为待核对，不阻塞已受理的评估。默认 Agent 的模型编辑与物理评估分开执行。

物理中间文件默认在评估完成后清理。调试布局或查看物理数据库时，可在启动命令中增加：

```sh
python3 -m contest2 run --baseline binary_loss --retain-physical-files
```

也可在 `contest-data/task2/runtime.json` 的 JSON 顶层设置 `"retain_physical_files": true`。设为 `false` 或使用 `--no-retain-physical-files` 时清理中间文件，命令行设置优先。清理后仍保留评分、完整日志、候选源码与验证记录。已经删除的物理文件需要重新运行才能生成。

## Agent 开发入口

运行时，Agent 在 `contest-work/task2/<基线>/participant-agent/<基线>/` 中使用独立的可写工作副本。工作副本保留演化产生的程序和文件。修改开发目录中的文件后，下次启动会同步这些修改。

| 基线 | Agent 目录 | 可提交的函数 |
| --- | --- | --- |
| 表征学习 TP-GNN | `AgenticBench/agent/loss_decoder/` | `compute_tp_gnn_loss`、`decode_tp_gnn_embeddings` |
| 概率预测 GNN | `AgenticBench/agent/binary_loss/` | `compute_binary_partition_loss` |

在选定目录的 `agent.py` 中实现 `Agent.run(context)`，可自行组织提示词、候选搜索、历史记录和局部实验，也可在该目录添加辅助文件。`program.py` 是提交给完整评估的函数程序。表征学习基线可修改损失与全局二类聚类解码，概率预测基线可修改可微损失。函数签名和可用操作由任务接口规定，候选仍须通过固定的层归属与面积合法性检查。

`context.status()` 返回剩余额度和评估历史。`context.codex_turn(prompt)` 调用默认 Codex 适配器，`context.model.responses_create(payload)` 提供受控模型请求。Agent 读取修改后的 `program.py`，通过 `context.submit_evaluation(source)` 提交其完整文本，再用 `context.wait_evaluation(request_id)` 取得结果。`Agent.run` 最终返回已完成训练评估的候选 ID。 返回候选后仍可继续开发，执行 `validate` 时才冻结候选与 Agent。冻结前会核对候选所属基线和函数接口，选错基线的命令不会锁定开发状态。两个目录中的默认 `agent.py` 展示了这一流程。

`context.status()` 同时给出 `model_dispatch_allowed`、`evaluation_dispatch_allowed` 和 `model_stop_reasons`，分别说明能否调用模型、能否提交候选及模型调用受限的原因。

Agent 容器可写当前基线的 Agent 目录、独立工作区和临时目录，可只读访问公开训练输入与物理源码。外层 harness 负责候选函数校验、预算、参考结果和评估调度。评估容器在独立源码副本中执行切分及下游物理流程，并核验阶段产物。

### Agent 容器中的目录

| 路径 | 权限 | 用途 |
| --- | --- | --- |
| `/workspace/agent` | 可写 | 当前基线的 Agent 与 `program.py` |
| `/workspace/workspaces` | 可写 | 自定义 Agent 工作文件 |
| `/workspace/scratch` | 可写 | 临时文件与局部诊断 |
| `/opt/contest/source` | 只读 | 完整物理设计源码 |
| `/opt/contest/AgenticBench` | 只读 | Agent 接口与评估代码 |
| `/workspace/README.md` | 只读 | 本开发说明 |
| `/inputs/<case>` | 只读 | 公开训练输入 |
| `/workspace/evaluations/<request_id>` | 只读 | 评估反馈、原始文本日志和指标文件 |

评估结束后，反馈中的 `artifacts_dir` 指向容器内结果目录，`files_index` 指向文件索引。`feedback.json` 保存结构化反馈，`files.json` 列出日志和指标的路径。Agent 可用终端直接阅读文件。较大的文本文件完整压缩为 `.gz`，可用 `zcat` 或 Python 的 `gzip` 模块读取。

`context.files` 提供源码、开发说明、框架和评估目录的位置。默认 Agent 的提示词、父候选选择和搜索策略都在参赛开发目录内，可以自行替换。模型请求统一使用当前赛事配置的 DeepSeek Flash 文本接口，Agent 容器通过外层网关访问模型。运行镜像提供开发依赖，CPU 和内存配额控制本地资源使用。

## 项目代码组织

| 目录 | 作用 |
| --- | --- |
| `AgenticBench/agent/loss_decoder/` | 表征学习 TP-GNN 的 Agent 与函数程序 |
| `AgenticBench/agent/binary_loss/` | 概率预测 GNN 的 Agent 与函数程序 |
| `AgenticBench/contest2/` | 启动入口、外层 harness、模型网关与预算管理 |
| `AgenticBench/local_tasks/tp_gnn_loss_decoder_timing/` | 表征学习任务的函数接口与固定配置 |
| `AgenticBench/local_tasks/tp_gnn_binary_loss_timing/` | 概率预测任务的函数接口与固定配置 |
| `AgenticBench/local_bench/` | 候选校验、矩阵运行与结果核验 |
| `Place-3D/` | 切分、双层布局和 HBT 的原生实现 |
| `open3dbench/`、`OpenROAD-3D/` | 物理流程编排、OPT 与时序测量 |

## 任务与评估

公开训练集为 `bp_fe-ng45`、`bp-ng45`、`ariane133-ng45`。公开验证集为 `swerv_wrapper-ng45`、`bp_fe-asap7`。切分与布局使用配对种子，I/O 种子固定为 1。表示学习路径每例使用 1001、1002、1003。概率路径的 Ariane133/ng45 固定为 1003，其余算例使用 1001、1002、1003。另有两例隐藏算例用于最终评估。

两条基线共用表示学习基线的固定宏单元 halo 设置，单位为 μm：

| 算例 | seed1001 | seed1002 | seed1003 |
| --- | ---: | ---: | ---: |
| bp_fe-ng45 | 5 | 5 | 5 |
| bp-ng45 | 10 | 10 | 10 |
| ariane133-ng45 | 10 | 5 | 10 |
| swerv_wrapper-ng45 | 5 | 5 | 5 |
| bp_fe-asap7 | 0 | 0 | 0 |

外层 harness 在模型调用与评估受理前核对配置。配置变化后的参考结果通过重新运行生成。

每个候选须为全部原始实例给出唯一的上层或下层归属。上层总面积占比须在 47%–53% 之间。有宏单元时，上层宏数量与宏面积占比均须在 45%–55% 之间。固定布局、PDN 和 HBT 流程之后执行一次 OPT，在 CTS 前以放置估计 RC、理想时钟及无源 HBT 模型读取全局 WNS 和 TNS。任一组运行缺失、不合法或测量值非有限，则整次训练评估失败。

对每组运行，先将 WNS、TNS 分别转为负时序裕量 `max(0, −slack)`，再与该算例统一的评分参考值计算改善率。同一 case 的所有种子及两条 GNN 均使用相同的分母：

```text
改善率 = (参考负时序裕量 − 候选负时序裕量) / 参考负时序裕量
单组分数 = 100 × (0.4 × WNS 改善率 + 0.6 × TNS 改善率)
```

每个算例按预先固定的种子集合等权平均，算例之间再等权平均。评分参考值由两条 GNN 的既有参考测量计算：先分别对每条基线、每个 case 的规定种子取平均，再对 WNS 和 TNS 的负时序裕量应用同一校准公式：

```text
共同参考值 = 1.0713470534964063 × 表示基线均值
           − 0.0713470534964063 × 概率基线均值
```

该系数使两条 GNN 在五个公开 case 上的等权平均初始得分均为 0。参考值属于评分归一化参数，所有分母均为正，不代表一次原生物理运行的结果。在两条基线数值之间做凸组合无法同时满足五个 case 的得分校准，因此部分参考值略超出两者之间的范围。

概率路径的 Ariane 使用 seed 1003，表示路径的 Ariane 使用三个种子，其他 case 均使用三个种子。原始参考结果和合法性核验保持不变。训练集单独计算时，两条基线的初始得分分别约为 −6.580928（概率）和 −0.438261（表示），公开验证集分别约为 9.871391 和 0.657392。五个 case 合并时按 case 等权平均，不将两个集合的平均分直接等权相加。

共同参考值及其原始测量记录见 `AgenticBench/contest2/manifests/common-timing-reference.json`。外层 harness 在 `cell.json`、矩阵 `evaluation_result.json` 和 Agent 反馈中返回共同参考分数。原生单组评估文件保留按原生配对参考计算的诊断分数，反馈中的 `native_paired_combined_score` 对应这一数值。

每队每条基线分别享有 **10 次训练评估提交** 和 **15 元模型 API 费用额度**。两条基线的次数、费用和断点记录相互独立。每次候选提交占用一次评估额度，包括函数接口、修改范围等检查未通过的提交，以及训练或物理流程失败的候选。同一请求 ID 的重复查询或重传只计一次。失败反馈包含 case、seed、异常原因和可用的原生日志片段。公开验证在最终候选确定后运行。
