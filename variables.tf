# variables.tf
variable "vm_config_path" {
  description = "Path to the JSON configuration file"
  type        = string
  default     = "azure_vm_config.json"
}
