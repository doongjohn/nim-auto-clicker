--define: "release"
--app: "gui"
--mm: "orc"
--threads: "on"
--opt: "size"
--excessiveStackTrace: "off"
--passL: "-static-libgcc -Wl,-Bstatic -s"

when defined(cpu64):
  {.link: "../res/wNim64.res".}
else:
  {.link: "../res/wNim32.res".}
