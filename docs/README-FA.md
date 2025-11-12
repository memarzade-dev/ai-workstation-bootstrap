# بوت‌استرپر حرفه‌ای ایستگاه‌کاری هوش‌مصنوعی — نسخه ۳.۱.۰

این پروژه برای راه‌اندازی سریع و امن محیط توسعه هوش‌مصنوعی بر روی macOS، Linux و Windows طراحی شده است. تمرکز روی امنیت (اسکریپت‌های سخت‌سازی‌شده)، سادگی و قابلیت‌های عملیاتی است.

نسخه انگلیسی: README.md

## ویژگی‌ها
- اسکریپت بوت‌استرپ حرفه‌ای با امن‌سازی پیشرفته
- نصب وابستگی‌ها با نسخه‌های پین‌شده (requirements.txt)
- اسکریپت‌های بهینه‌سازی برای macOS و Windows
- بنچمارک‌های ساده برای صحت عملکرد GPU/CPU
- مستندسازی کامل و به‌روز

## پیش‌نیازها
- Python 3.10+
- Git
- دسترسی به اینترنت

## شروع سریع
1) فعال‌سازی محیط:
   - حالت pip-venv:
     - source ~/.venvs/ai/bin/activate (در صورت داشتن venv از پیش ساخته)
   - حالت Conda:
     - conda activate ai-base (یا ai-llm / ai-vision)

2) نصب وابستگی‌ها (پین‌شده و توصیه‌شده):
   - pip install -r requirements.txt

3) بوت‌استرپ اختیاری (macOS/Linux):
   - bash scripts/bootstraps/ai_workstation_bootstrap_pro.sh

4) Windows (اختیاری):
   - اجرای پاورشل:
     - scripts/windows/ai_bootstrap_windows.ps1
     - یا اسکریپت Surface: scripts/windows/surface_ai_optimize_v_2.ps1

## ساختار پروژه
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
- docs/
  - README.md
  - README-FA.md
  - benchmarks/README.md
  - security_policy.md
  - changeset_summary.md
  - CHANGELOG.md
- requirements.txt

## بنچمارک‌ها
برای اجرای بنچمارک:
- python python/benchmarks/torch_bench.py
- python python/benchmarks/memory_check.py

اجرای جامع و ذخیره نتایج (JSON/CSV):
- python python/run_all_benchmarks.py --device auto --size 4096 --runs 3 --outdir benchmarks/results --pretty

راهنمای تکمیلی بنچمارک‌ها: docs/benchmarks/README.md

## نکات امنیتی
- تمام دانلودها به‌صورت امن و با اعتبارسنجی اجرا می‌شوند؛ از اجرای مستقیم کدهای ناشناخته جلوگیری می‌شود.
- اسکریپت بوت‌استرپ حرفه‌ای شامل نقل‌قول سخت‌گیرانه، اجرای محلی اسکریپت‌های دانلودی، و کنترل خطاهاست.
- نصب وابستگی‌ها از طریق requirements.txt با نسخه‌های پین‌شده، برای تکرارپذیری و پایداری.

## مجوز
این پروژه تحت مجوز MIT منتشر شده است.