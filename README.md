# tao_aic

“韬”智能杯 EDA 创新大赛，赛题 2：面向 3D 芯片网表切分的优化目标演化。

项目位于 WSL：`/home/lux1/tao_aic`，远程仓库为 <https://github.com/Luqhhh/tao_aic>。

**当前评估上限为每条基线 10 次训练评估，替代原 PDF 中的 30 次。** 随包 README 和官方任务包的预算实现均已采用 10 次。每条基线的模型 API 费用额度为 15 元，两条基线分别计账。规则及版本差异见 [docs/rules.md](docs/rules.md)。

## 目录

```text
tao_aic/
├── README.md
├── docs/
│   ├── rules.md                        # 当前规则、更新及材料差异
│   └── official/
│       ├── README.md                   # 随数据提供的原始开发说明
│       └── 赛题2_面向3D芯片网表切分的优化目标演化.pdf
├── manifests/
│   ├── assets.json                     # 原文件路径、字节数及 SHA-256
│   ├── extraction.json                 # 解压文件统计与链接检查记录
│   └── migration.json                  # 迁移验证和源文件清理记录
├── scripts/
│   └── verify_assets.py                # 校验本地原始材料
└── materials/                          # 本地保存，Git 忽略
    ├── archives/
    │   ├── contest-source.tar.gz
    │   ├── contest-data.tar.gz
    │   └── open3dbench-contest-runtime.tar.gz
    ├── contest-source/                 # 已解压的官方源码
    │   ├── AgenticBench/
    │   ├── Place-3D/
    │   ├── OpenROAD-3D/
    │   └── open3dbench/
    ├── contest-data/                   # 已解压的算例、参考结果及配置
    │   └── task2/
    ├── open3dbench-contest-runtime.tar.gz # 与 archives/同名文件为硬链接
    └── contest-work/                   # 后续运行时由官方框架生成
```

源码和数据保持相邻目录，以兼容官方的自动路径发现。镜像硬链接兼容原始 `runtime.json` 的相对路径，不额外占用一份镜像空间；官方启动器拒绝软链接，官方配置内容保持原样。

## 材料核验

原 D 盘赛题目录共 4 个文件、7,877,770,632 字节，另从 C 盘桌面复制规则 PDF。复制时逐文件比较源文件与目标文件的 SHA-256；源码、数据已解压，并逐个核对普通文件的大小。完整原始压缩包保存在 `materials/archives/`，来源与校验值见 [assets.json](manifests/assets.json)。

在项目根目录重新校验原始材料：

```bash
python3 scripts/verify_assets.py
```

该命令只读取文件，不启动比赛评估。D 盘源目录的清理结果见 [migration.json](manifests/migration.json)，C 盘桌面的原始 PDF 保留。

## 后续环境配置入口

安装与远程部署步骤见 [环境配置说明](docs/environment.md)。本地已创建 `.venv`（Python 3.10.12、PyYAML 6.0.3），可用 `bash scripts/contest2.sh --help` 查看官方入口。

正式运行依赖 Linux、Docker、NVIDIA GPU；默认 Agent 还需要主机上的 Codex CLI 和 DeepSeek API 配置。当前 WSL 未安装 Docker；用户已选择远程复现。已检查的 GPUHome 普通实例不支持二级容器，尚未加载比赛镜像或运行训练评估。

材料检查发现两类兼容问题：`binary_loss` 训练矩阵为 9 组而当前源码要求 7 组；两条基线的训练、验证矩阵还均因参考结果校验信息缺失而加载失败。详情见 [环境配置说明](docs/environment.md)和[规则说明](docs/rules.md)。官方原始材料保留原样。

Docker 可用后，在项目根目录加载官方镜像：

```bash
docker load -i materials/archives/open3dbench-contest-runtime.tar.gz
```

然后从官方入口检查两条基线：

```bash
cd materials/contest-source/AgenticBench
python3 -m contest2 check --baseline loss_decoder
python3 -m contest2 check --baseline binary_loss
```

训练、验证与 Agent 开发接口详见 [官方开发说明](docs/official/README.md)。API 密钥按官方要求放在源码、数据和工作目录之外。

## 版本管理范围

Git 跟踪项目说明、原始规则文档、校验清单及项目脚本。`materials/` 中的官方源码、数据、镜像和运行记录均在本地保存；从 GitHub 克隆仓库后，需要另外取得原始比赛包。后续自研 harness、提示模板和分析代码应放入独立的受版本管理目录，保留可追溯的开发历史。
