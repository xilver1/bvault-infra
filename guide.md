# Prerequisites

1. In tailscale, create tag:ci and tag:subnet-router, tagOwners (admin-general), OAuth client CI (write permission on auth_key), and OAuth Client for gitOps policy (write permission on policy). Afterwards, apply the tailscale/policy.hujson in the console JSON editor
2. Keys and secrets pre-generation:
    2.1. CI SSH keypair - This will be the keys used for the github runner to interact through ansible with each server. The public one will live in every server. The private one in AWS SSM as a SecureString parameter.
    2.2 Password hash for the admin account in bastion server. SSM Parameter store as a SecureString
    2.3. Bastion auth key. This auth key is used in the bootstrapping of the bastion server. It will serve to register the device within the tailnet network. Used once and then useless. Generate it locally and pass it locally
    2.4. Password hash for the answer.toml template for the setup of the compute server. It will be stored in AWS SSM as a SecureString parameter.
    2.5. Public key of root account (keypair generated locally on laptop) also on SSM parameter store as a String
    2.6. Client ID and client secret for both OAuth Clients in AWS SSM Parameter store, client_id as a String, client_secret as SecureString
3. Add OIDC provider in AWS account:
    URL: https://token.actions.githubusercontent.com
    Audience: sts.amazonaws.com
4. Create a role that will be used by github with the lab-infra-ci name. Use the trust policy and permissions policy as defined in aws folder.
5. Create an environment in github repository called tailscale-acl. This will be used by another role that we are going to create so that we can query the oauth client id and client secret parameters to enable gitOps pattern for tailscale and have proper separation of responsabilities for both roles
4. Shrink the ISP router's DHCP pool so the lab block is outside it.

# bastion

1. We retrieve through SSM the secrets necessary to fulfill the envsubst template that is the preseed configuration for the Debian image. We fill it out through envsubst. These are the 9 variables:
    GATEWAY_IP · HOSTNAME · DOMAIN · ADMIN_USER · ADMIN_PASSWORD_HASH · INSTALL_DISK · ADMIN_SSH_PUBKEY · CI_SSH_PUBKEY · TS_AUTHKEY
2. The netinst debian image is repacked with the final preseed file
3. I manually go and burn the image in an USB and run it in my physical host
4. The late_command stage of the preseed configuration executed the following upon install:
    4.1. Adds tailscale keyrings and installs tailscale
    4.2. Allows IPV4 forwarding and IPV6 all forwarding
    4.3. Writes injected admin_ssh and ci_ssh public keys to authorized_keys. Fixes permissions to ssh dirs.
    4.4. Writes an ssh hardened config to /etc/ssh/sshd_config.d
    4.5. Writes injected tailscale auth key to /target/etc/tailscale-bootstrap.key and fixes its permissions
    4.6. Writes a oneshot bootstrap service file for tailscale, which executes:
    `/usr/bin/tailscale up --authkey=file:/etc/tailscale-bootstrap.key --advertise-routes=192.168.0.190/31,192.168.0.192/26 --accept-dns=false --hostname={{ hostname }} --ssh=false`
    This uses the previously bootstrapped temporary tailscale key, advertises the network segment and basically registers this device to the tailnet.
    4.7 Destroy rendered artifacts

NOTE: Routes advertised are: .190–.255. Sixty-six addresses. 
NOTE 2: From here the bastion is in the CI inventory. Everything above this line is manual, once, by hand. Everything below it is automated.

# compute

4. The system reboot, and tailscale service is actually running

There's going to be a pipeline in Github Actions, which has answer.toml as a secret. It's going to follow the ISO preparation process and output an image into an S3 bucket.

The iamge is going to get pulled from the S3 bucket and manually burnt in an USB. The USB is going to be plugged into the computer and we got baseline OS for compute.

We have a terraform template

## Pipeline 1: "Build golden proxmox image"
This bootstraps the proxmox ISO with network config, authorized_keys, root password, and disk setup

1. Install proxmox-auto-install-assistant natively in github runner
2. Download latest proxmox ISO 
3. Execute `proxmox-auto-install-assistant prepare-iso /path/to/source.iso --fetch-from http --url "https://10.0.0.100/answer" --answer-auth-token "myhost:s3cr3t"`
5. Copy output ISO into an USB and boot

## Ansible setup for terraform
We need to setup API authentication in proxmox to allow for Terraform to interact with the API. Through SSH, ansible playbook will execute th following commands:
1. pveum user add terraform@pve
2. pveum role add Terraform -privs "Realm.AllocateUser, VM.PowerMgmt, VM.GuestAgent.Unrestricted, Sys.Console, Sys.Audit, Sys.AccessNetwork, VM.Config.Cloudinit, VM.Replicate, Pool.Allocate, SDN.Audit, Realm.Allocate, SDN.Use, Mapping.Modify, VM.Config.Memory, VM.GuestAgent.FileSystemMgmt, VM.Allocate, SDN.Allocate, VM.Console, VM.Clone, VM.Backup, Datastore.AllocateTemplate, VM.Snapshot, VM.Config.Network, Sys.Incoming, Sys.Modify, VM.Snapshot.Rollback, VM.Config.Disk, Datastore.Allocate, VM.Config.CPU, VM.Config.CDROM, Group.Allocate, Datastore.Audit, VM.Migrate, VM.GuestAgent.FileWrite, Mapping.Use, Datastore.AllocateSpace, Sys.Syslog, VM.Config.Options, Pool.Audit, User.Modify, VM.Config.HWType, VM.Audit, Sys.PowerMgmt, VM.GuestAgent.Audit, Mapping.Audit, VM.GuestAgent.FileRead, Permissions.Modify"
3. pveum aclmod / -user terraform@pve -role Terraform
4. pveum user token add terraform@pve provider --privsep=0
5. Concatenate the ID and token output by previous command in format: "user@realm!tokenid=secret". This will be the value of the api_token terraform variable


# media-server
