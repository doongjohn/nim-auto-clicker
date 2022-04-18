--define: "release"
--app: "gui"
--mm: "orc"
--threads: "on"
--opt: "size"
--excessiveStackTrace: "off"

# https://stackoverflow.com/questions/13768515/how-to-do-static-linking-of-libwinpthread-1-dll-in-mingw
--passL: "-static -s"

when defined(cpu64):
  {.link: "./res/wNim64.res".}
else:
  {.link: "./res/wNim32.res".}
