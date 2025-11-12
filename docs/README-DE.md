# KI-Workstation Bootstrap und Benchmark-Suite — Version 3.1.0

Dieses Projekt richtet eine sichere und schnelle KI-Entwicklungsumgebung auf macOS, Linux und Windows ein. Fokus auf Sicherheit (gehärtete Skripte), Einfachheit und Betriebsfähigkeit.

Englische Version: ../README.md

## Funktionen
- Professionelles Bootstrap-Skript mit Sicherheits-Hardening
- Abhängigkeiten mit festen Versionen über requirements.txt (deterministische Installation)
- Optimierungsskripte für macOS und Windows
- Einfache Benchmarks zur Verifizierung von GPU/CPU-Leistung
- Vollständige und aktuelle Dokumentation

## Voraussetzungen
- Python 3.10+
- Git
- Internetverbindung

## Schnellstart
1) Umgebung aktivieren:
   - pip-venv Modus:
     - `source ~/.venvs/ai/bin/activate`
   - Conda Modus:
     - `conda activate ai-base` (oder `ai-llm` / `ai-vision`)

2) Abhängigkeiten installieren (empfohlen, fixiert):
   - `pip install -r requirements.txt`

3) Optionales Bootstrap (macOS/Linux):
   - `bash scripts/bootstraps/ai_workstation_bootstrap_pro.sh`

4) Windows (optional):
   - PowerShell ausführen:
     - `scripts/windows/ai_bootstrap_windows.ps1`
     - oder Surface-Skript: `scripts/windows/surface_ai_optimize_v_2.ps1`

## Projektstruktur
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
  - README-DE.md
  - README-FA.md
  - benchmarks/README.md
  - security_policy.md
  - CHANGELOG.md
- requirements.txt

## Benchmarks
Benchmark ausführen:
- `python python/benchmarks/torch_bench.py`
- `python python/benchmarks/memory_check.py`

Kombinierter Lauf und Ergebnisablage (JSON/CSV):
- `python python/run_all_benchmarks.py --device auto --size 4096 --runs 3 --outdir benchmarks/results --pretty`

Benchmark-Anleitung: `docs/benchmarks/README.md`

## Sicherheitshinweise
- Alle Installationsskripte werden lokal heruntergeladen und anschließend ausgeführt; kein unsicheres Pipe-to-shell.
- Das professionelle Bootstrap-Skript nutzt strikte Variablen-Quotes, lokale Ausführung und sauberes Fehlerhandling.
- Abhängigkeiten werden über `requirements.txt` mit fixierten Versionen installiert — stabil und reproduzierbar.

## Lizenz
MIT-Lizenz.