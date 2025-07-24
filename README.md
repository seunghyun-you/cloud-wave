# 1. Streamlit Sample Project

## Auto Scaling Group 

- streamlit, Flask auto start script (/etc/rc.c/rc.local)

  ```bash
  #!/bin/bash
  streamlit run /root/streamlit-project/main.py --server.port 80 > /dev/null 2> /dev/null < /dev/null &
  python /root/streamlit-project/backend/app.py > /dev/null 2> /dev/null < /dev/null &
  ```

- create ami (ec2-web)

- update launch template (ami version)

- change launch template in auto scaling group 

- check asg application (with auto scaling refresh)

```bash
aws autoscaling start-instance-refresh \
    --auto-scaling-group-name lab-edu-asg-web \
    --preferences MinHealthyPercentage=50,InstanceWarmup=300
```