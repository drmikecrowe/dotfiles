from xonsh.platform import ON_LINUX, ON_DARWIN  # ON_DARWIN, ON_WINDOWS, ON_WSL, ON_CYGWIN, ON_MSYS, ON_POSIX, ON_FREEBSD, ON_DRAGONFLY, ON_NETBSD, ON_OPENBSD

# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# aliases
# -------------------------------------------------------------------------------------------------------------------------------------------------------------

def _in_path(s):
    import os 
    for path in $PATH:
        maybe = os.path.join(str(path), s[0])
        if os.path.exists(maybe):
            print(maybe)
aliases["where-in-path"] = _in_path

# Make directory and cd into it.
# Example: md /tmp/my/awesome/dir/will/be/here
aliases['mcd'] = lambda args: execx(f'mkdir -p {repr(args[0])} && cd {repr(args[0])}')

aliases['-'] = 'cd -'

if ON_LINUX:
    if os.path.exists("/usr/bin/ksshaskpass"):
        $SSH_ASKPASS = '/usr/bin/ksshaskpass'


# if ON_DARWIN:
#     aliases["psa"] = 'ps aux'
#     aliases["psag"] = 'ps aux | grep'

# def setLsAliases(colorflag):
#     # aliases["ls"] = f"ls {colorflag}"
#     colorflag = ""
#     aliases["l"] = f"ls -l {colorflag}"
#     aliases["ll"] = f"ls -l {colorflag}"
#     aliases["la"] = f"ls -la {colorflag}"
#     aliases["ls1b"] = "/usr/bin/ls -1b "

# if ON_DARWIN:
#     $LSCOLORS = 'BxBxhxDxfxhxhxhxhxcxcx'
#     setLsAliases("-G")

# if ON_LINUX:
#     $LS_COLORS = 'no=00:fi=00:di=01;31:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'
#     setLsAliases("--color")

