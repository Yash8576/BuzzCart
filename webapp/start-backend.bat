@echo off
echo Starting Buzz Social Cart Backend...
cd /d %~dp0backend
C:\Users\dravi\Downloads\webapp\.venv\Scripts\python.exe -m uvicorn server:app --reload --port 8000
