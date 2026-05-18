variable "region" { default = "us-east-1" }
variable "bucket_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "env_file_path" {
  type        = string
  description = "Path to generate the .env file"
  default     = "./.env" 
}