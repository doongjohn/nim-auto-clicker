--app: "gui"
--mm: "orc"
--threads: "on"
--opt: "size"
--passL: "-static-libgcc -Wl,-Bstatic -s"
--excessiveStackTrace: "off"

when defined(cpu64):
  {.link: "../res/wNim64.res".}
else:
  {.link: "../res/wNim32.res".}
