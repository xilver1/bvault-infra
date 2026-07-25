data "aws_ssm_parameter" "ci-ssh-public-key" {
  name = "/lab/ci/ssh-public-key"
}

locals {
  k8s_nodes = {
    "k8s-cp-1" = { octet = 193, cores = 2, memory = 4096, role = "control" }
    "k8s-w-1" = { octet = 194, cores = 2, memory = 4096, role = "worker" }
    "k8s-w-2" = { octet = 195, cores = 2, memory = 4096, role = "worker" }
  }
}

resource "proxmox_virtual_environment_vm" "k8_node" {
  for_each = local.k8s_nodes
  name      = each.key
  node_name = "pve"

  # should be true if qemu agent is not installed / enabled on the VM
  stop_on_destroy = true

  cpu { cores = each.value.cores }
  memory { dedicated = each.value.memory }

  initialization {
    # uncomment and specify the datastore for cloud-init disk if default `local-lvm` is not available
    # datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "${cidrhost("192.168.0.0/24", each.value.octet)}/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      username = "k8s"
      keys     = [trimspace(data.aws_ssm_parameter.ci-ssh-public-key.value)]
    }
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  network_device {
    bridge = "vmbr0"
  }
}

resource "proxmox_download_file" "debian_13_genericcloud_amd64" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud.debian.org/images/cloud/trixie/20250806-2196/debian-13-genericcloud-amd64-20250806-2196.qcow2"
}