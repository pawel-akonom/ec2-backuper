#!/bin/bash

DEBUG_MODE=false
DATE=$(date +'%Y-%m-%d')

# no arguments needed
function usage()
{
	echo -e "\n$(basename $0): script for ec2 instance backup as AMI\n"
	echo -e "usage:\n$(basename $0) [-n <instance name>] [-b <number of backups>] [-p <aws profile>] [-d] [-h]"
	echo -e "-n\tinstance name to backup"
	echo -e "-b\tnumber of backups to keep"
	echo -e "-p\taws-cli profile - specify if it's different than default"
	echo -e "-d\tbash debug mode enabled"
	echo -e "-h\thelp"
}

while getopts :n:b:p:dh OPTION;
do
   case ${OPTION} in
      n) INSTANCE_NAME=${OPTARG} ;;
      b) NUMBER_OF_BACKUPS=${OPTARG} ;;
      p) AWS_PROFILE=${OPTARG} ;;
      d) DEBUG_MODE=true ;;
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

if [ $DEBUG_MODE = true ] ; then
	set -x
fi

which aws &> /dev/null
if [ $? -ne 0 ] ; then
	echo "aws-cli is not installed" 1>&2
	exit 1
fi

WS_EC2_TEST=$(aws ec2 describe-vpcs 2>&1)
if [ $? -ne 0 ] ; then
	AWS_EC2_TEST=$(echo "$AWS_EC2_TEST" | tr -d '\n')
	echo -e "Can't Get information from AWS:\n$AWS_EC2_TEST" 1>&2
fi

# function takes instance name as an argument
# function return instance id
function get_instance_id()
{
	aws ec2 describe-instances --filter "Name=tag:Name,Values=$1" --query 'Reservations[*].Instances[*].InstanceId' | tr -d '"' | egrep [[:alnum:]] | sed -e 's/[[:space:]]*//'
}

INSTANCE_ID=$(get_instance_id $INSTANCE_NAME)
echo $INSTANCE_ID
