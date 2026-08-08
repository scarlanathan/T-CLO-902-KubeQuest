output "vm_id" {
  value       = azurerm_dev_test_linux_virtual_machine.kubequest_vm.id
  description = "ID de la VM créée dans le DevTestLab"
}

output "vm_fqdn" {
  value       = azurerm_dev_test_linux_virtual_machine.kubequest_vm.fqdn
  description = "FQDN de la VM (SSH kubequest@<fqdn>)"
}
