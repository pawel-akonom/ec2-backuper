#!/bin/bash

DEBUG_MODE=false
DATE=$(date +'%Y-%m-%d')
AWS_ARG=""

# no arguments needed
function usage()
{
	echo -e "\n$(basename $0): script for ec2 instance backup as AMI\n"
	echo -e "usage:\n$(basename $0) [-n <instance name>] [-b <number of backups>] [-p <aws profile>] [-d <AMI description>] [-h]"
	echo -e "-n\tinstance name to backup"
	echo -e "-b\tnumber of backups to keep"
	echo -e "-p\taws-cli profile - specify if it's different than default"
	echo -e "-d\tAMI description"
	echo -e "-h\thelp"
}

while getopts :n:b:p:d:h OPTION;
do
   case ${OPTION} in
      n) INSTANCE_NAME=${OPTARG} ;;
      b) NUMBER_OF_BACKUPS=${OPTARG} ;;
      p) AWS_PROFILE="${OPTARG}" ;;
      d) AMI_DESCRIPTION=${OPTARG} ;;
      h) usage ; exit 0;;
      :) echo "Option -${OPTARG} requires an argument"; usage ; exit 1;;
      \?) echo "Invalid option: -${OPTARG}"; usage ; exit 1;;
   esac
done

if [ -z $INSTANCE_NAME ] ; then
	echo "instance name is mandatory"
	exit 1
	usage
fi

if [ -z $NUMBER_OF_BACKUPS ] ; then
	echo "number of backups is mandatory"
	exit 1
	usage
fi

if ! [ -z $AWS_PROFILE ]; then
	AWS_ARG="--profile $AWS_PROFILE"
fi

which aws &> /dev/null
if [ $? -ne 0 ] ; then
	echo "aws-cli is not installed" 1>&2
	exit 2
fi

WS_EC2_TEST=$(aws ec2 describe-vpcs 2>&1)
if [ $? -ne 0 ] ; then
	AWS_EC2_TEST=$(echo "$AWS_EC2_TEST" | tr -d '\n')
	echo -e "Can't Get information from AWS:\n$AWS_EC2_TEST" 1>&2
	exit 2
fi

# function takes instance name as an argument
# function return instance id
function get_instance_id()
{
	aws $AWS_ARG ec2 describe-instances --filter "Name=tag:Name,Values=$1" --query 'Reservations[*].Instances[*].InstanceId' | tr -d '"' | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//'
}

# function take instance id as an agrument
# function return AMI id
function create_ami_from_instance()
{
	if ! [ -z "$AMI_DESCRIPTION" ]; then
		aws $AWS_ARG ec2 create-image --instance-id "$1" --name "$INSTANCE_NAME"-"$DATE" --description "$AMI_DESCRIPTION" | tr -d '"'  | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//' | awk '{print $2}'
	else
		aws $AWS_ARG ec2 create-image --instance-id "$1" --name "$INSTANCE_NAME"-"$DATE" | tr -d '"'  | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//' | awk '{print $2}'
	fi
}

# function take ami id as an argument
# function return all ebs snapshots from AMI
function get_snapshots_id_from_ami()
{
	aws $AWS_ARG ec2 describe-images --filter "Name=image-id,Values=$1" --query Images[*].BlockDeviceMappings[*].Ebs.SnapshotId | tr -d '"' | tr -d ',' | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//'
}

# no arguments needed
# function list all instance AMIs
function get_all_ami_names()
{
	aws $AWS_ARG ec2 describe-images --filter "Name=name,Values=$INSTANCE_NAME*" --query Images[*].Name | tr -d '"' | tr -d ',' | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//' | sort
}

# function take ami name as an argument
# function return ami id
function get_ami_id()
{
	aws ec2 describe-images --filter "Name=name,Values=$1" --query Images[*].ImageId  | tr -d '"' | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//'
}

INSTANCE_ID=$(get_instance_id $INSTANCE_NAME)

AMI_ID=$(create_ami_from_instance $INSTANCE_ID)

SNAPSHOTS_IDS=$(get_snapshots_id_from_ami $AMI_ID)

# create Name tags for new ebs snapshots
for SNAP_ID in $SNAPSHOTS_IDS; do
	aws ec2 create-tags --resources $SNAP_ID --tags Key=Name,Value="$INSTANCE_NAME"-"$DATE"' '"$AMI_DESCRIPTION"
done

ALL_BACKUP_AMI_NAMES=$(get_all_ami_names)

NUMBER_OF_AMIS=$(echo $ALL_BACKUP_AMI_NAMES | wc -w)
NUMBER_OF_BACKUPS_TO_DELETE=$((NUMBER_OF_AMIS-NUMBER_OF_BACKUPS))

if [ $NUMBER_OF_BACKUPS_TO_DELETE -gt 0 ] ; then
	ALL_AMI_NAMES_TO_DELETE=$(echo $ALL_BACKUP_AMI_NAMES | tr ' ' '\n' | sed -n "1,$NUMBER_OF_BACKUPS_TO_DELETE"p)
	for AMI_NAME_TO_DELETE in $ALL_AMI_NAMES_TO_DELETE; do
		AMI_ID_TO_DELETE=$(get_ami_id $AMI_NAME_TO_DELETE)
		echo "aws $AWS_ARG ec2 deregister-image --image-id $AMI_ID_TO_DELETE"
		ALL_SNAPSHOTS_IDS_TO_DELETE=$(get_snapshots_id_from_ami $AMI_ID_TO_DELETE)
		for SNAP_ID_TO_DEL in $ALL_SNAPSHOTS_IDS_TO_DELETE; do
			echo "aws $AWS_ARG ec2 delete-snapshot --snapshot-id $SNAP_ID_TO_DEL"
		done
	done
fi

