local cartridge = require('cartridge')
local log = require('log')
local json = require('json')
local http_client = require('http.client').new()

local httpd = cartridge.service_get('httpd')

local myapp = {
    cache = {},
    cache_ttl = 3600,
    api_base_url = 'https://api.open-meteo.com/v1/forecast'
}
local function get_weather(city)
    local cached = myapp.cache[city]
    if cached ~= nil and cached.expire_at > os.time() then
        return cached.data
    end

    local api_url = string.format('%s?city=%s&key=%s', myapp.api_base_url, city, myapp.api_key)
    local response = http_client:get(api_url)

    if response.status ~= 200 then
        error('Failed to get weather data')
    end

    local data = json.decode(response.body)

    myapp.cache[city] = {
        data = data,
        expire_at = os.time() + myapp.cache_ttl
    }
    return data
end

local function http_handler(req)
    if req.method ~= 'GET' then
        return {
            status = 405,
            body = 'Method not allowed'
        }
    end

    local city = req:stash('city')
    if city == nil or city == '' then
        return {
            status = 400,
            body = 'City not specified'
        }
    end

    local data = get_weather(city)

    return {
        status = 200,
        headers = {
            ['Content-Type'] = 'application/json'
        },
        body = json.encode(data)
    }
end
local function init(opts)
    httpd:route({
        path = '/weather/:city',
        method = 'GET'
    }, http_handler)

    return true
end

local function stop()
    return true
end

local function validate_config(conf_new, conf_old)
    return true
end

local function apply_config(conf, opts)
    return true
end

return {
    role_name = 'app.roles.weather',
    init = init,
    stop = stop,
    validate_config = validate_config,
    apply_config = apply_config
}
