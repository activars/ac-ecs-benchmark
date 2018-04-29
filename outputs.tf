output "slb_app_public_ip" {
  value = "${alicloud_slb.app.address}"
}

output "alicloud_instance_app_public_ip" {
  value = "${alicloud_instance.app.public_ip}"
}
