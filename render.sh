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
        *) echo "Usage: $0 <bastion|compute>" >&2; exit 1 ;;
    esac
}

export_ssm_params() {
    export CI_SSH_PUBKEY=$(aws ssm get-parameter --name /lab/ci/ssh-public-key --query "Parameter.Value" --output text)
    export ADMIN_SSH_PUBKEY=$(aws ssm get-parameter --name /lab/admin/admin-ssh-public-key --query "Parameter.Value" --output text)
    export ADMIN_PASSWORD_HASH=$(aws ssm get-parameter --name "/lab/$1/password-hash" --query "Parameter.Value" --with-decryption --output text)
}

substitute_template_files() {
    local outs
    case "$1" in
        bastion)
            : "${TS_AUTHKEY:?Paste the auth key into the env before running}"
            envsubst "$VARS" < bastion/preseed.cfg.tmpl > "bastion/preseed.cfg"
            envsubst "$VARS" < bastion/bootstrap.sh.tmpl > "bastion/bootstrap.sh"
            outs="bastion/preseed.cfg bastion/bootstrap.sh"
            ;;
        compute)
            envsubst "$VARS" < compute/answer.toml.tmpl > "compute/answer.toml"
            outs="compute/answer.toml"
            ;;
    esac

    # Validation of operations -- looking for remaining "${" string literals
    for out in $outs; do
        if grep -q '\${' "$out"; then
            echo "render failed: unsubstituted variables remain in $out" >&2
            exit 1
        fi
    done
}

validate_param "${1:-}"
export_ssm_params "$1"
substitute_template_files "$1"


