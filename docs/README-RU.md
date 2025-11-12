# Набор для подготовки и тестирования рабочей станции ИИ — версия 3.1.0

Проект предназначен для быстрого и безопасного развертывания среды разработки ИИ на macOS, Linux и Windows. Акцент на безопасность (усиленные скрипты), простоту и операционную пригодность.

Английская версия: ../README.md

## Возможности
- Профессиональный скрипт подготовки с усилением безопасности
- Фиксация версий зависимостей через requirements.txt для воспроизводимости
- Скрипты оптимизации для macOS и Windows
- Простые бенчмарки для проверки производительности GPU/CPU
- Полная и актуальная документация

## Требования
- Python 3.10+
- Git
- Доступ в интернет

## Быстрый старт
1) Активируйте окружение:
   - режим pip-venv:
     - `source ~/.venvs/ai/bin/activate`
   - режим Conda:
     - `conda activate ai-base` (или `ai-llm` / `ai-vision`)

2) Установка фиксированных зависимостей (рекомендуется):
   - `pip install -r requirements.txt`

3) Необязательная подготовка (macOS/Linux):
   - `bash scripts/bootstraps/ai_workstation_bootstrap_pro.sh`

4) Windows (необязательно):
   - Запуск PowerShell:
     - `scripts/windows/ai_bootstrap_windows.ps1`
     - или скрипт Surface: `scripts/windows/surface_ai_optimize_v_2.ps1`

## Структура проекта
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
  - README-RU.md
  - README-FA.md
  - benchmarks/README.md
  - security_policy.md
  - CHANGELOG.md
- requirements.txt

## Бенчмарки
Запуск бенчмарков:
- `python python/benchmarks/torch_bench.py`
- `python python/benchmarks/memory_check.py`

Комплексный запуск и сохранение результатов (JSON/CSV):
- `python python/run_all_benchmarks.py --device auto --size 4096 --runs 3 --outdir benchmarks/results --pretty`

Руководство по бенчмаркам: `docs/benchmarks/README.md`

## Замечания по безопасности
- Все установочные скрипты сначала скачиваются локально, затем выполняются; избегается прямой конвейер в shell.
- Профессиональный подготовительный скрипт использует строгие кавычки переменных, локальное выполнение скачанных файлов и корректную обработку ошибок.
- Установка зависимостей через `requirements.txt` с фиксированными версиями обеспечивает стабильность и воспроизводимость.

## Лицензия
Проект распространяется по лицензии MIT.