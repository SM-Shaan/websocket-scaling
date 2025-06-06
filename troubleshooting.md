1. permission issue. The AWS user doesn't have permission to create the service-linked role for Elastic Load Balancing. Let's fix this by creating the service-linked role first:

aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com

2.  If the connection still fails, check the logs:
EC2 instance: /var/log/user-data.log
Docker container: docker logs websocket-app
Application logs: /home/ec2-user/logs/websocket_server.log


3. while making sure no other process is using port 8000:
```bash
netstat -ano | findstr :8000
```
4. generate and set up the SSH key pair:
```bash
cd terraform; ssh-keygen -t rsa -b 2048 -f websocket-key -N '""'
icacls websocket-key /inheritance:r /grant:r "$($env:USERNAME):(R,W)" # correct permissions for the private key
```
5. To install wscat:
```bash
sudo npm install -g wscat
```

????????
1. Infrastructure:
VPC with public and private subnets
NAT Gateway for private subnet internet access
ALB in public subnet for external access

