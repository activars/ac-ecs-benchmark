solution_name = "grafana"
region = "eu-central-1"
app_availability_zone = "eu-central-1"
app_layer_name = "grafana"
app_availability_zone = "a"
app_instance_min_count = 1
app_instance_max_count = 1
app_instance_type = "ecs.n4.small"

app_instance_port = 3000
app_lb_port = 80
app_instance_image_id = "ubuntu_16_0402_64_20G_alibase_20171227.vhd"


db_layer_name = "db"
db_availability_zone = "a"
db_engine = "MySQL"
db_engine_version = "5.6"
db_instance_type = "rds.mysql.s1.small"
db_instance_storage = 10

db_username = "master_account"
# configure in environment variable as TF_VAR_db_password
# db_password =  
app_instance_user_data = "touch ~/worked"