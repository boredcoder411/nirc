local M = {}

local password = ""
local nickname = nil
local username = nil
local realname = nil
local message_buffer = {}
local client = nil

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

-- Function to send a message via the IRC client
function M.send_message()
  if not client then
    log_message("Not connected to the server")
    return
  end

  local message = vim.fn.input("Enter message: ")
  if message ~= "" then
    client:write(message .. "\r\n")
    log_message("You: " .. message)
  end
end

-- Function to join an IRC channel
function M.join_channel()
  if not client then
    log_message("Not connected to the server")
    return
  end

  local channel = vim.fn.input("Enter channel to join (e.g., #channel): ")
  if channel ~= "" then
    client:write("JOIN " .. channel .. "\r\n")
    log_message("Joined channel: " .. channel)
  end
end

-- Function to send custom IRC commands
function M.send_command()
  if not client then
    log_message("Not connected to the server")
    return
  end

  local command = vim.fn.input("Enter IRC command: ")
  if command ~= "" then
    client:write(command .. "\r\n")
    log_message("Sent command: " .. command)
  end
end

local function create_tcp_client(host, port, on_data_callback)
  local tcp_client = uv.new_tcp()

  if not tcp_client then
    log_message("Failed to create TCP client")
    return
  end

  local function on_read(err, data)
    assert(not err, err)
    if data then
      on_data_callback(tcp_client, data)
    else
      tcp_client:close()
      log_message("Connection closed")
    end
  end

  tcp_client:connect(host, port, function(err)
    assert(not err, err)
    log_message("Connected to " .. host .. ":" .. port)
    tcp_client:read_start(on_read)
  end)

  return tcp_client
end

local function init_irc(tcp_client)
  tcp_client:write("PASS " .. password .. "\r\n")
  tcp_client:write("NICK " .. nickname .. "\r\n")
  tcp_client:write("USER " .. username .. " 0 * :" .. realname .. "\r\n")
  log_message("Initialized IRC client")
end

local function handle_irc_message(tcp_client, data)
  if data:sub(1, 4) == "PING" then
    tcp_client:write("PONG " .. data:sub(6) .. "\r\n")
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

    client = create_tcp_client(ip, 6667, function(tcp_client, data)
      handle_irc_message(tcp_client, data)
    end)

    init_irc(client)
  end
end)

return M

