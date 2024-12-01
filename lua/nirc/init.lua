local M = {}

local password = ""
local nickname = nil
local username = nil
local realname = nil
local message_buffer = {}

function M.setup(opts)
  opts = opts or {}

  if not opts.nickname or not opts.username or not opts.realname then
    error("You must provide a nickname, username, and realname")
    return
  end
  password = opts.password or "none"
  nickname = opts.nickname
  username = opts.username
  realname = opts.realname
end

local uv = vim.loop

-- Helper function to create the output buffer
local function create_output_buf()
  return vim.api.nvim_create_buf(false, true) -- Create a scratch buffer
end

-- Function to log messages to an internal buffer
local function log_message(msg)
  for _, line in ipairs(vim.split(msg, "\n", { trimempty = true })) do
    table.insert(message_buffer, line)
  end
end

-- Function to show the contents of the message buffer
function M.show_buf()
  local buf = create_output_buf()
  vim.cmd("split")
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, message_buffer)
  vim.bo[buf].modifiable = false
end

local function create_tcp_client(host, port, on_data_callback)
  local client = uv.new_tcp()

  if not client then
    log_message("Failed to create TCP client")
    return
  end

  local function on_read(err, data)
    assert(not err, err)
    if data then
      on_data_callback(client, data)
    else
      client:close()
      log_message("Connection closed")
    end
  end

  client:connect(host, port, function(err)
    assert(not err, err)
    log_message("Connected to " .. host .. ":" .. port)
    client:read_start(on_read)
  end)

  return client
end

local function init_irc(client)
  client:write("PASS " .. password .. "\r\n")
  client:write("NICK " .. nickname .. "\r\n")
  client:write("USER " .. username .. " 0 * :" .. realname .. "\r\n")
  log_message("Initialized IRC client")
end

local function handle_irc_message(client, data)
  if data:sub(1, 4) == "PING" then
    client:write("PONG " .. data:sub(6) .. "\r\n")
  end
  log_message(data)
end

uv.getaddrinfo("irc.freenode.net", nil, { family = "inet" }, function(err, res)
  if not res then
    log_message("Failed to resolve DNS")
    return
  end

  if err then
    log_message("DNS resolution failed: " .. err)
  else
    local ip = res[1].addr
    if not ip then
      log_message("Failed to resolve IP")
      return
    end

    local client = create_tcp_client(ip, 6667, function(client, data)
      handle_irc_message(client, data)
    end)

    init_irc(client)
  end
end)

return M

