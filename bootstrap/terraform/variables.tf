variable "resource_group" {
  description = "Nom du Resource Group Azure contenant le DevTestLab"
  type        = string
}

variable "lab_name" {
  description = "Nom du DevTestLab existant"
  type        = string
}

variable "vm_name" {
  description = "Nom de la VM à créer dans le lab"
  type        = string
  default     = "kubequest-vm"
}

variable "vm_size" {
  description = "Taille de la VM Azure"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_username" {
  description = "Utilisateur admin de la VM"
  type        = string
  default     = "kubequest"
}

variable "vm_password" {
  description = "Mot de passe admin (à passer via -var ou TF_VAR_vm_password)"
  type        = string
  sensitive   = true
}

variable "lab_virtual_network_id" {
  description = "ID du VNet du DevTestLab"
  type        = string
}

variable "lab_subnet_name" {
  description = "Nom du subnet dans le VNet du lab"
  type        = string
}
