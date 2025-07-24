# 1. Streamlit Sample Project

## Auto Scaling Group 

- streamlit, Flask 실행 명령 주석처리 (/etc/rc.c/rc.local)

```bash
#!/bin/bash
# streamlit run /root/streamlit-project/main.py --server.port 80 > /dev/null 2> /dev/null < /dev/null &
# python /root/streamlit-project/backend/app.py > /dev/null 2> /dev/null < /dev/null &
```

- systemd 등록

```bash
# /etc/systemd/system/streamlit.service
[Unit]
Description=Run main.py on server boot
After=network.target

[Service]
ExecStart=/usr/local/bin/streamlit run /root/streamlit-project/main.py --server.port 80
WorkingDirectory=/root/streamlit-project
Restart=always
User=root
StandardOutput=append:/var/log/streamlit.log
StandardError=append:/var/log/streamlit.log

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/backend.service
[Unit]
Description=Run main.py on server boot
After=network.target

[Service]
ExecStart=/usr/bin/python /root/streamlit-project/backend/app.py
WorkingDirectory=/root/streamlit-project/backend
Restart=always
User=root
StandardOutput=append:/var/log/backend.log
StandardError=append:/var/log/backend.log

[Install]
WantedBy=multi-user.target
```

- service 실행

```bash
systemctl daemon-reload
systemctl start streamlit.service
systemctl start backend.service
systemctl enable streamlit.service
systemctl enable backend.service
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

- code deploy 배포 설정 수정

```bash
# ApplicationStop 후크 주석처리
hooks:
  # ApplicationStop:
  #   # - location: scripts/stop_streamlit.sh
  #   - location: scripts/stop_applications.sh
  #     timeout: 10
```

- start_application.sh 파일 수정

```bash
#!/bin/bash

systemctl restart streamlit.service
systemctl restart backend.service
```

- github actions asg 배포 스텝 추가

```bash
      # Step 3
      - name: Create CodeDeploy Deployment (ASG)
        id: deploy-asg
        run: |
          aws deploy create-deployment \
            --application-name lab-edu-cd-application-streamlit \
            --deployment-group-name lab-edu-cd-deploygroup-asg \
            --deployment-config-name CodeDeployDefault.OneAtATime \
            --github-location repository=${{ github.repository }},commitId=${{ github.sha }}
```

- code deploy 배포 그룹 추가 (lab-edu-cd-deploygroup-asg)

  - 배포 그룹 이름 : lab-edu-cd-deploygroup-asg
  - 서비스 역할 : ***********lab-edu-role-codedeploy
  - 환경 구성 : Amazon EC2 Auto Scaling 그룹
  - Auto Scaling Group : lab-edu-asg-web
  - 배포 구성 : CodeDeployDefault.AllAtOnce



- app 코드 변경 후 배포 (homepage_linux.py)