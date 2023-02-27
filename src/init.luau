--!strict
--[=[
	@class OutputUtil
]=]

local OutputUtil = {}
local Method: {[string]: Method} = {}

local ACTION_PREFIX = "%s %s:"

local ERROR_INVALID_METHOD = "%q is not a valid method"

local ACTION_FAILED = {name = "ACTION_FAILED"; message = "Action %q failed to run!"}
local ACTION_OVERWRITTEN = {name = "ACTION_OVERWRITTEN"; message = "Actions %q was overwritten"}
local ACTION_RESERVED = {name = "ACTION_RESERVED"; message = "Action %q is reserved, unable to set"}

local ACTION_INVALID_OBJECT = {name = "ACTION_INVALID_OBJECT"; message = "Action %q is not valid, table expected got %s"}
local ACTION_INVALID_METHOD = {name = "ACTION_INVALID_METHOD", message = "Action %q must contain a method, got %s"}
local ACTION_INVALID_TYPE = {name = "ACTION_INVALID_TYPE", message = "Action %q has an invalid type, got %s"}
local ACTION_INVALID_ICON = {name = "ACTION_INVALID_ICON", message = "Action %q has an invalid icon, got %s"}

local TYPE: {[string]: ActionType} = {
	ACTION = "ACTION";
	ALERT = "ALERT";
	WARN = "WARN";
	BUG = "BUG";
	ERROR = "ERROR";
	UNDEFINED = "UNDEFINED";
}

local ICON: {[string]: Emoji} = {
	ACTION = "👍";
	ALERT = "🛎️";
	WARN = "🚨";
	BUG = "🐛";
	ERROR = "💥";
	UNDEFINED = "🔬";
}

local _loadedActions: {[string]: Action} = {}
local _methodCallbacks: {[ActionType]: MethodCallback} = {}


--[=[
	@ignore
	@private

	@param unformattedString string
	@return string

	We use this to ensure that action names are case-insensitive
	when loading / calling.
]=]
local function formatString(unformattedString: string): string
	return string.upper(unformattedString)
end

--[=[
	@ignore
	@private

	@param actionIcon Emoji
	@param actionName ActionName
	@return ActionInfo

	Returns the action prefix
]=]
local function getActionMessage(actionIcon: Emoji, actionName: ActionName): ActionInfo
	return ACTION_PREFIX:format(actionIcon, actionName)
end

--[=[
	@ignore
	@private

	@param icon Emoji
	@param name ActionName
	@param action Action?
	@param method ExecuteMethod
	@param ... any

	Runs the action
]=]
local function execute(icon: Emoji, name: ActionName, action: Action?, method: ExecuteMethod, ...: any)
	local message = getActionMessage(icon, name)
	local payload = table.pack(...)

	local success, response = pcall(function()
		if action and action.method then
			return table.pack(action.method(unpack(payload)))
		end
		return payload
	end)
	if not success then
		return Method.ERROR(ACTION_FAILED.name, nil, ACTION_FAILED.message:format(name), response)
	end

	method(message, response, name)
end

--[=[
	@ignore
	@private

	@param actionName ActionName
	@param ... any
]=]
local function runAction(actionName: ActionName, ...: any)
	-- run an undefined action if action name is not a string
	if type(actionName) ~= "string" then
		return Method.UNDEFINED(actionName, ...)
	end

	local formattedName = formatString(actionName)

	-- run default action if need be
	if Method[formattedName] then
		return Method[formattedName](formattedName, nil, ...)
	end

	-- check to see if the action is loaded
	local action = _loadedActions[formattedName]
	if action then
		if action.type then
			local formattedType = formatString(action.type)
			if Method[formattedType] then
				return Method[formattedType](formattedName, action, ...)
			end
		end
		return Method.ACTION(formattedName, action, ...)
	end

	Method.UNDEFINED(actionName, ...)
end


--[=[
	@ignore
	@private
	@class ActionMethods
]=]

--[=[
	@within ActionMethods
	@ignore
	@private

	@param actionName ActionName
	@param action Action?
	@param ... any
]=]
function Method.ACTION(actionName: ActionName, action: Action?, ...: any)
	local icon = if action and action.icon then action.icon else ICON.ACTION
	execute(icon, actionName, action, function(message: ActionInfo, response: {any})
		if _methodCallbacks[TYPE.ACTION] then
			_methodCallbacks[TYPE.ACTION](actionName, unpack(response))
		end
		print(message, unpack(response))
	end, ...)
end

--[=[
	@within ActionMethods
	@ignore
	@private

	@param actionName ActionName
	@param action Action?
	@param ... any
]=]
function Method.ALERT(actionName: ActionName, action: Action?, ...: any)
	local icon = if action and action.icon then action.icon else ICON.ALERT
	execute(icon, actionName, action, function(message: ActionInfo, response: {any})
		if _methodCallbacks[TYPE.ALERT] then
			_methodCallbacks[TYPE.ALERT](actionName, unpack(response))
		end
		warn(message, unpack(response))
	end, ...)
end

--[=[
	@within ActionMethods
	@ignore
	@private

	@param actionName ActionName
	@param action Action?
	@param ... any
]=]
function Method.WARN(actionName: ActionName, action: Action?, ...: any)
	execute(ICON.WARN, actionName, action, function(message: ActionInfo, response: {any})
		if _methodCallbacks[TYPE.WARN] then
			_methodCallbacks[TYPE.WARN](actionName, unpack(response))
		end
		warn(message, unpack(response))
	end, ...)
end

--[=[
	@within ActionMethods
	@ignore
	@private

	@param actionName ActionName
	@param action Action?
	@param ... any
]=]
function Method.BUG(actionName: ActionName, action: Action?, ...: any)
	execute(ICON.BUG, actionName, action, function(message: ActionInfo, response: {any})
		if _methodCallbacks[TYPE.BUG] then
			_methodCallbacks[TYPE.BUG](actionName, unpack(response))
		end
		warn(message, unpack(response))
	end, ...)
end

--[=[
	@within ActionMethods
	@ignore
	@private

	@param actionName ActionName
	@param action Action?
	@param ... any
]=]
function Method.ERROR(actionName: ActionName, action: Action?, ...: any)
	execute(ICON.ERROR, actionName, action, function(message: ActionInfo, response: {any})
		if _methodCallbacks[TYPE.ERROR] then
			_methodCallbacks[TYPE.ERROR](actionName, unpack(response))
		end
		error(message .. " " .. table.concat(response, " "))
	end, ...)
end

--[=[
	@within ActionMethods
	@ignore
	@private

	@param actionName ActionName
	@param action Action?
	@param ... any
]=]
function Method.UNDEFINED(...: any)
	execute(ICON.UNDEFINED, TYPE.UNDEFINED, nil, function(message: ActionInfo, response: {any}, actionName: ActionName)
		if _methodCallbacks[TYPE.UNDEFINED] then
			_methodCallbacks[TYPE.UNDEFINED](actionName, unpack(response))
		end
		warn(message, unpack(response))
	end, ...)
end


--[=[
	@param acitonName ActionName
	@param action Action
]=]
function OutputUtil.loadAction(actionName: ActionName, action: Action)
	local formattedName = formatString(actionName)

	-- ensure we don't overwrite a reserved action
	if Method[formattedName] then
		Method.ERROR(ACTION_RESERVED.name, nil, ACTION_RESERVED.message:format(actionName))
		return
	end

	-- ensure the action is a table
	if type(action) ~= "table" then
		Method.ERROR(ACTION_INVALID_OBJECT.name, nil, ACTION_INVALID_OBJECT.message:format(actionName, type(action)))
		return
	end

	-- ensure the action has a method
	if type(action.method) ~= "function" then
		Method.ERROR(ACTION_INVALID_METHOD.name, nil, ACTION_INVALID_METHOD.message:format(actionName, type(action.method)))
		return
	end

	-- ensure that the action type is valid (if provided)
	if action.type then
		local invalidType

		-- ensure that the type is actually valid
		if type(action.type) ~= "string" then
			invalidType = type(action.type)
		elseif not Method[formatString(action.type)] then
			invalidType = action.type
		end

		if invalidType then
			Method.ERROR(ACTION_INVALID_TYPE.name, nil, ACTION_INVALID_TYPE.message:format(actionName, invalidType))
			return
		end
	end

	-- ensure the icon (if set) is valid
	if action.icon and (type(action.icon) ~= "string") then
		Method.ERROR(ACTION_INVALID_ICON.name, nil, ACTION_INVALID_ICON.message:format(type(action.icon)))
		return
	end

	-- explain we overwote an action
	if _loadedActions[formattedName] and not action.hideOverwriteWarning then
		Method.WARN(ACTION_OVERWRITTEN.name, nil, ACTION_OVERWRITTEN.message:format(actionName))
	end

	_loadedActions[formattedName] = action
end

--[=[
	@param actions {[string]: Action}

	This allows us to load a dictionary of actions, where the index
	will be used as the action name.
]=]
function OutputUtil.loadActions(actions: {[string]: Action})
	for actionName, action in actions do
		OutputUtil.loadAction(actionName, action)
	end
end

--[=[
	@param method ActionType
	@param callback MethodCallback

	This sets the callback to the method, so whenever and action
	is run with that method, it runs the callback.
]=]
function OutputUtil.registerMethodCallback(method: ActionType, callback: MethodCallback)
	local formattedMethod = formatString(method)
	assert(Method[formattedMethod], ERROR_INVALID_METHOD:format(method))
	_methodCallbacks[formattedMethod :: ActionType] = callback
end

--[=[
	@param actionName ActionName | any
	@param ... any

	If actionName is a registered action, uses that, and passes ...
	Otherwise runs an internal function.
]=]
function OutputUtil.run(actionName: ActionName | any, ...: any)
	runAction(actionName, ...)
end



--// Types

--[=[
	@type Emoji string

	An icon that will be used by an action, (it doesn't **have** to be an emoji).
]=]
type Emoji = string

--[=[
	@type ActionType "ACTION"|"ALERT"|"WARN"|"BUG"|"ERROR"|"UNDEFINED"

	This is generally what kind of action it should be, or what level
	to display the message at.

	* ACTION — The default, akin to `print()`
	* ALERT — Not quite a warn, but more of a high-priority action
	* WARN — Used when something unexpected happened, akin to `warn()`
	* BUG — Helpful for when we know there's something wrong, alias for warn
	* ERROR — An error, akin to `error()`
	* UNDEFINED — This is used for when an action is not loaded
]=]
type ActionType = "ACTION"|"ALERT"|"WARN"|"BUG"|"ERROR"|"UNDEFINED"

--[=[
	@type ActionName ActionType|string

	Name of a loaded action
]=]
type ActionName = ActionType|string

--[=[
	@type ActionMethod (...any) -> (...any)

	The method for an action, it can take whatever values it needs
	and return anything (as long as it can be printed).
]=]
type ActionMethod = (...any) -> (...any)

--[=[
	@interface Action
	.method ActionMethod
	.type ActionType? -- what level the action should be ran at, defaults to `ACTION`
	.icon Emoji? -- use a custom icon for the action, defaults to the icon of `.ActionType`
	.hideOverwriteWarning boolean? -- if true, will hide a warning if the action overwrites another
]=]
type Action = {
	method: ActionMethod;
	type: ActionType?;
	icon: Emoji?;
	hideOverwriteWarning: boolean?;
}

--[=[
	@type ActionInfo string

	This is the string that will be printed first, it includes
	the icon and the name of the action. `👍 ACTION_NAME:`
]=]
type ActionInfo = string

--[=[
	@ignore
	@private
	@type ExecuteMethod (ActionInfo, {any}, ActionName) -> ()
]=]
type ExecuteMethod = (ActionInfo, {any}, ActionName) -> ()

--[=[
	@ignore
	@private
	@type Method (string, Action?, ...any) -> ()
]=]
type Method = (string, Action?, ...any) -> ()

--[=[
	@type MethodCallback (ActionName, ...any) -> ()

	This is used to add some external functionality to an action method
	such as logging to an external database when an error occurs.
]=]
type MethodCallback = (ActionName, ...any) -> ()



return table.freeze(setmetatable(OutputUtil, {
	__call = function(_, ...: any)
		return OutputUtil.run(...)
	end
}))