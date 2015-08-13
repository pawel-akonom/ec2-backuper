About:
-----
ec2-backuper.sh is a tool for backup AWS EC2 instances as an AMI images.
Name of an EC2 instance to backup and number of backups kept for an EC2 instance need to be specified as an argument.
Additionaly aws profile can be set as a script argument - if it's different than default.
Description can be also specified as a script argument and it is used to name EBS snapshots associated with AMI.

Configuration:
-------------
To make daily EC2 instanstance backups with this tool you need to run script from crontab from another machine or EC2 instance.
Another method is to launch EC2 micro instance, upload the script, add it to /etc/rc.local (need to be run as user with
aws-cli configuration) then create AMI from this EC2 instance and schedule nightly running and stoping and EC2 instance from this AMI
using AWS OpsWorks service with Time-based Instances scheduler e.g. start at 2:00AM, do the backup and stop at 3:00 AM.
ec2-backuper.sh tool is using aws-cli for communication with AWS. if crontab for ec2-user will be set please configure
aws-cli for ec2-user with "aws configure" command from ec2-user. AWS Access key and secret key need to be specified and
default output format have to be set to "json". User for which AWS access and secrety keys will be used need to have following policy:

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:CreateImage",
                "ec2:DeregisterImage",
                "ec2:CreateTags"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}

Example:
-------
If you want to keep 7 EC2 instance nightly backups at 2:00am as an AMI and EC2 instance name is set to: CI-dev-tools.
- create user on AWS web console e.g. backuper
- attach needed policy for backuper user
- create access and secret keys for backuper user
- login to machine from which you will execute nightly backups
- install and configure aws-cli: set access key and secret key for user backuper and default output format to json
- create crontab entry:
0 2 * * * $HOME/ec2-backuper.sh -n CI-dev-tools -b 7 -d "CI-dev-tools backup via ec2-backuper" >> $HOME/ec2-backuper.log

Script will run at 2:00am, it will create new AMI CI-dev-tools-YYYY-MM-DD for CI-dev-tools instance, it will add 
"CI-dev-tools-YYYY-MM-DD CI-dev-tools backup via ec2-backuper" name to all EBS snapshots associated with CI-dev-tools-YYYY-MM-DD instance,
it will check number of AMI backups created for an EC2 instance and if it pass specified limit it will deregister the oldest
AMI and delete associated EBS snapshots to keep specified number of backups only - in this example 7.

Author:
------
Pawel Akonom
pawel.akonom(at)gmail.com
