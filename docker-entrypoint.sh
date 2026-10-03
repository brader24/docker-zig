#!/bin/sh
# If a command was given, run it (docker run IMAGE zig build ...).
# With a TTY and no command, drop into bash (docker run -it IMAGE).
# Otherwise keep the container running (docker run -d, VS Code Dev Containers).
if [ "$#" -gt 0 ]; then
    exec "$@"
fi
if [ -t 0 ]; then
    exec /bin/bash
fi
exec sleep infinity
