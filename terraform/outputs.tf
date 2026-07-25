output "k8s_host_data" {
    value = {
        for name, vm in proxmox_virtual_environment_vm.k8s_node :
        name => {
            ip = split("/", vm.initialization[0].ip_config[0].ipv4[0].address)[0]
            role = local.k8s_nodes[name].role
        }
    } 
}