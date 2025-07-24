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

- app 코드 변경

```bash
        # AutoScaling Group에서 인스턴스 목록 가져오기
        token = self.get_token()
        region = self.get_instance_metadata(token, "placement/region")
        ec2_client = boto3.client('ec2', region_name=region)
        autoscaling_client = boto3.client('autoscaling', region_name=region)
        asg_name = "lab-edu-asg-web"
        try:
            asg_response = autoscaling_client.describe_auto_scaling_groups(
                AutoScalingGroupNames=[asg_name]
            )
            
            if not asg_response['AutoScalingGroups']:
                st.error(f"AutoScaling Group '{asg_name}'을 찾을 수 없습니다.")
                return
            
            # ASG의 인스턴스 ID 목록 추출
            asg_instances = asg_response['AutoScalingGroups'][0]['Instances']
            instance_ids = [instance['InstanceId'] for instance in asg_instances if instance['LifecycleState'] == 'InService']
            
            if not instance_ids:
                st.warning(f"AutoScaling Group '{asg_name}'에 실행 중인 인스턴스가 없습니다.")
                return
            
            # EC2 인스턴스 세부 정보 가져오기
            ec2_response = ec2_client.describe_instances(InstanceIds=instance_ids)
            
            instances_info = []
            
            for reservation in ec2_response['Reservations']:
                for instance in reservation['Instances']:
                    # 인스턴스 이름 태그 찾기
                    instance_name = "N/A"
                    if 'Tags' in instance:
                        for tag in instance['Tags']:
                            if tag['Key'] == 'Name':
                                instance_name = tag['Value']
                                break
                    
                    # 인스턴스 정보 수집
                    instance_info = {
                        "Name": instance_name,
                        "Instance ID": instance['InstanceId'],
                        "Instance Type": instance['InstanceType'],
                        "State": instance['State']['Name'],
                        "Availability Zone": instance['Placement']['AvailabilityZone'],
                        "Private IP": instance.get('PrivateIpAddress', 'N/A'),
                        "Public IP": instance.get('PublicIpAddress', 'N/A'),
                        "Launch Time": instance['LaunchTime'].strftime('%Y-%m-%d %H:%M:%S')
                    }
                    instances_info.append(instance_info)
            
            # DataFrame 생성 및 테이블 출력
            if instances_info:
                df = pd.DataFrame(instances_info)
                st.subheader(f"AutoScaling Group: {asg_name}")
                st.write(f"총 {len(instances_info)}개의 인스턴스")
                st.table(df)
            else:
                st.warning("인스턴스 정보를 가져올 수 없습니다.")

        except Exception as e:
            st.error(f"오류 발생: {str(e)}")
            # fallback: 현재 인스턴스 정보만 표시
            st.info("현재 인스턴스 정보로 대체합니다.")
            current_instance_id = self.get_instance_metadata(token, "instance-id")
            name_tag = self.get_instance_name_tag(ec2_client, current_instance_id)
            metadata_info = {
                "Name": name_tag,
                "Instance ID": current_instance_id,
                "Instance Type": self.get_instance_metadata(token, "instance-type"),
                "Region": region,
                "Availability Zone": self.get_instance_metadata(token, "placement/availability-zone"),
                "Private IP": self.get_instance_metadata(token, "local-ipv4"),
                "Public IP": self.get_instance_metadata(token, "public-ipv4"),
            }
            df = pd.DataFrame(list(metadata_info.items()), columns=['Metadata', 'Value'])
            st.table(df)
```

- code deploy 배포 그룹 추가 (lab-edu-cd-deploygroup-asg)

  - 배포 그룹 이름 : lab-edu-cd-deploygroup-asg
  - 서비스 역할 : ***********lab-edu-role-codedeploy
  - 환경 구성 : Amazon EC2 Auto Scaling 그룹
  - Auto Scaling Group : lab-edu-asg-web
  - 배포 구성 : CodeDeployDefault.AllAtOnce

  