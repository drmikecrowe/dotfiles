$OPENAI_API_KEY = "op://Private/OpenAI-API-Key/api-key"
$STARSHIP_SHELL = "xonsh"
$STARSHIP_CONFIG = '~/.config/starship_xonsh.toml'

old_get = __xonsh__.env.get

def get_val(k, d=None):
    v = old_get(k, d)
    if type(v) == str and v.startswith("op://"):
        return $(op read @(v)).strip()
    return v


from xonsh.built_ins import XSH
XSH.env.get = get_val