variable "public_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    public_ip         = optional(bool, true)
    tags              = optional(map(string), {}) # Makes an attribute optional with a default
  }))
  description = "Subnets map of objects variable"
}

variable "private_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    public_ip         = optional(bool, false)
    tags              = optional(map(string), {}) # Makes an attribute optional with a default
  }))
  description = "Subnets map of objects variable"
}

variable "cidr_block" {
  type = string
  description = "VPC CIDR Range"

}

variable "hosting_domain" {
  type = string
  description = "Domain used for the load balancer"
}