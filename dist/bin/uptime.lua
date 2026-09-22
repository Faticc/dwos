local a=math.floor(require("computer").uptime())
io.write(string.format("%02d:%02d:%02d\n",math.floor(a/3600),math.floor(a/60)%60,a%60))
