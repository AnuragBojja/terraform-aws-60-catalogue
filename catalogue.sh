#!/bin/bash
set -e

service_name=$1
env=$2
echo "started '$service_name'"
#dnf install ansible -y
# python3 -m pip install boto3 botocore
# /usr/bin/python3 -m pip install boto3 botocore

REPO_URL=https://github.com/AnuragBojja/terraform-anisble-roboshop.git
REPO_DIR=/opt/terraform/ansible
VENV_DIR=$REPO_DIR/ansible-venv
ANSIBLE_DIR=terraform-anisble-roboshop
LOG_DIR=/var/log/roboshoplogs
LOGFILE_NAME=${service_name}-boostrap.log
LOG_FILE=$LOG_DIR/$LOGFILE_NAME


mkdir -p "$REPO_DIR"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
touch "$LOG_DIR/ansible.log"

#installing Python 
dnf install python3 git -y &>> $LOG_FILE
echo "Complteted installing python3 and git"
# checking for venv dir 
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR" &>> $LOG_FILE
fi
echo "completed creating venv"

# installing ansible boto3 and botocore
source $VENV_DIR/bin/activate
pip install ansible boto3 botocore &>> $LOG_FILE
echo "Installing ansible boto3 botocore SUCCESS"
cd $REPO_DIR

#checking for git repo if not exiest clone if exiest pull
if [ -d "$ANSIBLE_DIR" ]; then 
    cd "$ANSIBLE_DIR"
    git pull &>> $LOG_FILE
    echo "pulled repo '$ANSIBLE_DIR'"
else
    git clone "$REPO_URL" &>> $LOG_FILE
    cd "$ANSIBLE_DIR"
    echo "cloned repo '$ANSIBLE_DIR'"
fi 
echo "Started ansible playbook"
echo "enviroment is '$env'"
$VENV_DIR/bin/ansible-playbook -e service_name=$service_name -e env=$env -e ansible_python_interpreter=$VENV_DIR/bin/python main.yaml

echo "comleted playbook"