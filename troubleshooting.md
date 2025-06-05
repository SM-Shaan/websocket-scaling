1. permission issue. The AWS user doesn't have permission to create the service-linked role for Elastic Load Balancing. Let's fix this by creating the service-linked role first:

aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com

2.  let's find the correct AMI ID for Amazon Linux 2023 in ap-southeast-1 (Singapore) region:
```bash
aws ec2 describe-images --region ap-southeast-1 --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text
```


3. while making sure no other process is using port 8000:
```bash
netstat -ano | findstr :8000
```

????????
1. Infrastructure:
VPC with public and private subnets
NAT Gateway for private subnet internet access
ALB in public subnet for external access