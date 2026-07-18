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

validate_param() {
    case "$1" in
        bastion) ;;
        compute) ;;
        *) echo "Usage: $0 <bastion|compute>" >&2; exit 1 ;;
    esac
}

export_ssm_params() {
    export CI_SSH_PUBKEY=$(aws ssm get-parameter --name /lab/ci/ssh-public-key --query "Parameter.Value" --output text)
    export ADMIN_SSH_PUBKEY=$(aws ssm get-parameter --name /lab/admin/admin-ssh-public-key --query "Parameter.Value" --output text)
    export ADMIN_PASSWORD_HASH=$(aws ssm get-parameter --name "/lab/$1/password-hash" --query "Parameter.Value" --with-decryption --output text)
}

substitute_template_files() {
    case "$1" in
        bastion)
            local out="bastion/preseed.cfg"
            : "${TS_AUTHKEY:?Paste the auth key into the env before running}"
            envsubst '$CI_SSH_PUBKEY $ADMIN_SSH_PUBKEY $ADMIN_PASSWORD_HASH $TS_AUTHKEY' < bastion/preseed.cfg.tmpl > "$out"
            ;;
        compute)
            local out="compute/answer.toml"
            envsubst '$CI_SSH_PUBKEY $ADMIN_SSH_PUBKEY $ADMIN_PASSWORD_HASH' < compute/answer.toml.tmpl > "$out"
            ;;
    esac

    # Validation of operations -- looking for remaining "${" string literals
    if grep -q '\${' "$out"; then
        echo "render failed: unsubstituted variables remain in $out" >&2
        exit 1
    fi
}

validate_param "${1:-}"
export_ssm_params "$1"
substitute_template_files "$1"


