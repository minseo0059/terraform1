name: Terraform Deploy VPC and EC2

on:
  workflow_dispatch:
    inputs:
      env:
        description: 'Environment (dev/stage/prod)'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - stage
          - prod

env:
  AWS_REGION: "ap-northeast-2"
  TF_STATE_BUCKET: "your-terraform-state-bucket" # 실제 버킷명으로 변경 필요

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: "1.6.6"

      - name: Terraform Init
        run: terraform init -backend-config="bucket=${{ env.TF_STATE_BUCKET }}" -backend-config="key=${{ github.event.inputs.env }}/terraform.tfstate"

      - name: Terraform Plan
        run: terraform plan -var="env=${{ github.event.inputs.env }}" -var="key_name=CH3-key"

      - name: Terraform Apply
        run: terraform apply -var="env=${{ github.event.inputs.env }}" -var="key_name=CH3-key" -auto-approve

      - name: Debug Terraform Outputs
        run: |
          echo "모든 Terraform 출력 확인:"
          terraform output -json > /tmp/terraform_outputs.json
          cat /tmp/terraform_outputs.json
          echo "---"
          echo "ec2_public_ip 출력값 확인 (Raw):"
          terraform output -raw ec2_public_ip || echo "Error: ec2_public_ip 출력이 없거나 비어 있습니다."
        continue-on-error: true

      - name: Get EC2 Public IP
        id: get_ip
        run: |
          # terraform output의 결과를 임시 변수에 저장하고, IP 주소만 필터링하고 공백/줄바꿈을 제거합니다.
          FULL_OUTPUT=$(terraform output -raw ec2_public_ip 2>&1)
          IFS= read -r EC2_IP_RAW < <(echo "$FULL_OUTPUT" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
          EC2_IP=$(echo "$EC2_IP_RAW" | tr -d '[:space:]' | tr -d '\n\r')

          if [ -z "$EC2_IP" ]; then
            echo "::error::EC2 Public IP를 가져오지 못했습니다. 출력: $FULL_OUTPUT"
            echo "::error::인스턴스에 퍼블릭 IP가 할당되었는지, 그리고 grep 패턴이 올바른지 확인하세요."
            exit 1
          else
            CLEAN_EC2_IP=$(echo "$EC2_IP" | xargs)
            echo "EC2_PUBLIC_IP=$CLEAN_EC2_IP" >> $GITHUB_OUTPUT
            echo "::debug::EC2 Public IP: $CLEAN_EC2_IP"
            echo "::debug::Final EC2_PUBLIC_IP (length: ${#CLEAN_EC2_IP}): '$CLEAN_EC2_IP'"
          fi
        shell: bash

      - name: Add SSH Key to Agent
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Install Ansible # 이것은 GitHub Actions 러너에 Ansible을 설치합니다.
        run: |
          sudo apt-get update
          sudo apt-get install -y ansible

      - name: Create Ansible Inventory and Run Playbook
        env:
          EC2_IP: ${{ steps.get_ip.outputs.EC2_PUBLIC_IP }}
        run: |
          echo "Attempting to SSH to ${{ env.EC2_IP }}"
          # EC2에 대한 연결 테스트 (선택 사항이지만 연결성 확인에 유용)
          ssh -o StrictHostKeyChecking=no ubuntu@${{ env.EC2_IP }} "echo 'SSH connection successful!'" || true

          # Ansible 인벤토리 파일 생성 (EC2 자체를 관리 대상으로 포함)
          mkdir -p ansible/playbooks # playbooks 디렉토리도 함께 생성
          cat <<EOF > ansible/inventory.ini
          [ec2_instances]
          # 호스트 이름은 '서버'가 되며, 실제 접속할 IP는 ansible_host로 지정합니다.
          # ansible_user는 SSH 접속 사용자입니다.
          서버 ansible_host=${{ env.EC2_IP }} ansible_user=ubuntu
          EOF

          echo "Ansible Inventory created:"
          cat ansible/inventory.ini
          echo "---"

          # Ansible 플레이북 파일 생성 (Nginx 설치 부분은 삭제하고 연결 확인만 수행)
          # 사용자님의 실제 플레이북 경로로 변경해야 합니다.
          # 예를 들어, 플레이북이 저장소의 'ansible/playbooks/my_backup_playbook.yml'에 있다고 가정
          ANSIBLE_PLAYBOOK_PATH="./ansible/playbooks/connectivity_check_playbook.yml" # 예시 경로: 연결 확인용 플레이북

          # 이 시점에는 실제 AWS 작업을 수행하는 플레이북을 연결할 수 있습니다.
          # 예시: connectivity_check_playbook.yml 내용을 직접 여기에 정의합니다.
          cat <<EOF > "$ANSIBLE_PLAYBOOK_PATH"
          ---
          - name: EC2 인스턴스 연결 확인 플레이북 (러너에서 실행)
            hosts: ec2_instances
            become: true # 필요시 root 권한 사용
            tasks:
              - name: EC2 인스턴스 Ping 테스트 (러너 -> EC2)
                ansible.builtin.ping:
                # 이 플레이북은 EC2 인스턴스가 Ansible 연결에 준비되었는지 확인합니다.
                # Nginx 설치와 같은 초기 설정은 이제 이 플레이북에서 하지 않습니다.
          EOF

          # 플레이북 파일이 존재하는지 확인 (선택 사항이지만 좋은 습관)
          if [ -f "$ANSIBLE_PLAYBOOK_PATH" ]; then
            echo "Running Ansible Playbook: $ANSIBLE_PLAYBOOK_PATH"
            ansible-playbook -i ansible/inventory.ini "$ANSIBLE_PLAYBOOK_PATH"
          else
            echo "::error::Ansible playbook not found at $ANSIBLE_PLAYBOOK_PATH"
            exit 1
          fi
