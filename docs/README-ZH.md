# AI 工作站引导与基准测试套件 — 版本 3.1.0

本项目用于在 macOS、Linux、Windows 上快速、安全地搭建 AI 开发环境。重点关注安全（加固脚本）、简洁性以及可操作性。

英文版：../README.md

## 特性
- 加固的专业引导脚本
- 通过 requirements.txt 固定依赖版本，确保可重复性
- 提供 macOS 与 Windows 优化脚本
- 简单的基准测试用于验证 GPU/CPU 性能
- 完整且更新的文档

## 前置要求
- Python 3.10+
- Git
- 网络连接

## 快速开始
1) 激活环境：
   - pip-venv 模式：
     - `source ~/.venvs/ai/bin/activate`
   - Conda 模式：
     - `conda activate ai-base`（或 `ai-llm` / `ai-vision`）

2) 安装固定依赖（推荐）：
   - `pip install -r requirements.txt`

3) （可选）进行引导（macOS/Linux）：
   - `bash scripts/bootstraps/ai_workstation_bootstrap_pro.sh`

4) Windows（可选）：
   - 运行 PowerShell：
     - `scripts/windows/ai_bootstrap_windows.ps1`
     - 或 Surface 脚本：`scripts/windows/surface_ai_optimize_v_2.ps1`

## 项目结构
- scripts/
  - bootstraps/ai_workstation_bootstrap_pro.sh
  - mac/mac_ai_optimize.sh
  - windows/surface_ai_optimize_v_2.ps1
  - windows/ai_bootstrap_windows.ps1
- python/
  - __init__.py
  - system_info.py
  - benchmarks/
    - torch_bench.py
    - memory_check.py
  - run_all_benchmarks.py
- docs/
  - README-ZH.md
  - README-FA.md
  - benchmarks/README.md
  - security_policy.md
  - CHANGELOG.md
- requirements.txt

## 基准测试
运行基准测试：
- `python python/benchmarks/torch_bench.py`
- `python python/benchmarks/memory_check.py`

综合运行并保存结果（JSON/CSV）：
- `python python/run_all_benchmarks.py --device auto --size 4096 --runs 3 --outdir benchmarks/results --pretty`

基准测试使用说明：`docs/benchmarks/README.md`

## 安全说明
- 所有安装脚本均本地下载后再执行，避免直接从互联网管道到 shell。
- 专业引导脚本采用严格的变量引用与本地执行策略，并提供错误处理。
- 通过 `requirements.txt` 使用固定版本，提升稳定性与可重复性。

## 许可证
MIT 许可证。