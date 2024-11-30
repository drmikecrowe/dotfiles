def _yy():
    tmp = $(mktemp -t "yazi-cwd.XXXXXX")
    yazi $ARGS --cwd-file=$tmp
    cwd = $(cat $tmp)
    if cwd and cwd != $PWD:
        cd $cwd
    rm -f $tmp

aliases['yy'] = _yy
