-- Как компонент выглядит в /dev/components: тип -> функция(прокси) -> узлы.
local adapter_api = ...
local fs = require("filesystem")
local text = require("text")

local cache = {}
local function once(callback)
  local c = cache[callback]
  if not c then
    c = callback()
    cache[callback] = c
  end
  return c
end

return {
  computer = function(proxy)
    return {
      beep = { write = adapter_api.createWriter(proxy.beep, 0, "number", "number") },
      running = adapter_api.create_toggle(proxy.isRunning, proxy.start, proxy.stop),
    }
  end,

  eeprom = function(proxy)
    return {
      contents = { read = proxy.get, write = proxy.set },
      data = { read = proxy.getData, write = proxy.setData },
      checksum = { read = proxy.getChecksum, size = function() return 8 end },
      size = { once(proxy.getSize) },
      dataSize = { once(proxy.getDataSize) },
      label = { write = proxy.setLabel, proxy.getLabel() },
      makeReadonly = { write = proxy.makeReadonly },
    }
  end,

  filesystem = function(proxy)
    return {
      label = {
        read = function() return proxy.getLabel() or "" end,
        write = function(v) proxy.setLabel(text.trim(v)) end,
      },
      isReadOnly = { proxy.isReadOnly() },
      spaceUsed = { proxy.spaceUsed() },
      spaceTotal = { proxy.spaceTotal() },
      mounts = { read = function()
        local mounts = {}
        for mproxy, mpath in fs.mounts() do
          if mproxy.address == proxy.address then
            mounts[#mounts + 1] = mpath
          end
        end
        return table.concat(mounts, "\n")
      end },
    }
  end,

  gpu = function(proxy)
    local screen = proxy.getScreen()
    screen = screen and ("../" .. screen)
    return {
      viewport = { write = adapter_api.createWriter(proxy.setViewport, 2, "number", "number"), proxy.getViewport() },
      resolution = { write = adapter_api.createWriter(proxy.setResolution, 2, "number", "number"), proxy.getResolution() },
      maxResolution = { proxy.maxResolution() },
      screen = { link = screen, isAvailable = proxy.getScreen },
      depth = { write = adapter_api.createWriter(proxy.setDepth, 1, "number"), proxy.getDepth() },
      maxDepth = { proxy.maxDepth() },
      background = { write = adapter_api.createWriter(proxy.setBackground, 1, "number", "boolean"), proxy.getBackground() },
      foreground = { write = adapter_api.createWriter(proxy.setForeground, 1, "number", "boolean"), proxy.getForeground() },
    }
  end,

  internet = function(proxy)
    return {
      httpEnabled = { proxy.isHttpEnabled() },
      tcpEnabled = { proxy.isTcpEnabled() },
    }
  end,

  modem = function(proxy)
    return {
      wakeMessage = {
        read = function() return proxy.getWakeMessage() or "" end,
        write = function(msg) return proxy.setWakeMessage(msg) end,
      },
      wireless = { proxy.isWireless() },
    }
  end,

  screen = function(proxy)
    return {
      aspectRatio = { proxy.getAspectRatio() },
      keyboards = { read = function()
        local ks = {}
        for _, ka in ipairs(proxy.getKeyboards()) do
          ks[#ks + 1] = ka
        end
        return table.concat(ks, "\n")
      end },
      on = adapter_api.create_toggle(proxy.isOn, proxy.turnOn, proxy.turnOff),
      precise = adapter_api.create_toggle(proxy.isPrecise, proxy.setPrecise),
      touchModeInverted = adapter_api.create_toggle(proxy.isTouchModeInverted, proxy.setTouchModeInverted),
    }
  end,
}
