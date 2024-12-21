#!/bin/bash
streamlit run /root/streamlit-project/main.py --server.port 80 > /dev/null 2> /dev/null < /dev/null &
python /root/streamlit-project/back_end/app.py > /dev/null 2> /dev/null < /dev/null &


rm -rf /opt/codedeploy-agent/deployment-root/*
exit 0