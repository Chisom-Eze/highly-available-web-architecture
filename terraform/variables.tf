variable "region" {
  description = "us-east-1"
  type        = string
  default     = "us-east-1"
}


variable "key_name" {
  description = "Cloud-Ops"
  type        = string
}

variable "instance_type" {
  description = "t2.micro"
  type        = string
  default     = "t2.micro"
}

variable "vpc_cidr" {
  description = "10.0.0.0/16"
  type        = string
  default     = "10.0.0.0/16"
}


variable "public_subnet_1_cidr" {
  description = "10.0.1.0/24"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "10.0.2.0/24"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "10.0.3.0/24"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  description = "10.0.4.0/24"
  type        = string
  default     = "10.0.4.0/24"
}