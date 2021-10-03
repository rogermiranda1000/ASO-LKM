cmd_/home/rogermiranda1000/lkm/modules.order := {   echo /home/rogermiranda1000/lkm/hello_world.ko; :; } | awk '!x[$$0]++' - > /home/rogermiranda1000/lkm/modules.order
