variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "hash_key" {
  description = "The primary hash key name"
  type        = string
  default     = "email"
}

variable "hash_key_type" {
  description = "The data type of the hash key"
  type        = string
  default     = "S"
}

variable "attributes" {
  description = "Array of additional attributes (each as an object with name and type) to define in the table. Type should be S, N, or B."
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "ttl_attribute_name" {
  description = "The name of the TTL attribute"
  type        = string
  default     = "ttl"
}
