__doc__ = """
pipx inject xonsh \
      xontrib-zoxide \
      xontrib-chatgpt \
      xonsh-direnv \
      xontrib-prompt-starship \
      xontrib-readable-traceback \
      xontrib-gitinfo \
      xontrib-sh \
      xontrib-term-integrations \
      xontrib-clp \
      xontrib-dotdot \
      xontrib-cd
"""

# this uses cross-platform xclip/pbcopy
$XONTRIB_CLP_ALIAS = 'shutil'

_xontribs = [
    "clp",
    "dotdot",
    "zoxide",
    "chatgpt",
    "direnv",
    "coreutils",
    "gitinfo",
    "sh",
    "prompt_starship",
    "term_integration",
    "readable-traceback",
    "langenv"
]

if _xontribs:
    xontrib load @(_xontribs)
