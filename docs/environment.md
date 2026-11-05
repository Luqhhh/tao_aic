# 环境配置与检查

截至 2026-11-05，已完成远程 Docker GPU 环境、官方镜像及 EDA 工具检查，DeepSeek 鉴权和指定模型可用性检查也已通过。官方矩阵的兼容问题仍阻止完整基线启动；未调用模型生成接口或提交训练评估。

## 主机要求

使用 Ubuntu amd64 GPU 主机，并具备实际运行 Docker GPU 容器的能力。仅有容器内 root 权限不足以保证 Docker 可用。

- 官方非布线评估请求 4 CPU、24 GiB 容器内存、16 GiB 工作空间、1 张 GPU。
- 官方资源准入额外保留 4 GiB 可用内存、10 GiB 空闲磁盘，因此开始一个物理评估前至少需要 **28 GiB 可用内存、26 GiB 空闲工作磁盘**。原始包、解压材料、Docker 镜像本身还需另外占用空间。
- GPU 准入要求至少 4096 MiB 空闲显存；这只是入口检查，不保证所有算例的实际显存占用。
- Agent 默认另有 32 GiB 内存上限。计算资源应同时容纳 Agent、物理流程及主机开销。

依据：官方源码 `AgenticBench/local_bench/matrix_docker.py`、`grt_bench/runtime.py` 及 `contest2/runner.py`。保留这些原始资源限制，不通过修改评估器降低要求。

本地 WSL 总内存约 16 GiB，未达到完整评估准入条件，用户已选择远程服务器。

## 远程实例

当前使用 Ubuntu-nvidia 22.04 虚拟机，16 个逻辑 CPU、约 62 GiB 内存、RTX 4090 24 GB，项目目录为 `/home/ubuntu/tao_aic`。该实例以 systemd 启动，普通用户有 sudo 权限，可以安装主机 Docker；不再受嵌套容器限制。主机地址、SSH 私钥及密码不写入仓库。

已验证的软件与运行环境：

| 项目 | 结果 |
| --- | --- |
| 主机 Python / PyYAML | 3.10.12 / 6.0.3 |
| Docker Engine | 29.9.3，普通用户可用，systemd 开机启动 |
| NVIDIA 驱动 / Container Toolkit | 570.153.02 / 1.20.1 |
| Codex CLI | 0.166.0，官方启动参数可用 |
| 官方镜像 | config ID `sha256:f2401e978e5504c11cbc048266cc088152f3d5cf0a1a5438d91933175c9b7821`，56 层全部匹配 |
| 镜像内 PyTorch / CUDA | 1.7.1+cu110 / 11.0，RTX 4090 上反向传播通过 |
| DREAMPlace | 实际 HPWL CUDA 算子检查通过 |
| EDA 工具 | OpenROAD、OpenSTA、Yosys 启动检查通过；OpenSTA 3.1.0、Yosys 0.58；OpenROAD 的版本字符串为 `GITDIR-NOTFOUND` |
| 导入后空闲磁盘 | 约 45 GiB，超过 26 GiB 准入要求 |

Docker 29 使用已核验的 manifest 地址识别此镜像；官方 `runtime_images` 适配器把它映射回固定 config ID，不修改镜像。镜像内原有的 PyTorch、CUDA 和 EDA 依赖保持原样。

此前检查的 GPUHome 普通实例是容器，没有 Docker socket，无法创建 namespace；其[官方说明](https://docs.gpuhome.cc/docs/environment/docker.html)也明确不支持二级运行时。未在该实例安装 Docker 或上传大型比赛包。

## 在支持 Docker 的主机部署

克隆本仓库，将三个原始压缩包传到项目的 `materials/archives/`，保留文件名。完整性校验清单在 `manifests/assets.json`。

如果 Ubuntu amd64 主机尚未安装 Docker 和 NVIDIA Container Toolkit，在该主机以 root 执行：

```bash
bash scripts/setup_host.sh <运行比赛的Linux用户名>
```

脚本使用 [Docker 官方软件源](https://docs.docker.com/engine/install/ubuntu/)及 [NVIDIA Container Toolkit 官方软件源](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)，安装容器环境并配置 GPU runtime。它要求 systemd 主机；已有正常运行的 Docker GPU 环境时可跳过。驱动由所用 GPU 主机维护。

加入 `docker` 用户组后，新登录会话才会取得组权限。后续操作使用该普通用户，在项目根目录执行：

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-host.txt
bash scripts/extract_materials.sh
docker load -i materials/archives/open3dbench-contest-runtime.tar.gz
```

`extract_materials.sh` 先校验原文件 SHA-256，再解压到新目录；已有解压目录时会停止，以保留现有材料。

比赛 GPU 及 EDA 依赖来自固定镜像，主机只安装编排依赖。先独立验证官方镜像的身份和全部文件层、PyTorch CUDA 反向传播、DREAMPlace HPWL CUDA 算子，以及容器内 OpenROAD、OpenSTA、Yosys 的版本：

```bash
.venv/bin/python scripts/check_runtime.py
```

该脚本复用官方 `contest2.runtime_images` 校验，不加载评估矩阵、不创建比赛预算账本。结果保存在 `results/environment/runtime/runtime-check.json`。

随后可以运行官方 `check`，它还会验证矩阵和评分参考，但不会提交候选评估或调用模型：

```bash
bash scripts/contest2.sh check --baseline loss_decoder --work-root "$PWD/results/environment/loss_decoder"
bash scripts/contest2.sh check --baseline binary_loss --work-root "$PWD/results/environment/binary_loss"
```

两条基线均已执行官方 `contest2.runner.main check`，在参考结果加载处以 `Packed GNN reference authority is incomplete` 停止。检查使用官方镜像地址适配器，避免 Docker 29 为同一镜像重复导入归档；未修改官方源码。结果汇总在 `results/environment/official-checks.json`，每条基线的日志在对应目录的 `check.log`。两个检查账本中的评估与模型调用记录均为 0，当前材料兼容问题见下文。

## 默认 Agent 的主机工具

已安装 Codex CLI 0.166.0，入口为 `~/.local/bin/codex`，完整官方 Linux 包保存在 `~/.local/share/codex/0.166.0`。该版本接受源码要求的 `--ignore-user-config` 和 `--ignore-rules` 参数，`codex exec --help` 已验证。

安装方式依据 [OpenAI Docs 的 Codex CLI 说明](https://learn.chatgpt.com/docs/codex/cli)。远程下载返回 403，因此本次在本机取得官方 GitHub Release 的完整 Linux 包，对照官方发布元数据核对 SHA-256 后上传，服务器再次核对摘要再解压；未替换已有 CLI。安装包及下载记录保存在忽略的 `results/environment/` 中。

官方 Agent 通过其计费网关使用 `deepseek-flash`。用户提供的 DeepSeek API key 已保存至服务器的 `~/.config/tao-aic/deepseek.key`，目录权限为 0700、文件权限为 0600，位于源码、数据和工作目录之外。密钥未写入 Git、命令参数或安装日志。

`scripts/contest2.sh` 在没有显式设置密钥环境变量时，自动把上述文件路径交给官方入口；可通过 `DEEPSEEK_API_KEY`、`DEEPSEEK_API_KEY_FILE` 或官方 `--api-key-file` 参数覆盖。直接运行 `python -m contest2` 时需自行传递密钥文件路径。

已通过官方 `check_provider` 的只读 `/models` 检查：鉴权有效且 `deepseek-flash` 可用。记录位于 `results/environment/provider/control/provider-preflight.json`。该检查不生成模型输出；环境准备阶段没有登录 Codex 账户或调用模型生成接口。

## 当前官方材料兼容问题

执行以下静态检查不需要 Docker、不调用模型、不创建评估账本：

```bash
.venv/bin/python scripts/check_materials.py
```

本批材料的实际检查结果为：

| 基线 | 集合 | 数据清单组数 | 源码种子要求 | 官方矩阵加载结果 |
| --- | --- | ---: | ---: | --- |
| `loss_decoder` | train | 9 | 9 | 参考校验信息缺失 |
| `loss_decoder` | validation | 6 | 6 | 参考校验信息缺失 |
| `binary_loss` | train | 9 | 7 | 参考校验信息缺失，另有种子冲突 |
| `binary_loss` | validation | 6 | 6 | 参考校验信息缺失 |

矩阵加载的首个错误是 `ValueError: Packed GNN reference authority is incomplete`。当前源码 `local_bench/packed_gnn_reference.py` 要求参考结果回执具有 `artifacts.packed_reference` 字段，并核对摘要、切分、候选快照和实现校验信息；提供的数据回执缺少该字段。此问题来自官方包之间的接口不一致，不是 Python 依赖缺失。

应取得互相匹配的官方源码和数据，或由官方提供修订。本次配置不伪造参考结果校验信息、不绕过官方检查，也不自行决定七组或九组的赛事口径。PDF 与任务包差异详见 [rules.md](rules.md)。

官方 `run` 会启动 Agent 演化和计费流程。复现官方初始算法的入口及范围，应在材料兼容、环境检查通过后单独确定。
