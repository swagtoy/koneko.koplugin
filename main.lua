-- TODO: majority of these are not used
local DataStorage = require("datastorage")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")
local dump = require("dump")

local Blitbuffer = require("ffi/blitbuffer")

local Button = require("ui/widget/button")
local Geom = require("ui/geometry")
local ButtonDialog = require("ui/widget/buttondialog")
local CheckButton = require("ui/widget/checkbutton")
local ConfirmBox = require("ui/widget/confirmbox")
local ImageWidget = require("ui/widget/imagewidget")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local FrameContainer = require("ui/widget/container/framecontainer")
local TitleBar = require("ui/widget/titlebar")
local Device = require("device")
local Screen = Device.screen
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local VirtualKeyboard = require("ui/widget/virtualkeyboard")

local shamuneko = require("libshamuneko")

local logger = require("logger")
local filemanagermenu = require('apps/filemanager/filemanagermenu')

local Koneko = FrameContainer:extend {
	name = "koneko",
	fullname = ("Koneko"),

	bordersize = 0,
	padding = 0,
	margin = 0,
	background = Blitbuffer.COLOR_WHITE,
	covers_fullscreen = true,

	shamuneko = nil
}

local _first_load = false

local _shamuneko_module_name = nil
local _shamuneko_module = nil

function Koneko:init()
	--self:loadSettings()
	if not _first_load then
		self.ui.menu:registerToMainMenu(self)
	end
	_first_load = true

	self.shamuneko = shamuneko.new(shamuneko.SHAMUNEKO_FLAG_SYNCHRONOUS, {
		request = function(url, sendback)
			local http = require("socket.http")
			local socket = require("socket")
			local socketutil = require("socketutil")
			local socket_url = require("socket.url")
			local sink = {}

			local request = {
				url = url,
				method = "GET",
				sink = socketutil.table_sink(sink)
			}
			local code, headers, status = http.request(request)

			local content = table.concat(sink)

			sendback(content)
		end,
	})
	_shamuneko_module = self.shamuneko:module_load("hello")

	self.height = Screen:getHeight()
	self:setupLayout()
end

function Koneko:addToMainMenu(menu_items)
	menu_items.koneko = {
		text = self.fullname,
		sorting_hint = "tools",
		keep_menu_open = false,

		callback = function()
			UIManager:show(Koneko:new { })
		end,
	}
end

function Koneko:setupLayout()
	self[1] =
		VerticalGroup:new {
			TitleBar:new {
				title = "Koneko",
				align = "center",
				fullscreen = true,
				show_parent = self[1],

				left_icon = 'appbar.menu',
				left_icon_tap_callback = function() self:open_menu() end,

				right_icon = 'exit',
				right_icon_tap_callback = function() self:onClose() end,
			},

			self:create_button_group(),
		}
end

function Koneko:dev_set_module_name()
	local myinput
	myinput = InputDialog:new {
		title = "Set libshamuneko module name",
		input = "pepper&carrot",
		input_hint = "libshamuneko module name",
		description = "Module name to operate on for the developer menu",
		buttons = {
			{
				{
					text = "Close",
					id = "close",
					callback = function()
						UIManager:close(myinput)
					end,
				},
				{
					text = "Set",
					callback = function()
						_shamuneko_module_name = myinput:getInputText()
						_shamuneko_module = self.shamuneko:module_load(string.format("/home/swags/libshamuneko/modules/%s/main.lua", _shamuneko_module_name))
						self:open_dev_menu()
						UIManager:close(myinput)
					end,
				},
			},
		}
	}

	UIManager:show(myinput)
end

function Koneko:dev_read_series_by_id(id)
	if not _shamuneko_module then return end

	_shamuneko_module:get_pages("peppercarrot", id, function (pages)
		local buttons = {}
		for i, page in ipairs(pages) do
			buttons[#buttons + 1] = {{
				text = string.format("%d: %s", #buttons, page.img_url)
			}}
		end

		UIManager:show(ButtonDialog:new {
			buttons = buttons
		})
	end)
end

function Koneko:open_dev_menu()
	-- these were breaking on my kobos luajit when put inline... no idea why.. luajit bug?
	local smn_btn_text = (_shamuneko_module_name != nil and
	               string.format("Set module name (%s)", _shamuneko_module_name) or
	               "Set libshamuneko module name")
	local check2 = (_shamuneko_module_name != nil)
	local mydialog
	mydialog = ButtonDialog:new {
		buttons = {
			{{
				text = smn_btn_text,
				callback = function()
					UIManager:close(mydialog)
					self:dev_set_module_name()
				end,
			}},
			{{
				text = "Read series by ID",
				enabled = check2,
				callback = function()
					local myindialog
					myindialog = InputDialog:new {
						title = "Index of comic",
						input_type = "number",
						buttons = {
							{{
								text = "Read",
								is_enter_default = true,
								callback = function()
									self:dev_read_series_by_id(myindialog:getInputValue())
								end,
							}}
						}
					}
					UIManager:show(myindialog)
				end,
			}},
		}
	}
	UIManager:show(mydialog)
end

function Koneko:open_menu()
	local mybtns
	mybtns = ButtonDialog:new {
		buttons = {
			{{
					text = "Open developer menu...",
					callback = function()
						self:open_dev_menu()
						UIManager:close(mybtns)
					end
			}},

		}
	}
	UIManager:show(mybtns)
end

function Koneko:create_button_group()
	local group = HorizontalGroup:new {}
	for i, v in ipairs({'chevron.first', 'chevron.left', 1, 'chevron.right', 'chevron.last'}) do
		if v == 1 then
			group[i] = HorizontalSpan:new { width = 100, }
		else
			group[i] = Button:new {
				icon = v,
				bordersize = 0,
			}
		end
	end
	return group
end

-- errata
function Koneko:onClose()
	for i=1,20 do logger.err("CLOSING") end
	UIManager:close(self)
	--UIManager:forceRePaint()
	UIManager:setDirty(nil, "full")
	return true
end

function Koneko:registerToMainMenu(widget)
	logger.err(widget)
	for _, w in ipairs(self.registered_widgets) do
		if w == widget then
			return
		end
	end
	table.insert(self.registered_widgets, widget)
end


return Koneko
