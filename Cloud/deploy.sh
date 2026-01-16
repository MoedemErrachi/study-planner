aws cloudformation deploy --template-file 01-network.yaml --stack-name network
aws cloudformation deploy --template-file 02-security.yaml --stack-name security
aws ec2 create-key-pair --key-name my-key --query 'KeyMaterial' --output text > my-key.pem
chmod 400 my-key.pem
aws cloudformation deploy --template-file 03-bastion.yaml --stack-name bastion
aws cloudformation deploy --template-file 04-alb.yaml --stack-name alb
aws cloudformation deploy --template-file 07-rds.yaml --stack-name rds

aws cloudformation deploy --template-file 05-frontend-asg.yaml --stack-name frontend-asg 
aws cloudformation deploy --template-file 06-backend-asg.yaml --stack-name backend-asg 

aws cloudformation deploy --template-file 08-s3.yaml --stack-name s3

aws cloudformation deploy --template-file 09-ecs-migration.yaml --stack-name ecs 

aws cloudformation deploy --template-file 10-ec2-backend.yaml --stack-name ec2-backend

aws cloudformation delete-stack --stack-name <bastion>