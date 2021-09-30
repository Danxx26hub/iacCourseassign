variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "westus"
}

variable "username" {
  description = "The username of the machine"
}

variable "password" {
  description = "the password to use"
  sensitive   = true
}

variable "machines" {
  type        = number
  description = "how many virtual machines would you like to build? (please select at least 2 but no more than 5)"

  validation {
    condition = var.machines > 2 && var.machines <= 5
    error_message = "You must select at least 2 VM's but no more than 5 VM's!"
  }

}

variable "size" {
  description = "the size, to conform with my Azure policy Standar_b1s only"
  type        = string
  default     = "Standard_B1s"
}
