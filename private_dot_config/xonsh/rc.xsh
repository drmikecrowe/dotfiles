import os
from datetime import datetime
from xonsh.platform import ON_LINUX, ON_DARWIN  # ON_DARWIN, ON_WINDOWS, ON_WSL, ON_CYGWIN, ON_MSYS, ON_POSIX, ON_FREEBSD, ON_DRAGONFLY, ON_NETBSD, ON_OPENBSD


$XONSH_SHOW_TRACEBACK = False
$AUTO_CD = True
$MANPAGER = "nvim +Man!"
$PUSHD_SILENT = True
$DIRENV_HIDE_DIFF = 1

try:
	$EDITOR = ('code -n -w' if $DISPLAY else 'nvim')
except (Exception):
	$EDITOR = 'nvim'
