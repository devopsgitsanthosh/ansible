#!/bin/bash


LID=lt-032c3178e31f24c5c
LVER=1
#COMPONENT=$1

if [ -z "$1" ]; then
  echo "Component Name INput is needed"
  exit 1
fi

Instance_Create() {
  COMPONENT=$1
  INSTANCE_EXISTS=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${COMPONENT}  | jq .Reservations[])
  STATE=$(aws ec2 describe-instances     --filters Name=tag:Name,Values=${COMPONENT}  | jq .Reservations[].Instances[].State.Name | xargs)
  if [ -z "${INSTANCE_EXISTS}" -o "$STATE" == "terminated"  ]; then
    aws ec2 run-instances --launch-template LaunchTemplateId=${LID},Version=${LVER}  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}}, {Key=Project,Value=ROBOSHOP}]" | jq
  else
    echo "Instance ${COMPONENT} already exists"
  fi


  IPADDRESS=$(aws ec2 describe-instances     --filters Name=tag:Name,Values=${COMPONENT}   | jq .Reservations[].Instances[].PrivateIpAddress | grep -v null |xargs)

  sed -e "s/COMPONENT/${COMPONENT}/" -e "s/IPADDRESS/${IPADDRESS}/" record.json >/tmp/record.json
  aws route53 change-resource-record-sets --hosted-zone-id Z0449177GO3AQK4VZZ1H --change-batch file:///tmp/record.json
  sed -i -e "/${COMPONENT}/ d" ../inventory
  echo "${IPADDRESS} APP=$(echo ${COMPONENT} | awk -F - '{print $1}')" >>../inventory
}

if [ "$1" == "all" ]; then
  for instance in frontend mongodb catalogue redis user cart mysql shipping rabbitmq payment ; do
    Instance_Create $instance-dev
  done
else
  Instance_Create $1-dev
fi
