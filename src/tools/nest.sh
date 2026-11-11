#!/bin/sh
# nest.sh -- the nest, as post.l's (nest _) reads it: $LOVE_NEST, else $XDG_DATA_HOME/love,
# else $HOME/.love (/.love with no HOME). for shell under a make that no love runs above
if [ -n "${LOVE_NEST:-}" ]; then echo "$LOVE_NEST"
elif [ -n "${XDG_DATA_HOME:-}" ]; then echo "$XDG_DATA_HOME/love"
else echo "${HOME:-}/.love"; fi
