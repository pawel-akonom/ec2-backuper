#!/bin/bash

DEBUG_MODE=false

# no arguments needed
function usage()
{
	echo -e "$(basename $0): script for ec2 instance backup as AMI\n"
	echo -e "usage:\n$(basename $0) [-i <instance name>] [-n <number of backups>] [-d] [-h]"
	echo -e "-i\tinstance name to backup"
	echo -e "-n\tnumber of backups to keep"
	echo -e "-d\tbash debug mode enabled"
	echo -e "-h\thelp"
}

while getopts :i:n:dh OPTION;
do
   case ${OPTION} in
      i) INSTANCE_NAME=${OPTARG} ;;
      n) NUMBER_OF_BACKUPS=${OPTARG} ;;
      d) DEBUG_MODE=true ;;
      h) usage ; exit 0;;
      :) echo "Option -${OPTARG} requires an argument"; usage ; exit 1;;
      \?) echo "Invalid option: -${OPTARG}"; usage ; exit 1;;
   esac
done

if [ $DEBUG_MODE = true ] ; then
	set -x
fi

aws --version &> /dev/null
if [ $? -ne 0 ] ; then
	echo "aws is not installed" 1>&2
	exit 1
fi

WS_EC2_TEST=$(aws ec2 describe-vpcs 2>&1)
if [ $? -ne 0 ] ; then
	AWS_EC2_TEST=$(echo "$AWS_EC2_TEST" | tr -d '\n')
	echo -e "Can't Get information from AWS:\n$AWS_EC2_TEST" 1>&2
fi

