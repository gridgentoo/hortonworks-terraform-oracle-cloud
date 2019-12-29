variable "VPC-CIDR" {
  default = "10.0.0.0/16"
}

resource "oci_core_vcn" "hortonworks_vcn" {
  cidr_block     = "${var.VPC-CIDR}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "hortonworks_vcn"
  dns_label      = "hwvcn"
}

resource "oci_core_internet_gateway" "hortonworks_internet_gateway" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "hortonworks_internet_gateway"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"
}

resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"
  display_name   = "nat_gateway"
}

resource "oci_core_dhcp_options" "hortonworks_vcn_dhcp_options" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"
  display_name   = "hw_vcn_dhcp_options"

  options {
    type 	= "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
    }
}

data "oci_core_services" "hortonworks_services" {
}

resource "oci_core_service_gateway" "hortonworks_service_gateway" {
    compartment_id = "${var.compartment_ocid}"
    services {
      service_id = "${lookup(data.oci_core_services.all_svcs_moniker.services[0], "id")}"        
    }
    vcn_id = "${oci_core_vcn.hortonworks_vcn.id}"
    display_name = "Hortonworks Service Gateway"
}

resource "oci_core_route_table" "RouteForComplete" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"
  display_name   = "RouteTableForComplete"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "${oci_core_internet_gateway.hortonworks_internet_gateway.id}"
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"
  display_name   = "private"

  route_rules = [
    {
      destination       = "${var.oci_service_gateway}"
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = "${oci_core_service_gateway.hortonworks_service_gateway.id}"
    },
    {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = "${oci_core_nat_gateway.nat_gateway.id}"
    }
	
  ]
}

resource "oci_core_security_list" "PublicSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Public Subnet"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"

  egress_security_rules = [{
    destination = "0.0.0.0/0"
    protocol    = "6"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 8080
      "min" = 8080
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 8443
      "min" = 8443
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 9443
      "min" = 9443
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 19888
      "min" = 19888
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    protocol = "6"
    source   = "${var.VPC-CIDR}"
  }]

  egress_security_rules = [{
    protocol    = "6"
    destination = "${var.VPC-CIDR}"
  }]

  egress_security_rules = [{
    protocol    = "17"
    destination = "${var.VPC-CIDR}"
  }]

  ingress_security_rules = [{
    protocol = "17"
    source   = "${var.VPC-CIDR}"
  }]
}

resource "oci_core_security_list" "PrivateSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Private"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"

  egress_security_rules = [{
    destination = "0.0.0.0/0"
    protocol    = "6"
  }]

  egress_security_rules = [{
    protocol    = "6"
    destination = "${var.VPC-CIDR}"
  }]

  ingress_security_rules = [{
    protocol = "6"
    source   = "${var.VPC-CIDR}"
  }]

  egress_security_rules = [{
    protocol    = "17"
    destination = "${var.VPC-CIDR}"
  }]

  ingress_security_rules = [{
    protocol = "17"
    source   = "${var.VPC-CIDR}"
  }]
}

resource "oci_core_security_list" "BastionSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Bastion"
  vcn_id         = "${oci_core_vcn.hortonworks_vcn.id}"

  egress_security_rules = [{
    protocol    = "6"
    destination = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      protocol = "6"
      source   = "${var.VPC-CIDR}"
    },
  ]
}

resource "oci_core_subnet" "public" {
  count               = "3"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[count.index],"name")}"
  cidr_block          = "${cidrsubnet(var.VPC-CIDR, 8, count.index)}"
  display_name        = "public_${count.index+1}"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.hortonworks_vcn.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  security_list_ids   = ["${oci_core_security_list.PublicSubnet.id}"]
  dhcp_options_id     = "${oci_core_dhcp_options.hortonworks_vcn_dhcp_options.id}"
  dns_label           = "public${count.index+1}"
}

resource "oci_core_subnet" "private" {
  count               = "3"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[count.index],"name")}"
  cidr_block          = "${cidrsubnet(var.VPC-CIDR, 8, count.index+3)}"
  display_name        = "private_ad${count.index+1}"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.hortonworks_vcn.id}"
  route_table_id      = "${oci_core_route_table.private.id}"
  security_list_ids   = ["${oci_core_security_list.PrivateSubnet.id}"]
  dhcp_options_id     = "${oci_core_dhcp_options.hortonworks_vcn_dhcp_options.id}"
  prohibit_public_ip_on_vnic = "true"
  dns_label = "private${count.index+1}"
}

resource "oci_core_subnet" "bastion" {
  count               = "3"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[count.index],"name")}"
  cidr_block          = "${cidrsubnet(var.VPC-CIDR, 8, count.index+6)}"
  display_name        = "bastion_ad${count.index+1}"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.hortonworks_vcn.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  security_list_ids   = ["${oci_core_security_list.BastionSubnet.id}"]
  dhcp_options_id     = "${oci_core_dhcp_options.hortonworks_vcn_dhcp_options.id}"
  dns_label           = "bastion${count.index+1}"
}
