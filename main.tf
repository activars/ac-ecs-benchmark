terraform {
  backend "s3" {
    bucket = "ci-ops-terraform-state"
    key    = "terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "alicloud" {
  access_key = "${var.access_key_id}"
  secret_key = "${var.access_key_secret}"
  region     = "${var.region}"
  version    = "~> 1.9.0"
}

resource "alicloud_vpc" "default" {
  name        = "${var.solution_name}-vpc"
  description = "VPC for hosting ${var.solution_name} solution"
  cidr_block  = "10.0.0.0/16"
}

resource "alicloud_vswitch" "app" {
  vpc_id            = "${alicloud_vpc.default.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}${var.app_availability_zone}"
}

resource "alicloud_vswitch" "db" {
  vpc_id            = "${alicloud_vpc.default.id}"
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}${var.db_availability_zone}"
}

resource "alicloud_nat_gateway" "nat_gateway" {
  vpc_id = "${alicloud_vpc.default.id}"
  specification   = "Small"
  name   = "default_nat_gw"
}

# resource "alicloud_ess_scaling_group" "app" {
#   scaling_group_name = "scaling-group-app"
#   min_size           = "${var.app_instance_min_count}"
#   max_size           = "${var.app_instance_max_count}"

#   removal_policies   = ["OldestInstance", "NewestInstance"]
#   loadbalancer_ids   = ["${alicloud_slb.app.id}"]
#   db_instance_ids    = ["${alicloud_db_instance.default.id}"]
#   vswitch_ids        = ["${alicloud_vswitch.app.id}", "${alicloud_vswitch.db.id}"]
# }

# resource "alicloud_ess_scaling_configuration" "app" {
#   scaling_configuration_name = "scaling-configuration-app"
#   scaling_group_id           = "${alicloud_ess_scaling_group.app.id}"
#   instance_type              = "ecs.n4.small"
#   # cpu_core_count             = 1
#   # memory_size                = 2
#   system_disk_category       = "cloud_efficiency"
#   image_id                   = "${var.app_instance_image_id}"

#   security_group_id          = "${alicloud_security_group.app.id}"
#   active                     = true
# }

# resource "alicloud_ess_scaling_rule" "app" {
#   scaling_rule_name = "scaling-rule-app"
#   scaling_group_id  = "${alicloud_ess_scaling_group.app.id}"

#   adjustment_type   = "TotalCapacity"
#   adjustment_value  = 2
#   cooldown          = 60
# }

################################################################
data "template_file" "init_script" {
  template = "${file("scripts/init.cfg")}"
  vars {
    USERNAME = "${var.db_username}"
    PASSWORD = "${var.db_password}"
    HOSTNAME = "${alicloud_db_instance.default.connection_string}"
  }
}
# data "template_file" "shell-script" {
#   template = "${file("scripts/volumes.sh")}"
#   vars {
#     DEVICE = "${var.INSTANCE_DEVICE_NAME}"
#   }
# }
data "template_cloudinit_config" "cloudinit" {
  gzip = false
  base64_encode = false
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = "${data.template_file.init_script.rendered}"
  }
}
##################################################################

resource "alicloud_instance" "app" {
  count                      = "1"
  instance_name              = "${var.app_layer_name}"
  instance_type              = "${var.app_instance_type}"
  system_disk_category       = "cloud_efficiency"
  image_id                   = "${var.app_instance_image_id}"

  availability_zone          = "${var.region}${var.app_availability_zone}"
  vswitch_id                 = "${alicloud_vswitch.app.id}"
  internet_max_bandwidth_out = 10
  key_name                   = "default"
  security_groups            = ["${alicloud_security_group.app.id}"]
  user_data                  = "${data.template_cloudinit_config.cloudinit.rendered}"
}

resource "alicloud_slb" "app" {
  name        = "${var.app_layer_name}-slb"
  internet    = true
  internet_charge_type = "paybytraffic"
  vswitch_id = "${alicloud_vswitch.app.id}"
}

resource "alicloud_slb_listener" "http" {
  load_balancer_id = "${alicloud_slb.app.id}"
  backend_port = 3000
  frontend_port = 80
  bandwidth = 10
  protocol = "http"
  health_check_connect_port = 3000
  health_check_http_code = "http_2xx,http_3xx"
  sticky_session = "on"
  sticky_session_type = "insert"
  cookie = "testslblistenercookie"
  cookie_timeout = 86400
}

# resource "alicloud_slb_server_group" "group" {
#   load_balancer_id = "${alicloud_slb.app.id}"
#   servers = [
#     {
#       server_ids = ["${alicloud_instance.app.*.id}"]
#       port = 3000
#       weight = 100
#     }
#   ]
# }

resource "alicloud_slb_attachment" "default" {
  load_balancer_id    = "${alicloud_slb.app.id}"
  instance_ids = ["${alicloud_instance.app.*.id}"]
}

resource "alicloud_security_group" "app" {
  name   = "${var.app_layer_name}-sg"
  vpc_id = "${alicloud_vpc.default.id}"
}

resource "alicloud_security_group_rule" "allow_app_access" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "${var.app_instance_port}/${var.app_instance_port}"
  priority          = 1
  security_group_id = "${alicloud_security_group.app.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_app_external_ingress" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 2
  security_group_id = "${alicloud_security_group.app.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_app_external_egress" {
  type              = "egress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/443"
  priority          = 3
  security_group_id = "${alicloud_security_group.app.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_db_instance" "default" {
    engine = "${var.db_engine}"
    engine_version = "${var.db_engine_version}"
    instance_type = "${var.db_instance_type}"
    instance_storage = "${var.db_instance_storage}"

    vswitch_id = "${alicloud_vswitch.db.id}"
    security_ips = ["10.0.2.0/24"]
}

resource "alicloud_db_account" "master" {
    instance_id = "${alicloud_db_instance.default.id}"
    name = "${var.db_username}"
    password = "${var.db_password}"
    type = "Super"
}


