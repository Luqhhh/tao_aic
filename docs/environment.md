# 环境配置与检查

截至 2026-11-05，已完成本地 Python 环境和官方数据静态检查；远程 Docker 环境尚未就绪，未调用模型或提交训练评估。

## 主机要求

使用 Ubuntu amd64 GPU 主机，并具备实际运行 Docker GPU 容器的能力。仅有容器内 root 权限不足以保证 Docker 可用。

- 官方非布线评估请求 4 CPU、24 GiB 容器内存、16 GiB 工作空间、1 张 GPU。
- 官方资源准入额外保留 4 GiB 可用内存、10 GiB 空闲磁盘，因此开始一个物理评估前至少需要 **28 GiB 可用内存、26 GiB 空闲工作磁盘**。原始包、解压材料、Docker 镜像本身还需另外占用空间。
- GPU 准入要求至少 4096 MiB 空闲显存；这只是入口检查，不保证所有算例的实际显存占用。
- Agent 默认另有 32 GiB 内存上限。计算资源应同时容纳 Agent、物理流程及主机开销。

依据：官方源码 `AgenticBench/local_bench/matrix_docker.py`、`grt_bench/runtime.py` 及 `contest2/runner.py`。保留这些原始资源限制，不通过修改评估器降低要求。

本地 WSL 总内存约 16 GiB，未达到完整评估准入条件，用户已选择远程服务器。

## 已检查的远程实例

已连接到用户提供的 GPUHome 实例，识别到 RTX 4090 24 GB、100 GiB cgroup 内存限额及 15 CPU 的配额。实例的 `free` 显示的是物理宿主机内存，应以 cgroup 限额判断本实例资源。

该实例没有 Docker socket，PID 1 为 `tini`，创建用户 namespace 返回 `Operation not permitted`。平台的[Docker 与容器化不可用说明](https://docs.gpuhome.cc/docs/environment/docker.html)明确说明普通实例不支持 Docker、containerd、Podman、Apptainer 等二级运行时。

因此该实例无法直接运行当前官方评估入口。下一步需要能运行 Docker GPU 容器的主机，或平台提供的相应环境；未向该实例传输大型比赛包，也未安装 Docker。连接密码不写入仓库或部署脚本。

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

比赛 GPU 及 EDA 依赖来自固定镜像，主机只安装编排依赖。镜像 ID 和完整文件层由官方 `contest2.runtime_images` 核验。随后可以运行官方 `check`，它会执行实际 CUDA 和 DREAMPlace HPWL 算子，但不会提交候选评估或调用模型：

```bash
bash scripts/contest2.sh check --baseline loss_decoder --work-root "$PWD/results/environment/loss_decoder"
bash scripts/contest2.sh check --baseline binary_loss --work-root "$PWD/results/environment/binary_loss"
```

上述命令会在指定工作目录生成检查记录和空预算账本；当前材料兼容问题会使其无法全部通过，见下文。

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
