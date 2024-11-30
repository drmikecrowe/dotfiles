export PRE_INIT="/tmp/$(basename $SHELL).pre-init.sh"
echo "#!$SHELL" > $PRE_INIT
for FILE in $(find "$HOME/.shell.d/init" -maxdepth 1 -type f -name '*.sh' | sort); do
  echo "### $FILE ###" >> $PRE_INIT
  cat "$FILE" >> $PRE_INIT
  echo " " >> $PRE_INIT
done

export POST_INIT="/tmp/$(basename $SHELL).post-init.sh"
echo "#!$SHELL" > $POST_INIT
for FILE in $(find "$HOME/.shell.d/login" -maxdepth 1 -type f | rg "\.sh$|\.$(basename $SHELL)$" | sort); do
  echo "### $FILE ###" >> $POST_INIT
  cat "$FILE" >> $POST_INIT
  echo " " >> $POST_INIT
done