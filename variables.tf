variable "location" {
  type        = string
  default     = "eastus2"
  description = "Location where the resoruces are going to be created."
}

variable "suffix" {
  type        = string
  default     = "bts"
  description = "To be added at the beginning of each resource."
}

variable "rgName" {
  type        = string
  default     = "SingleNodeRG"
  description = "Resource Group Name."
}

variable "tags" {
  type = map
  default = {
    "Environment" = "Dev"
    "Project"     = "BTS-SWIM"
    "BillingCode" = "Internal"
    "Customer"    = "DOT"
  }
}

## Networking variables
variable "routeTableName" {
  type        = string
  default     = "Main"
  description = "Route table name."
}

variable "vnetName" {
  type        = string
  default     = "Main"
  description = "VNet name."
}

locals {
  base_cidr_block = "10.60.0.0/16"
}

variable "baseCIDRBlock" {
  type        = list
  default     = ["10.60.0.0/16"]
  description = "Main VNet CIDR value range."
}


variable "subnets" {
  type = map
  default = {
    "workers"    = "1"
    "zookeeper"  = "2"
    "headnodes"  = "3"
    "management" = "4"
  }
  description = "Subnets to be created in the VNet"
}

variable "dataBricksSubnets" {
  type = map
  default = {
    "publicDB"  = "5"
    "privateDB" = "6"
  }
  description = " DataBricks dedicated subnets for VNet injection."
}

## Security variables
variable "sgName" {
  type        = string
  default     = "default_RDPSSH_SG"
  description = "Default Security Group Name to be applied by default to VMs and subnets."
}

variable "sourceIPs" {
  type        = list
  default     = ["173.66.39.236", "152.120.199.10", "167.220.148.25"]
  description = "Public IPs to allow inboud communications."
}

variable "workspaceName" {
  type        = string
  default     = "DatabricksWokspaceSingleNode"
  description = "DataBricks Workspace name."
}
