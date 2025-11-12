# مستندات بنچمارک‌ها

این پوشه شامل اسکریپت‌های ساده برای ارزیابی عملکرد CPU/GPU و صحت تنظیمات محیط هوش‌مصنوعی است.

## فایل‌ها
- python/benchmarks/torch_bench.py — بنچمارک ماتمول برای CPU/GPU (CUDA/MPS)
- python/benchmarks/memory_check.py — بررسی مصرف حافظه پس از تخصیص تانسورها
- python/system_info.py — گزارش کامل سخت‌افزار و محیط سیستم

## اجرای بنچمارک‌ها
1) نصب پیش‌نیازها:
- pip install -r requirements.txt

2) اجرای گزارش سیستم:
- python python/system_info.py

3) اجرای بنچمارک ماتمول:
- python python/benchmarks/torch_bench.py

4) بررسی حافظه:
- python python/benchmarks/memory_check.py

نکته: اگر GPU CUDA فعال باشد، torch_bench به‌صورت خودکار تست GPU را نیز اجرا می‌کند. در macOS با Apple Silicon، بنچمارک از MPS استفاده می‌کند اگر فعال باشد.