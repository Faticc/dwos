-- имя машины для приглашения; /etc/profile.lua идёт позже
if require("filesystem").exists("/etc/hostname") then
  loadfile("/bin/hostname.lua")("--update")
end
os.setenv("SHELL", "/bin/sh.lua")
