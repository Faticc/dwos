local seconds=math.floor(require("computer").uptime())
io.write(string.format("%02d:%02d:%02d\n",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60))
