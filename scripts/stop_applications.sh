#!/bin/bash

terminate_process() {
  local PIDS=$1
  local NAME=$2

  if [ -z "$PIDS" ]; then
    echo "$NAME is not running"
  else
    for PID in $PIDS; do
      echo "Kill -9 $PID ($NAME)"
      kill -9 $PID
      sleep 1
    done
  fi
}

# Find PIDs
APP_PID=$(pgrep streamlit)
FLASK_PIDS=$(pgrep -f "python app.py")

# Terminate processes
terminate_process "$APP_PID" "Streamlit"
terminate_process "$FLASK_PIDS" "Flask"

sleep 5
exit 0