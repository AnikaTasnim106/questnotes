@echo off
cd /d "%~dp0"
set PY=python
where py >nul 2>nul && set PY=py
if not exist .env (
  echo First time setup: get a free key at https://aistudio.google.com
  set /p KEY=Paste your Gemini API key here and press Enter: 
  call echo GEMINI_API_KEY=%%KEY%%> .env
  echo Saved. You will not be asked again.
)
echo Installing packages - the first time takes a minute...
%PY% -m pip install -q -r requirements.txt
echo.
echo Starting the QuestNotes server. Keep this window open while you play.
echo.
%PY% -m uvicorn main:app --port 8000
pause
