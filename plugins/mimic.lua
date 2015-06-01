-- http://git.io/vUA4M
local socket = require "socket"
local JSON = require "cjson"

local wikiusage = {
  "!mimic [text]: Show article from 'La Tana del Mimic'",
  "!mimic search [text]: Search for articles in 'La Tana del Mimic'",
}

local Wikipedia = {
  -- http://meta.wikimedia.org/wiki/List_of_Wikipedias
  wiki_server = "http://bluehood.xyz",
  wiki_path = "/w/api.php",
  wiki_load_params = {
    action = "query",
    prop = "extracts",
    format = "json",
    exchars = 300,
    exsectionformat = "plain",
    explaintext = "",
    redirects = ""
  },
  wiki_search_params = {
    action = "opensearch",
  },
}

function Wikipedia:getWikiServer(lang)
  return self.wiki_server
end

--[[
--  return decoded JSON table from Wikipedia
--]]
function Wikipedia:loadPage(text, lang, intro, plain)
  local request, sink = {}, {}
  local query = ""

  self.wiki_load_params.explaintext = plain and "" or nil -- plain ? "" : nil
  for k,v in pairs(self.wiki_load_params) do
    query = query .. k .. '=' .. v .. '&'
  end
  local parsed = URL.parse(self:getWikiServer(lang))
  parsed.path = self.wiki_path
  parsed.query = query .. "titles=" .. URL.escape(text)

  -- HTTP request
  request['url'] = URL.build(parsed)
  print(request['url'])
  request['method'] = 'GET'
  request['sink'] = ltn12.sink.table(sink)
  
  local httpRequest = parsed.scheme == 'http' and http.request or https.request
  local code, headers, status = socket.skip(1, httpRequest(request))

  if not headers or not sink then
    return nil
  end

  local content = table.concat(sink)
  if content ~= "" then
    local ok, result = pcall(JSON.decode, content)
    if ok and result then
      return result
    else
      return nil
    end
  else 
    return nil
  end
end

-- extract intro passage in wiki page
function Wikipedia:wikintro(text, lang)
  local result = self:loadPage(text, lang, true, true)

  if result and result.query then
    local query = result.query
    if query and query.normalized then
      text = query.normalized[1].to or text
    end

    local page = query.pages[next(query.pages)]

    if page and page.extract then
      return text..": "..page.extract
    else
      local text = "Extract not found for "..text
      text = text..'\n'..table.concat(wikiusage, '\n')
      return text
    end
  else
    return "Sorry an error happened"
  end
end

function Wikipedia:loadSearchResults(text, lang)
  local request, sink = {}, {}
  local query = ""

  for k,v in pairs(self.wiki_search_params) do
    query = query .. k .. '=' .. v .. '&'
  end
  local parsed = URL.parse(self:getWikiServer(lang))
  parsed.path = self.wiki_path
  parsed.query = query .. "search=" .. URL.escape(text)

  -- HTTP request
  request['url'] = URL.build(parsed)
  print(request['url'])
  request['method'] = 'GET'
  request['sink'] = ltn12.sink.table(sink)
  
  local httpRequest = parsed.scheme == 'http' and http.request or https.request
  local code, headers, status = socket.skip(1, httpRequest(request))

  if not headers or not sink then
    return nil
  end

  local content = table.concat(sink)
  if content ~= "" then
    local ok, result = pcall(JSON.decode, content)
    if ok and result then
      return result
    else
      return nil
    end
  else 
    return nil
  end
end

-- search for term in wiki
function Wikipedia:wikisearch(text, lang)
  local result = self:loadSearchResults(text, lang)

  if result and result[1] then
    if result[2] and result[2][1] then
	 	local pages = ""
		for i,page in ipairs(result[2]) do
        pages = pages .. "\n" .. page
		end
      return pages
    else
      return "No result found"
    end
  else
    return "Sorry, an error happened"
  end
  	
end

local function run(msg, matches)
  -- TODO: Remember language (i18 on future version)
  -- TODO: Support for non Wikipedias but Mediawikis
  local term = matches[2]
  local search = matches[1]
  if not term then
    term = search
    search = nil
  end
  if term == "" then
    local text = "Usage:\n"
    text = text..table.concat(wikiusage, '\n')
    return text
  end
  if search == nil then
    local result = Wikipedia:wikintro(term, lang)
    return result
  end
  if search == "search" then
    local result = Wikipedia:wikisearch(term, lang)
	 return result
  end
end

return {
  description = "Searches 'La Tana del Mimic' and sends results",
  usage = wikiusage,
  patterns = {
	 "^![Mm]imic (search) ?(.*)$",
    "^![Mm]imic ?(.*)$",
  },
  run = run
}
