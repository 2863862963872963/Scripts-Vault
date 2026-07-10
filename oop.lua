local Safe = {}
Safe.__index = Safe

local cloneref = cloneref or function(obj) return obj end
local getgenv = getgenv or function() return _G end

local RefCache = setmetatable({}, {__mode = "k"})

local function SafeRef(obj)
	if not obj then return nil end
	if RefCache[obj] then return RefCache[obj] end
	local ref = cloneref(obj)
	RefCache[obj] = ref
	return ref
end

function Safe:Get(Parent, Property, Default)
	if not Parent then return Default end
	local s, r = pcall(function() return Parent[Property] end)
	return (s and r ~= nil) and SafeRef(r) or Default
end

function Safe:Find(Parent, Name, Recursive)
	if not Parent then return nil end
	local s, c = pcall(function() return Parent:FindFirstChild(Name, Recursive or false) end)
	return s and SafeRef(c) or nil
end

function Safe:Wait(Parent, Name, Timeout)
	if not Parent then return nil end
	local s, c = pcall(function() return Parent:WaitForChild(Name, Timeout or 5) end)
	return s and SafeRef(c) or nil
end

function Safe:FindClass(Parent, ClassName)
	if not Parent then return nil end
	local s, c = pcall(function() return Parent:FindFirstChildOfClass(ClassName) end)
	return s and SafeRef(c) or nil
end

function Safe:FindAncestor(Parent, Name)
	if not Parent then return nil end
	local s, a = pcall(function() return Parent:FindFirstAncestor(Name) end)
	return s and SafeRef(a) or nil
end

function Safe:GetService(Name)
	local s, svc = pcall(function() return game:GetService(Name) end)
	return s and SafeRef(svc) or nil
end

function Safe:Wrap(Inst)
	if typeof(Inst) ~= "Instance" then return Inst end
	return setmetatable({}, {
		__index = function(_, k)
			local v = Safe:Get(Inst, k)
			if typeof(v) == "function" then
				return function(_, ...) 
					local s, r = pcall(v, Inst, ...) 
					return s and SafeRef(r) or nil 
				end
			end
			return v
		end,
		__newindex = function(_, k, v)
			pcall(function() Inst[k] = v end)
		end,
		__tostring = function() return tostring(Inst) end
	})
end

function Safe:Tbl(tbl)
	if not tbl or typeof(tbl) ~= "table" then return {} end
	return tbl
end

function Safe:TblGet(tbl, key, def)
	if not tbl then return def end
	return tbl[key] ~= nil and tbl[key] or def
end

function Safe:TblSet(tbl, key, val)
	if tbl then tbl[key] = val end
	return tbl
end

function Safe:TblMerge(t1, t2)
	if not t1 then return t2 or {} end
	if not t2 then return t1 end
	for k, v in pairs(t2) do t1[k] = v end
	return t1
end

function Safe:TblDeepCopy(obj)
	if typeof(obj) ~= "table" then return obj end
	local res = {}
	for k, v in pairs(obj) do
		res[k] = Safe:TblDeepCopy(v)
	end
	return res
end

function Safe:TblPrint(tbl, indent)
	indent = indent or 0
	local prefix = string.rep("  ", indent)
	if not tbl or typeof(tbl) ~= "table" then
		print(prefix .. tostring(tbl))
		return
	end
	print(prefix .. "{")
	for k, v in pairs(tbl) do
		local keyStr = typeof(k) == "string" and '"'..k..'"' or tostring(k)
		if typeof(v) == "table" then
			print(prefix .. "  " .. keyStr .. " = ")
			Safe:TblPrint(v, indent + 1)
		else
			print(prefix .. "  " .. keyStr .. " = " .. tostring(v))
		end
	end
	print(prefix .. "}")
end

function Safe:Str(str)
	return tostring(str or "")
end

function Safe:Trim(s)
	s = Safe:Str(s)
	return s:match("^%s*(.-)%s*$")
end

function Safe:Split(s, sep)
	s = Safe:Str(s)
	local res = {}
	for part in s:gmatch("([^" .. (sep or "%s") .. "]+)") do
		table.insert(res, part)
	end
	return res
end

function Safe:Format(fmt, ...)
	return string.format(fmt or "", ...)
end

function Safe:StrCapitalize(s)
	s = Safe:Str(s)
	return s:gsub("^%l", string.upper)
end

function Safe:Color(text, color)
	text = Safe:Str(text)
	if typeof(color) == "string" then
		return string.format('<font color="%s">%s</font>', color, text)
	elseif typeof(color) == "Color3" then
		return string.format('<font color="rgb(%d,%d,%d)">%s</font>', 
			math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255), text)
	end
	return text
end

function Safe:ToJson(tbl)
	if not tbl then return "{}" end
	local function encode(v)
		if typeof(v) == "string" then
			return '"' .. v:gsub('"', '\\"') .. '"'
		elseif typeof(v) == "table" then
			local parts = {}
			for k, val in pairs(v) do
				table.insert(parts, '"'..tostring(k)..'"'..":"..encode(val))
			end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif typeof(v) == "number" or typeof(v) == "boolean" then
			return tostring(v)
		end
		return '"' .. tostring(v) .. '"'
	end
	return encode(tbl)
end

function Safe:FromJson(str)
	str = Safe:Str(str):gsub("%s+", "")
	local tbl = {}
	for key, value in str:gmatch('"([^"]+)":([^,{}]+)') do
		value = value:gsub('"', "")
		tbl[key] = tonumber(value) or value
	end
	return tbl
end

function Safe:Num(n)
	return tonumber(n) or 0
end

function Safe:Round(n, dec)
	n = Safe:Num(n)
	local mult = 10 ^ (dec or 0)
	return math.floor(n * mult + 0.5) / mult
end

function Safe:Clamp(n, min, max)
	return math.max(min or 0, math.min(max or 1, Safe:Num(n)))
end

function Safe:Random(min, max)
	return math.random(Safe:Num(min), Safe:Num(max))
end

function Safe:Init()
	local svcs = {"Players","Workspace","ReplicatedStorage","Lighting","RunService","UserInputService","TweenService","HttpService"}
	for _, n in ipairs(svcs) do
		getgenv()["Safe" .. n] = self:GetService(n)
	end
end

setmetatable(Safe, {
	__call = function(self)
		local inst = setmetatable({}, self)
		inst:Init()
		return inst
	end
})

return Safe
