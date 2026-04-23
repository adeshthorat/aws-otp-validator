variable "vpc_id" {
  type        = string
  description = "VPC ID where security groups will be created"
}

variable "prefix" {
  type        = string
  description = "Prefix for naming"
}

variable "security_groups" {
  type = map(object({
    description = optional(string, "Managed by Terraform")
    ingress_rules = optional(list(object({
      from_port                = number
      to_port                  = number
      protocol                 = string
      cidr_blocks              = optional(list(string), [])
      security_groups          = optional(list(string), [])
      source_security_group_key = optional(string, null)
      self                     = optional(bool, false)
      description              = optional(string, null)
    })), [])
    egress_rules = optional(list(object({
      from_port                = number
      to_port                  = number
      protocol                 = string
      cidr_blocks              = optional(list(string), ["0.0.0.0/0"])
      security_groups          = optional(list(string), [])
      source_security_group_key = optional(string, null)
      self                     = optional(bool, false)
      description              = optional(string, null)
    })), [{
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }])
    tags = optional(map(string), {})
  }))
  default     = {}
  description = "Map of security group configurations"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
