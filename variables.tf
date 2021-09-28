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
  description = "how many virtual machines would you like to build? (please select at least 1)"


}

variable "size" {
  description = "the size, to conform with my Azure policy Standar_b1s only"
  type        = string
  default     = "Standard_B1s"
}
