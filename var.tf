variable "project_id" {
  description = "The ID of the project in which the resource belongs."
  type        = string
  default     = "kinetic-primer-305209"
}

variable "region" {
  description = "The region in which the resource belongs."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone in which the resource belongs."
  type        = string
  default     = "us-central1-a"
}