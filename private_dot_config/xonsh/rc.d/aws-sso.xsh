import subprocess
import builtins
import re
from xonsh.completers.tools import *


@contextual_command_completer_for("aws-sso-profile")
def __aws_sso_profile_complete(ctx: CommandContext):
    cmd = [arg.raw_value for arg in ctx.args[: ctx.arg_index]]
    if not cmd:
        return
    if not cmd[0].startswith('aws-sso-profile'):
        return
    prefix = ctx.prefix
    args = builtins.__xonsh__.env.get('AWS_SSO_HELPER_ARGS', '-L error --no-config-check')
    
    try:
        output = subprocess.check_output(f'aws-sso {args} list --csv -P "Profile={prefix}" Profile', shell=True)
        profiles = output.decode('utf-8').split()
    except subprocess.CalledProcessError:
        profiles = []

    return {p for p in profiles if p.startswith(prefix)}


@contextual_command_completer_for("aws-sso")
def __aws_sso_complete(ctx: CommandContext):
    cmd = [arg.raw_value for arg in ctx.args[: ctx.arg_index]]
    if not cmd:
        return
    if not cmd[0].startswith('aws-sso'):
        return
    prefix = ctx.prefix
    args = builtins.__xonsh__.env.get('AWS_SSO_HELPER_ARGS', '-L error --no-config-check')
    
    try:
        output = subprocess.check_output(f'aws-sso {args} --help', shell=True)
        profiles = output.decode('utf-8').split()
    except subprocess.CalledProcessError:
        profiles = []

    return {p for p in profiles if p.startswith(prefix)}

def aws_sso_profile(profiles):
    if not profiles:
        return
    profile = profiles[0]
    args = builtins.__xonsh__.env.get('AWS_SSO_HELPER_ARGS', '-L error --no-config-check')
    if 'AWS_PROFILE' in builtins.__xonsh__.env:
        print("Unable to assume a role while AWS_PROFILE is set")
        return 1
    try:
        eval_output = subprocess.check_output(f'aws-sso {args} eval -p "{profile}"', shell=True)
        key_value_pairs = re.findall(r'export (\w+)="([^"]*)"', eval_output.decode('utf-8'))
        for key, value in key_value_pairs:
            builtins.__xonsh__.env[key] = value
        if builtins.__xonsh__.env.get('AWS_SSO_PROFILE') != profile:
            return 1
    except subprocess.CalledProcessError:
        return 1
    return 0

def aws_sso_clear():
    args = builtins.__xonsh__.env.get('AWS_SSO_HELPER_ARGS', '-L error --no-config-check')
    if 'AWS_SSO_PROFILE' not in builtins.__xonsh__.env:
        print("AWS_SSO_PROFILE is not set")
        return 1
    try:
        eval_output = subprocess.check_output(f'aws-sso {args} eval -c', shell=True)
        keys = [x[6:] for x in eval_output.decode('utf-8').split("\n") if x.startswith("unset")]
        for key in keys[1:]:
            del builtins.__xonsh__.env[key]
    except subprocess.CalledProcessError:
        return 1
    return 0

completer add '__aws_sso_profile_complete'  __aws_sso_profile_complete 'start'
completer add '__aws_sso_complete'  __aws_sso_complete 'start'

aliases['aws-sso-profile'] = aws_sso_profile
aliases['aws-sso-clear'] = aws_sso_clear
