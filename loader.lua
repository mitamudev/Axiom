-- Axiom Script loader. Secrets and authorization decisions belong to the API.
local env = getgenv()
local base = "https://axiom-whitelist.jpssomacontact.workers.dev"
local key = env.AXIOM_KEY
local product = nil
local function fail(message) error("Axiom Script: " .. message, 0) end
if type(base) ~= "string" or not base:match("^https://") then fail("Use the loader from Get Script in Discord.") end
base = base:gsub("/+$", "")
if type(key) ~= "string" or (product ~= nil and type(product) ~= "string") then fail("Missing key or invalid product. Open Get Script in Discord.") end
local send = request or http_request or (syn and syn.request) or (http and http.request)
if type(send) ~= "function" then fail("This executor has no supported HTTP request function.") end
if type(gethwid) ~= "function" then fail("This executor has no supported gethwid function. Contact support.") end
local deviceOK, device = pcall(gethwid)
if not deviceOK or type(device) ~= "string" or #device < 8 or #device > 256 then fail("Could not obtain a supported device identifier.") end
local HttpService = game:GetService("HttpService")
local nonce = HttpService:GenerateGUID(false)
local function post(path, data, token)
    local headers = {["Content-Type"] = "application/json"}
    if token then headers.Authorization = "Bearer " .. token end
    local ok, response = pcall(send, {Url = base .. path, Method = "POST", Headers = headers, Body = HttpService:JSONEncode(data)})
    if not ok or type(response) ~= "table" then fail("Connection failed. Check your network and try again.") end
    local status = tonumber(response.StatusCode or response.Status)
    local body = response.Body or response.body
    if type(body) ~= "string" then fail("Invalid response from the license service.") end
    if status ~= 200 then
        local decodedOK, decoded = pcall(function() return HttpService:JSONDecode(body) end)
        local message = decodedOK and type(decoded) == "table" and decoded.message
        fail(type(message) == "string" and message or "License service unavailable. Try again later.")
    end
    return body
end
local response = post("/v1/session", {key = key, product = product, hwid = device, nonce = nonce, placeId = string.format("%.0f", game.PlaceId)})
local decodedOK, session = pcall(function() return HttpService:JSONDecode(response) end)
if not decodedOK or type(session) ~= "table" or type(session.token) ~= "string" then fail("Invalid session response.") end
local source = post("/v1/script", {hwid = device, nonce = nonce}, session.token)
local chunk = loadstring(source, "Axiom/" .. (product or "General"))
if type(chunk) ~= "function" then fail("Could not compile the script. Contact support.") end
-- shortcut: a client can copy delivered code; this handshake controls delivery, not ownership of the runtime.
chunk()
