variable "environment" {
    type = string
    description = "Name of the environment to deploy (devel or stage)"
}

variable "resource_name_prefix" {
    type = string
    description = "Name prefix for the resources that will be created by the module"
}