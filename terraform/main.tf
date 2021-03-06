terraform {
  required_version = ">= 0.12.0"
}

resource "oci_identity_compartment" "this" {
  compartment_id = var.compartment_ocid
  description = "Micronaut HOL Compartment"
  name = "mn-oci-hol"
}

resource "oci_core_vcn" "this" {
  dns_label      = var.vcn_dns_label
  cidr_block     = var.vcn_cidr
  compartment_id = oci_identity_compartment.this.id
  display_name   = var.vcn_display_name
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = oci_identity_compartment.this.id
  vcn_id         = oci_core_vcn.this.id
}

resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_ocid
}

resource "oci_core_security_list" "this" {
  compartment_id = oci_identity_compartment.this.id
  vcn_id = oci_core_vcn.this.id
  ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0"
    description = "Allow port 8080"
    stateless = "false"
    tcp_options {
      max = "8080"
      min = "8080"
    }
  }
}

resource "oci_core_subnet" "subnet" {
  availability_domain = local.availability_domain[0]
  cidr_block          = cidrsubnet(var.vcn_cidr, ceil(log(length(data.oci_identity_availability_domains.this.availability_domains) * 2, 2)), 0)
  display_name        = "MN-OCI Demo Subnet"
  dns_label           = "${var.subnet_dns_label}1"
  compartment_id      = oci_identity_compartment.this.id
  vcn_id              = oci_core_vcn.this.id
  security_list_ids   = [
      oci_core_vcn.this.default_security_list_id,
      oci_core_security_list.this.id
  ]
}

data "oci_core_subnet" "this" {
  subnet_id = oci_core_subnet.subnet.id // the last AD should have the "always free" shapes...
}

data "oci_core_images" "this" {
  #Required
  compartment_id = oci_identity_compartment.this.id
  #Optional
  shape = local.availability_domain[0] != null ? "VM.Standard.E2.1.Micro" : "VM.Standard.E2.1"
  state = "AVAILABLE"
}

data "oci_limits_services" "services" {
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["compute"]
  }
}

data "oci_limits_limit_values" "ad_limits" {
  count          = length(data.oci_identity_availability_domains.this.availability_domains)
  compartment_id = var.tenancy_ocid
  service_name   = data.oci_limits_services.services.services.0.name
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[count.index].name
  name                = "vm-standard-e2-1-micro-count"
  scope_type          = "AD"
}

locals {
  availability_domain = [for limit in data.oci_limits_limit_values.ad_limits : limit.limit_values[0].availability_domain if limit.limit_values[0].value > 0]
}

resource "oci_core_instance" "this" {
  availability_domain  = local.availability_domain[0] != null ? local.availability_domain[0] : data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id       = oci_identity_compartment.this.id
  display_name         = var.instance_display_name
  shape                = var.shape

  create_vnic_details {
    assign_public_ip       = var.assign_public_ip
    display_name           = var.vnic_name
    subnet_id              = data.oci_core_subnet.this.id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = var.user_data
  }

  source_details {
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
    source_type = "image"
    source_id   = data.oci_core_images.this.images[0].id
  }

}

resource "random_string" "autonomous_database_admin_password" {
  length      = 16
  min_numeric = 1
  min_lower   = 1
  min_upper   = 1
  min_special = 1
  override_special = "_"
}

resource "random_string" "autonomous_database_schema_password" {
  length      = 16
  min_numeric = 1
  min_lower   = 1
  min_upper   = 1
  min_special = 1
  override_special = "_"
}

data "oci_database_autonomous_db_versions" "test_autonomous_db_versions" {
  #Required
  compartment_id = oci_identity_compartment.this.id

  #Optional
  db_workload = var.autonomous_database_db_workload
}

resource "oci_database_autonomous_database" "autonomous_database" {
  #Required
  admin_password           = random_string.autonomous_database_admin_password.result
  compartment_id           = oci_identity_compartment.this.id
  cpu_core_count           = "1"
  data_storage_size_in_tbs = "1"
  is_free_tier             = var.use_free_tier
  db_name                  = var.autonomous_database_db_name

  #Optional
  //db_version                                     = data.oci_database_autonomous_db_versions.test_autonomous_db_versions.autonomous_db_versions.0.version
  db_workload                                    = var.autonomous_database_db_workload
  display_name                                   = var.autonomous_database_display_name
  license_model                                  = var.autonomous_database_license_model
  is_preview_version_with_service_terms_accepted = "false"
}

data "oci_database_autonomous_databases" "autonomous_databases" {
  #Required
  compartment_id = oci_identity_compartment.this.id

  #Optional
  display_name = oci_database_autonomous_database.autonomous_database.display_name
  db_workload  = var.autonomous_database_db_workload
}

resource "random_string" "autonomous_database_wallet_password" {
  length  = 16
  min_numeric = 1
  min_lower   = 1
  min_upper   = 1
  min_special = 1
  override_special = "_"
}

data "oci_database_autonomous_database_wallet" "autonomous_database_wallet" {
  autonomous_database_id = oci_database_autonomous_database.autonomous_database.id
  password               = random_string.autonomous_database_wallet_password.result
  base64_encode_content  = "true"
}