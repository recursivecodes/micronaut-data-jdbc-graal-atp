output "script_input" {
  atp_admin_password = random_string.autonomous_database_admin_password.result
  atp_schema_password = random_string.autonomous_database_schema_password.result
  atp_wallet_password = random_string.autonomous_database_wallet_password.result
  tns_name = "${oci_database_autonomous_database.autonomous_database.db_name}_high"
  atp_db_ocid = oci_database_autonomous_database.autonomous_database.id
  compartment_ocid = oci_core_instance.this.compartment_id
  region = var.region
}

output "public_ip" {
  description = "Public IPs of created instances. "
  value       = [oci_core_instance.this.public_ip]
}

output "atp_admin_password" {
  value = random_string.autonomous_database_admin_password.result
}

output "atp_schema_password" {
  value = random_string.autonomous_database_schema_password.result
}

output "atp_wallet_password" {
  value = random_string.autonomous_database_wallet_password.result
}

output "tns_name" {
  value = "${oci_database_autonomous_database.autonomous_database.db_name}_high"
}

output "atp_db_ocid" {
  value = oci_database_autonomous_database.autonomous_database.id
}

output "compartment_ocid" {
  value = oci_core_instance.this.compartment_id
}

output "region" {
  value = var.region
}