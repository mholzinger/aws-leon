# aws-leon
AWS Resource Cleanup Script. The Cleaner. A Professional. 

# AWS Resource Cleanup Tool

A comprehensive script for cleaning up AWS resources after Terraform deployments.

## Overview

This tool helps identify and clean up AWS resources that might remain after incomplete or failed Terraform operations. It systematically discovers and removes resources in the correct order, handling dependencies properly.

## Features

- Automatic resource discovery across multiple AWS services
- Proper dependency handling for resource deletion
- Cross-region support
- Detailed logging of actions
- Focus on EKS and related infrastructure
- Safe operation - preserves default resources

## Installation

1. Download the script:

```bash
curl -O https://raw.githubusercontent.com/yourusername/aws-cleanup/main/aws_cleanup.sh
```

2. Make it executable:

```bash
chmod +x aws_cleanup.sh
```

## Usage

Run the script for a specific region:

```bash
./aws_cleanup.sh us-east-1
```

To clean up multiple regions:

```bash
./aws_cleanup.sh us-east-1
./aws_cleanup.sh us-west-2
```

## Resources Cleaned

The script identifies and removes:

- EKS clusters
- Load Balancers (Classic, Application, Network)
- NAT Gateways
- Elastic IPs
- Security Groups
- CloudWatch Log Groups related to EKS
- KMS Keys with EKS/Terraform tags
- Non-default VPCs and dependencies (Internet Gateways, Subnets, Route Tables)
- IAM OIDC Providers related to EKS

## When to Use

- After running \`terraform destroy\` to catch orphaned resources
- When cleaning up after failed Terraform operations
- As a regular maintenance task to prevent unnecessary costs

## Prerequisites

- AWS CLI installed and configured
- Appropriate IAM permissions to delete resources

## Sample Output

```
Running cleanup in region: us-east-1
Starting AWS resource cleanup...

Checking for EKS clusters...
No EKS clusters found.

Checking for Classic Load Balancers...
No Classic Load Balancers found.

Checking for Application/Network Load Balancers...
No ALB/NLB Load Balancers found.

Checking for NAT Gateways...
Found NAT Gateways: nat-0e6c2821ceefa066e
Deleting NAT Gateway: nat-0e6c2821ceefa066e
NAT Gateway deletion initiated. This process can take several minutes.

Checking for unattached Elastic IPs...
Found unattached Elastic IPs: eipalloc-099322379ebc37103
Releasing Elastic IP: eipalloc-099322379ebc37103

Checking for non-default security groups...
Found security groups: sg-07272d647972cc9f1 sg-0fa031622800f1b54
Removing rules from security group: sg-07272d647972cc9f1
Revoking inbound rules
Revoking outbound rules
Removing rules from security group: sg-0fa031622800f1b54
Revoking inbound rules
Deleting security group: sg-07272d647972cc9f1
Deleting security group: sg-0fa031622800f1b54

Checking for EKS CloudWatch Log Groups...
Found EKS Log Groups: /aws/eks/eks-gitops-VAQNozne/cluster
Deleting Log Group: /aws/eks/eks-gitops-VAQNozne/cluster

Checking for EKS/Terraform related KMS keys...
Scheduling deletion for KMS key: dceacfc2-3ae4-4dd3-86ac-6accc41340e6
Scheduling deletion for KMS key: 88ab9df9-443d-4760-b48a-433b197c79a5

Checking for non-default VPCs...
Found non-default VPCs: vpc-00dfb47ac71e9ad7c vpc-01d5f111d37b74188
Processing VPC: vpc-00dfb47ac71e9ad7c
Detaching and deleting Internet Gateway: igw-036ff0fb709620640
Deleting Subnet: subnet-085cf202bb6aa9eb0
Deleting Subnet: subnet-031e842b2a7d0f0c5
Deleting Subnet: subnet-05d219694cb43a8bc
Deleting Route Table: rtb-0a984bf0584d741bf
Deleting Route Table: rtb-040d0f61a4a8c34e6
Deleting VPC: vpc-00dfb47ac71e9ad7c

Checking for EKS OIDC providers...
Deleting EKS OIDC provider: arn:aws:iam::783764573580:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/584D78400EFAEB86416B3993BFEDEB74

Cleanup completed in region us-east-1
```

## Customization

The script can be modified to target additional resource types or to be more selective about which resources to delete. Open the script and edit the relevant sections as needed.

## Warning

This script will delete resources permanently. Always ensure you have appropriate backups and that you understand which resources will be affected before running it.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


<pre style="font-family: monospace; line-height: 1; white-space: pre;">

```text
              .00OOOO0000000000000000000KKKKKK0'            .,;',',..
   ....       .OOOOOOOOOO000000000000000KK00KK0'           ..',;,','.          .
              .0OOOOOOOOO00000000000000KKKKK00K;    .................. .......''
  ;ddddd.     .0OOO000000000KKKKKKKKKKKKKKKKxlK:.....                       . ..
  dWWWWN'     .0OO000000000KKKKKKKKKKKKKKKKO;;d;.       .',;:cc:;,...
  dWWWWN'     .0O000000000KKKKKKXXXXXXXXXXKd'.    .':ok0KK0OOOOOkxdolcc:;,'....
  dWWWWN'     .OO00000KKKKKKKKKKXXXXXXXXX0c.   .:dkO0KK00kxxkOKK0K00Odollllccc:;
  dWWWWWNNNNNd d0KKKKKKKKKKXXXXXXXXXXXXKc.  .,dkOOOKK0kdddxkkK0ooKNNX0d;;l;,;;;;
  ckkkkkkOOkkc d0KKKKKKXXXXXXXXXXXXXXKKk,..,lkOOO0KOl:oo:,;xKkc:ckXXOdkxkd;.',''
               dKXXXXXXXXXXXXXXXKkdllldk0X0kxOKXNKk;;x;.':OXl,'.',:;ldoodlc;''',
              .oKXXXXXXXXXXXXXkc,.cdxk0XNNNX0O00Oxc'l'.'dK0;...    .cl'.,',;;:;;
      .,l:...  :kKXXXXNNNNNXO;....;lxO00Okdl:::::d' . .':;..       .,,. ...'',;;
  oNNNWWWWNNNd ,dOXXNNNNXXKd. .:xKXKOkdlc:::;,,,':l.           .'..........;c:;;
  oWWWWXooooo, 'lkXNNNNXK0x..lk0K0xolc::;,'.',;:::do'.....'',;;,......''''',:::;
  dWWWWWXXXXX, 'lxXNNNNNXKx..:;;;'.........,,,';;::cc:;:;:c:;,''.''''''''',;:ccc
  dWWWWXooooo' 'lxXXNNNNNXXx,......     ...,;;;,';:ldxol::cc:;;;;,,,;;;;;::::;;;
  xWWWWWWWWWWk .coKNNNNNK0XKo:::'...       ......,odO0KK00Odolllccccc:::;;,,''''
  ,cccccccccc, .,c0NNNNNOx0Nl.......       ......:kKXXXKKKK0Okkxkxxdolcc:;,,'''.
                .;OXNNNNkdk0;  .,...       ...',cx0KXXXK0K0kddooollcc:;;,,''....
                 ,kONNNXo;o:. .,.....      ..,:ldxkO0XXK0Okddolcc:;;,,,''.......
   .,coddo:'    .'kkXNNK:cd. .'.;:ccc;,'.......',;:ldkkOkxxolc::;;;,''..........
 .xNWWWWWWWWKc ...odKNKk::l.''':;''................,';ccllloo::;;,''..''........
.0WWWXc;:0WWWWl ...:oKk;..,',,;',;::ccc:;,'............',:::;;,'''''''.''''...'.
.NWWWO.  oWWWWx.....;Od....,.,ldooollcc:::::;;;''.... .....,,;..,'....'''''.....
 cNWWWNKXWWWW0.    ..ol.  .'.;:'.........',,:ccc::;'.....'.,,'........''..'....
  .cx0XNXKOd,       .,..  ...c:,''..'',ccllcllccc:;:;'...''.'...................
                     .     .;oddoxkkkO00OOkddolc:::;,........................
                          ..,lodddk0KK0OO0O0Odlclcc;;,........... ....
  ....   ....             ..';clcldokddoclolllc::,.,,,'.............
  kWWNo. OWWWl            ..',:;;:;coooc:;:;';c,...,,''.......                .
  kWWWWK;0MMMl            ...''''''':;,........'..'.'......                   .
  kWWWWWWWMMMl           .. .............  ..  .. .. .
  kWWWONMMMMMl              . .  ... ..
  kWWW'.kWMMMl     ......  .. ... '.'  ....,.  .. .. ..   .' .. .. .. ....'.
  ;ccc.  ,lll'     .. .'.  .  ... .'.  ....,.  .. .. ..   .' .. .. .' ....'.
                   .......... ............. .................  ............   .
                     .............. ...........'... ............       ....   .
                   ..... .....    .      ............            .....  ...   .
                                            .......               ...
```
</pre>
