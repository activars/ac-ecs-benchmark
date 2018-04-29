# ac-ecs-benchmark

Deployment and repository configuration for alicloud using Terraform:

  - This creates or teardown VPC, VSwitch, Security Groups, Server Load Balancer, Firewall rules
  - Terraform state is maintained in a remote AWS S3 bucket (configured in CircleCI).
  - CI/CD environment configuration is defined .circleci/config.yml
  - CloudInit user data is templated for bootstraping. If you have a subscription account or unlocked privilages, it's psossible to configure autoscaling.
  - The auto-scaling example is commented out.
  - There are some limitations. For example, database has to be manually created (using master account doesn't seem to work. Error message for failed operation is logged in error.log file
  
