# BEGIN_AWS_SSO_CLI
__aws_sso_profile_complete() {
    COMPREPLY=()
    local _args=${AWS_SSO_HELPER_ARGS:- -L error --no-config-check}
    local cur
    _get_comp_words_by_ref -n : cur

    COMPREPLY=($(compgen -W '$(/usr/local/bin/aws-sso-cli $_args list --csv -P "Profile=$cur" Profile)' -- ""))

    __ltrim_colon_completions "$cur"
}

aws-sso-profile() {
    local _args=${AWS_SSO_HELPER_ARGS:- -L error --no-config-check}
    if [ -n "$AWS_PROFILE" ]; then
        echo "Unable to assume a role while AWS_PROFILE is set"
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Usage: aws-sso-profile <profile>"
        return 1
    fi

    eval $(/usr/local/bin/aws-sso-cli $_args eval -p "$1")
    if [ "$AWS_SSO_PROFILE" != "$1" ]; then
        return 1
    fi
}

aws-sso-clear() {
    local _args=${AWS_SSO_HELPER_ARGS:- -L error --no-config-check}
    if [ -z "$AWS_SSO_PROFILE" ]; then
        echo "AWS_SSO_PROFILE is not set"
        return 1
    fi
    eval $(aws-sso eval $_args -c)
}

complete -F __aws_sso_profile_complete aws-sso-profile
complete -C /usr/local/bin/aws-sso-cli aws-sso

# END_AWS_SSO_CLI