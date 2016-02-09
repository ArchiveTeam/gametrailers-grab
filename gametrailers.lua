dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

local status_code = nil

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  local thumbnailurl = nil

  downloaded[url] = true
  
  local function check(urla)
    local url = string.match(urla, "^([^#]+)")
    if string.match(url, "thumbnail%.") then
      thumbnailurl = url
    end
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and (string.match(url, "^https?://[^/]*gametrailers%.com") or string.match(url, "https?://[^/]*edgecastcdn%.net") or string.match(url, "https?://[^/]*brkmd%.com")) and not (string.match(url, "/>")) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^//") then
      check("http:"..newurl)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if not (string.match(newurl, "^https?://") or string.match(newurl, "^/") or string.match(newurl, "^javascript:") or string.match(newurl, "^mailto:") or string.match(newurl, "^%${")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end

  if string.match(url, "%.mp4Seg[0-9]+%-Frag[0-9]+") and status_code == 200 then
    local fragnum = string.match(url, "%.mp4Seg[0-9]+%-Frag([0-9]+)")
    check(string.gsub(url, "(%.mp4Seg[0-9]+%-Frag)[0-9]+", "%1"..fragnum+1))
  end
  
  if (string.match(url, "^https?://embed%.gametrailers%.com/embed/") or string.match(url, "https?://[^/]*edgecastcdn%.net[^%?]+%?")) and not (string.match(url, "%.mp4%?") or string.match(url, "%.mp4Seg[0-9]+%-Frag[0-9]+")) then
    html = read_file(file)
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    if string.match(html, '"[Aa]uth[Tt]oken"') then
      local token = string.match(html, '"AuthToken":%s+"([^"]+)"')
      local kbpslist = {}
      local newlist = {}
      if thumbnailurl ~= nil then
        check(thumbnailurl..'?'..token)
      end
      for kbps in string.gmatch(html, "([0-9]+)_kbps") do
        local add = true
        for _, i in pairs(kbpslist) do
          if i == kbps then
            add = false
          end
        end
        if add == true then
          table.insert(kbpslist, kbps)
        end
      end
      for i=1,#kbpslist do
        local lowkbps = 1000000
        for _, kbps in pairs(kbpslist) do
          local add = true
          for _, num in pairs(newlist) do
            if num == kbps then
              add = false
            end
          end
          if add == true and tonumber(kbps) < tonumber(lowkbps) then
            lowkbps = kbps
          end
        end
        table.insert(newlist, lowkbps)
      end
      for i=1,#newlist-2 do
        check('http://wpc.10016.edgecastcdn.net/0210016/'..string.gsub(string.match(html, '"uri":%s+"https?://wpc[^/]+/[0-9]+/([^%?]+)'), '[0-9]+(_kbps%.mp4)', ','.. newlist[i] ..','.. newlist[i+1] ..','.. newlist[i+2] ..',%1')..'.f4m?'..token)
      end
      for i=1,#newlist do
        for num=1,#newlist do
          for numk=1,#newlist do
            local templist = {}
            for numm=1,#newlist do
              if numm ~= i and numm ~= num then
                table.insert(templist, newlist[numm])
              end
            end
            if #templist >= 3 then
              for i=1,#templist-2 do
                check('http://wpc.10016.edgecastcdn.net/0210016/'..string.gsub(string.match(html, '"uri":%s+"https?://wpc[^/]+/[0-9]+/([^%?]+)'), '[0-9]+(_kbps%.mp4)', ','.. templist[i] ..','.. templist[i+1] ..','.. templist[i+2] ..',%1')..'.f4m?'..token)
              end
            end
          end
        end
      end
    end
    if string.match(url, "%.mp4%.f4m%?") and not string.match(url, ',') then
      check(string.gsub(string.match(url, '^([^%?]+)%?'), '%.f4m', 'Seg1-Frag1'))
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 400) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if not (string.match(url["url"], "^https?://[^/]*gametrailers%.com") or string.match(url["url"], "https?://[^/]*edgecastcdn%.net") or string.match(url["url"], "https?://[^/]*brkmd%.com")) then
      return wget.actions.EXIT
    end
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.EXIT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
