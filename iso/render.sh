#!/usr/bin/env bash
#
# Preconditions:
# - Logged into aws CLI with appropriate permissions
#
# Parameters:
# - $1 : A string literal with value of either 'bastion' or 'compute'
# These are the values thats will be retrieved for each possible value of first parameter:
# bastion -> ($CI_SSH_PUBKEY, $ADMIN_SSH_PUBKEY, $ADMIN_PASSWORD_HASH, $TS_AUTHKEY)
# compute -> ($CI_SSH_PUBKEY, $ADMIN_SSH_PUBKEY, $ADMIN_PASSWORD_HASH)
#
# Example usage:
# TS_AUTHKEY=ts-xxxxxx ./render.sh bastion
# ./render.sh compute
#

set -euo pipefail

VARS='$ADMIN_PASSWORD_HASH $ADMIN_SSH_PUBKEY $CI_SSH_PUBKEY $TS_AUTHKEY'

validate_param() {
    case "$1" in
        bastion) ;;
        compute) ;;
        observability) ;;
        *) echo "Usage: $0 <bastion|compute|observability>" >&2; exit 1 ;;
    esac
}

export_ssm_params() {
    CI_SSH_PUBKEY=$(aws ssm get-parameter --name /lab/ci/ssh-public-key --query "Parameter.Value" --output text)
    export CI_SSH_PUBKEY
    ADMIN_SSH_PUBKEY=$(aws ssm get-parameter --name /lab/admin/admin-ssh-public-key --query "Parameter.Value" --output text)
    export ADMIN_SSH_PUBKEY
    ADMIN_PASSWORD_HASH=$(aws ssm get-parameter --name "/lab/$1/password-hash" --query "Parameter.Value" --with-decryption --output text)
    export ADMIN_PASSWORD_HASH
}

substitute_template_files() {
    local outs
    case "$1" in
        bastion)
            : "${TS_AUTHKEY:?Paste the auth key into the env before running}"
            envsubst "$VARS" < iso/bastion/preseed.cfg.tmpl > "iso/bastion/preseed.cfg"
            envsubst "$VARS" < iso/bastion/bootstrap.sh.tmpl > "iso/bastion/bootstrap.sh"
            outs="iso/bastion/preseed.cfg iso/bastion/bootstrap.sh"
            ;;
        observability)
            envsubst "$VARS" < iso/observability/preseed.cfg.tmpl > "iso/observability/preseed.cfg"
            envsubst "$VARS" < iso/observability/bootstrap.sh.tmpl > "iso/observability/bootstrap.sh"
            outs="iso/observability/preseed.cfg iso/observability/bootstrap.sh"
            ;;
        compute)
            envsubst "$VARS" < iso/compute/answer.toml.tmpl > "iso/compute/proxmox-auto-install-assistant-docker/secrets/pve-1/answer.toml"
            outs="iso/compute/answer.toml"
            ;;
    esac
}

validate_param "${1:-}"
export_ssm_params "$1"
substitute_template_files "$1"


