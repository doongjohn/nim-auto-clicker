switch("threads", "on")
switch("opt", "size")
switch("passL", "-s")
switch("app", "gui")

when defined(cpu64):
  {.link: "../res/wNim64.res".}
else:
  {.link: "../res/wNim32.res".}