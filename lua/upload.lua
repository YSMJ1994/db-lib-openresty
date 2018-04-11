local _M = {
    _VERSION = '0.01'
}

local upload = require "resty.upload"
local chunk_size = 4096
local cjson = require 'cjson.safe'
local os_exec = os.execute
local os_date = os.date
local md5 = ngx.md5
local io_open = io.open
local tonumber = tonumber
local type = type
local ngx_var = ngx.var
local upload_dir = "/Users/wuwaki/playground/digital-static"
local ngx_req = ngx.req
local os_time = os.time
local json_encode = cjson.encode
local static_prefix = 'static'

-- 根据后缀名获取文件上传路径
local function get_upload_path(ext)
    if ext == 'jpg' or ext == 'gif' or ext == 'png' then
        return '/uploads/images'
    elseif ext == 'pdf' or ext == 'txt' then
        return '/uploads/books'
    else
        return nil
    end
end

-- 根据文件名获取文件后缀
local function get_ext(res)
    local filename = ngx.re.match(res, '(.+)filename="(.+)"(.*)')
    if filename then
        local upload_path
        local ext = filename[2]:match(".+%.(%w+)$")
        local upload_path = get_upload_path(ext)

        return ext, upload_path
    else
        return nil
    end
end

local function in_table(key, table)
    for k, v in ipairs(table) do
        if v == key then
            return true;
        end
    end
    return false
end

local function file_exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end

local function json_return(code, message, data)
    ngx.header["Content-type"] = "application/json"
    ngx.say(json_encode({code = code, msg = message, data = data}))
end

local function uploadfile()
    local file
    local file_name
    local form, err = upload:new(chunk_size)
    local conf = {max_size = 10000000, allow_exts = {'jpg', 'png', 'gif', 'pdf', 'txt'} }
    local root_path = upload_dir
    local file_info = {extension = '', filesize = 0, url = '', mime = '' }
    local content_len = ngx_req.get_headers()['Content-length']
    local body_size = content_len and tonumber(content_len) or 0
    if not form then
        return nil, '没有上传的文件'
    end
    if body_size > 0 and body_size > conf.max_size then
        return nil, '文件过大'
    end
    file_info.filesize = body_size
    while true do
        local typ, res, err = form:read()
        if typ == "header" then
            if res[1] == "Content-Type" then
                file_info.mime = res[2]
            elseif res[1] == "Content-Disposition" then
               
                local file_id = md5('upload'..os_time())
                local ext, upload_path = get_ext(res[2])

                if not ext or not upload_path then
                    return nil,  '未获取文件后缀'
                end

                file_info.extension = ext

                if not in_table(ext, conf.allow_exts) then
                    return nil,  '不支持该文件格式'
                end

                local dir = root_path..upload_path..'/'
                if file_exists(dir) ~= true then
                    local status = os_exec('mkdir -p '..dir)
                    if status ~= true then
                        return nil, '创建目录失败'
                    end
                end
                file_name = dir..file_id.."."..ext
                if file_name then
                    file = io_open(file_name, "w+")
                    if not file then
                        return nil, '打开文件失败'
                    end
                end
            end
        elseif typ == "body" then
            if file then
                file:write(res)
            end
        elseif typ == "part_end" then
            if file then
                file:close()
                file = nil
            end
        elseif typ == "eof" then
            file_name = ngx.re.sub(file_name, root_path, '')
            file_info.url = static_prefix..file_name
            return file_info
        else

        end
    end
end


local file_info, err = uploadfile()
if file_info then
    json_return(200, '上传成功', { imgurl = file_info.url })
else
    json_return(5003, err, nil)
end