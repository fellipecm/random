### Linode vars
variable "linode_token" {
    type = string
    description = "Your Linode Terraform Token"
    sensitive = true
}

variable "region" {
    type = string
    description = "Region"
    default = "ap-southeast"
}