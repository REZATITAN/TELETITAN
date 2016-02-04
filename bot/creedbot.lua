package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "Boobs",
    "Feedback",
    "plugins",
    "lock_join",
    "antilink",
    "antitag",
    "gps",
    "auto_leave",
    "cpu",
    "calc",
    "bin",
    "tagall",
    "text",
    "info",
    "bot_on_off",
    "welcome",
    "webshot",
    "google",
    "sms",
    "anti_spam",
    "add_bot",
    "owners",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban"
    },
    sudo_users = {118682430},--Sudo users
    disabled_channels = {},
    realm = {},--Realms Id
    moderation = {data = 'data/moderation.json'},
    about_text = [[TELETITAN 2.5
     
    this bot is made by : @REZATITAN
   〰〰〰〰〰〰〰〰
  ♻️ You can send your Ideas and messages to Us By sending them into bots account by this command :
   تمامی درخواست ها و نظراتتونو با دستور زیر برای ما ارسال کنید
   !feedback (your ideas and messages)
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
Create a group
ساخت گروه جدید

!createrealm [Name]
Create a realm
ساخت گروه مادر جدید

!setname [Name]
Set group name
اسم گروه را تغییر بدهید

!setabout [GroupID] [Text]
Set a group's about text
برای ان گروه توضیحاتی را تعیین کنید

!setrules [GroupID] [Text]
Set a group's rules
برای ان گروه قوانینی را تعیین کنید

!lock [GroupID] [setting]
Lock a group's setting
تنظیمات ان گروه را قفل کنید

!unlock [GroupID] [setting]
Unock a group's setting
تنظیمات ان گروه را ازاد کنید

!wholist
Get a list of members in group/realm
لیست تمامی اعضا همراه با ای دی

!who
Get a file of members in group/realm
لیست تمامی اعضا همراه با ای دی در یک فایل متنی

!type
Get group type
در مورد نقش گروه بگیرید

!kill chat [GroupID]
Kick all memebers and delete group ⛔️
حذف تمامی اعضای ان گروه

!kill realm [RealmID]
Kick all members and delete realm⛔️⛔️
حذف تمامی اعضای ان گروه مادر

!addadmin [id|username]
Promote an admin by id OR username *Sudo only
اضافه کردن ادمین 

!removeadmin [id|username]
Demote an admin by id OR username *Sudo only❗️
صلب مقام یک ادمین

!list groups
Get a list of all groups
لیست تمامی گروه های ربات

!list realms
Get a list of all realms
لیست گروه های مادر ربات

!log
Get a logfile of current group or realm
تمامی عملیات گروه 

!broadcast [text]
Send text to all groups ✉️
✉️ ارسال یک متن به صورت هم زمان برای همه گروه ها

!br [group_id] [text]
This command will send text to [group_id]✉️
ارسال یک متن برای ان گروه

You Can user both "!" & "/" for them
میتوانید از هردو کاراکتر های ! و / برای دستورات استفاده کنید


]],
    help_text = [[
TeleTitan bots Help for mods : Plugins

Banhammer : 


Help For Banhammer دستوراتی برای کنترل گروه


!Kick @UserName or ID or replay
حذف یک شخص از گروه

!Ban @UserName or ID or replay
تحریم یک شخص از گروه

!Unban @UserName
حذف تحریم یک شخص از گروه


For Admins :


!banall [ID] or replay
تحریم جهانی یک شخص

!unbanall ID
حذف تحریم جهانی یک شخص

〰〰〰〰〰〰〰〰〰〰
2. GroupManager :

!lock leave
با فعال کردن این دستور اگر کسی از گروه برود از گروه تحریم میشود

!lock tag
مجوز ندادن به اعضا از استفاده کردن از @ و # برای تگ

!creategroup "GroupName"
you can Create group with this comman
ساخت یک گروه جدید

!lock member
For locking Inviting user
برای جلوگیری از آمدن اعضای جدید

!lock bots
for Locking Bots invitation
برای جلوگیری از اضافه کرن ربات به گروه

!lock name 
To lock the group name for every bodey
قفل کردن نام گروه

!setflood
set the group flood control
تنظیم حساسیت ربات برای تشخیص اسپم

!settings
Watch group settings
نمایش تنظیمات گروه

!owner
watch group owner
نمایش ای دی مدیر اصلی گروه

!setowner user_id or replay
You can set someone to the group owner‼️
تعیین مدیر اصلی برای گروه

!modlist
Watch Group mods
نمایش لیست مدیران گروه

!lock join 
to lock joining the group by link
برای جلوگیری از وارد شدن به گروه با لینک گروه

!lock flood
lock group flood
فعال کردن تشخیص اسپم ربات

!unlock (bots-member-flood-photo-name-tag-link-join-Arabic)✅
Unlock Something
ازاد سازی موارد بالا با این دستور

!rules & !set rules [text]
TO see group rules or set rules
نمایش قوانین گروه یا تنظیم قوانین گروه

!about & !set about [text]
watch about group or set about
نمایش متنی درباره گروه یا تنظیم متنی درباره گروه

!res @username
see Username INfo
دیدن اطلاعات یک شخص

!who
Get Ids Chat
لیست ایدی های اعضای گروه

!log 
get members id 
نمایش تمامی فعالیت های انجام یافته توسط شما و یا مدیران

!all
Says every thing he knows about a group
نمایش تمامی اطلاعات ثبت شده در مورد گروه

!newlink
Changes or Makes new group link
عوض کردن لینک گروه

!link
gets The Group link
نمایش لینک گروه

!linkpv
sends the group link to the PV
ارسال لینک توسط ربات در پی وی
〰〰〰〰〰〰〰〰
Admins :


!add
to add the group as knows
مجوز دادن به ربات برای استفاده در گروه

!rem
to remove the group and be unknown
ناشناس کردن گروه برای ربات

!setgpowner (Gpid) user_id 
For Set a Owner of group from realm
تعیین مدیر اصلی برای ان گروه

!addadmin [Username]
to add a Global admin to the bot
اضافه کردن ادمین اصلی برای ربات


!removeadmin [username]
to remove an admin from global admins
برای صلب مقام یک ادمین اصلی


!plugins - [pluginName]
To Disable the plugin
برای غیر فعال کردن پلاگین 


!plugins + [pluginName]
To enable a plugins
برای فعال کردن پلاگین

!plugins ?
To reload al plugins
تازه سازی تمامی پلاگین های فعال

!plugins
Shows the list of all plugins
لیست تمامی پلاگین ها

!sms [id] (text)
To send a message to an account by his/her ID
برای فرستادن متنی توسط ربات به یک شخص
〰〰〰〰〰〰〰〰〰〰〰
3. Stats :


!stats teletitan (sudoers)✔️
To see the stats of bot
برای دیدن آمار ربات 

!stats
To see the group stats
برای دیدن آمار گروه 
〰〰〰〰〰〰〰〰
4. Feedback

!feedback (text)
To send your ideas to the Sudo
ارسال نظر و پیشنهاد شما برای مدیر اصلی ربات
〰〰〰〰〰〰〰〰〰〰〰
5. Tagall

!tagall (text)
To tags the every one and sends your message at bottom
تگ کردن همه ی اعضای گروه و نوشتن متن شما زیر تگ ها
〰〰〰〰〰〰〰〰〰
Master Admin : @REZATITAN
our channel : @TeleTitanChannel


You Can user both "!" & "/" for them
می توانید از دو کاراکتر !  و / برای دادن دستورات استفاده کنید

]]

  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
