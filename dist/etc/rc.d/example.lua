local a=0
function start(b)
print("This script displays a welcome message and counts the number "..
"of times it has been called. The welcome message can be set in the "..
"config file /etc/rc.cfg")
print(args)
if b then
print(b)
end
print(a)
print("runlevel: "..require("computer").runlevel())
a=a+1
end
