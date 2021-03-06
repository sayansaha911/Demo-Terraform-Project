############ GLOBAL ###################

variable "vpc_id" {
  description = "The Prefix used for all resources in this example"
  type = string
}

variable "public_subnet_ids" {
  description = "VPC public subnet ids"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name for the EKS cluster"
  type = string
}

##################################################################

variable "public_anywhere" {
  description = "Public access"
  default     = "0.0.0.0/0"
}

variable "asg_name" {
  description = "Name of the autoscaling group"
  default = ""
}

variable "eks_node_sg_id" {
  description = "cluster sg id"
  default = ""
}