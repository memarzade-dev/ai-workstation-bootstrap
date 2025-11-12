# مجموعة إعداد واختبار محطة عمل الذكاء الاصطناعي — الإصدار 3.1.0

هذا المشروع يهدف إلى إعداد بيئة تطوير الذكاء الاصطناعي بشكل آمن وسريع على أنظمة macOS وLinux وWindows. يتم التركيز على الأمان (سكربتات مُحصّنة)، البساطة، وقابلية التشغيل.

النسخة الإنجليزية: ../README.md

## الميزات
- سكربت إعداد احترافي مع تعزيزات أمنية
- تثبيت الاعتمادات بإصدارات مثبتة (requirements.txt)
- سكربتات تحسين لأنظمة macOS وWindows
- بنشماركات بسيطة للتحقق من أداء GPU/CPU
- توثيق كامل ومحدّث

## المتطلبات
- Python 3.10+
- Git
- اتصال بالإنترنت

## البدء السريع
1) تفعيل البيئة:
   - وضع pip-venv:
     - `source ~/.venvs/ai/bin/activate`
   - وضع Conda:
     - `conda activate ai-base` (أو `ai-llm` / `ai-vision`)

2) تثبيت الاعتمادات (مُثبتة ومُوصى بها):
   - `pip install -r requirements.txt`

3) إعداد اختياري (macOS/Linux):
   - `bash scripts/bootstraps/ai_workstation_bootstrap_pro.sh`

4) Windows (اختياري):
   - تشغيل PowerShell:
     - `scripts/windows/ai_bootstrap_windows.ps1`
     - أو سكربت Surface: `scripts/windows/surface_ai_optimize_v_2.ps1`

## هيكل المشروع
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
  - README-AR.md
  - README-FA.md
  - benchmarks/README.md
  - security_policy.md
  - CHANGELOG.md
- requirements.txt

## البنشماركات
لتشغيل البنشمارك:
- `python python/benchmarks/torch_bench.py`
- `python python/benchmarks/memory_check.py`

تشغيل شامل وحفظ النتائج (JSON/CSV):
- `python python/run_all_benchmarks.py --device auto --size 4096 --runs 3 --outdir benchmarks/results --pretty`

دليل البنشماركات: `docs/benchmarks/README.md`

## ملاحظات أمنية
- يتم تنزيل الملفات محليًا والتحقق منها قبل التنفيذ؛ نتجنب تنفيذ التعليمات مباشرة من الإنترنت.
- السكربت الاحترافي يعتمد اقتباسًا صارمًا للمتغيرات، وتنفيذًا محليًا للملفات المُنزّلة، ومعالجة أخطاء مناسبة.
- تثبيت الاعتمادات عبر `requirements.txt` بإصدارات مثبتة لضمان الثبات وقابلية التكرار.

## الترخيص
المشروع مرخّص تحت MIT.