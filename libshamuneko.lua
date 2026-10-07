local ffi = require("ffi")
local logger = require("logger")

local LS = ffi.load("plugins/koneko.koplugin/libshamuneko.so")
ffi.cdef(dofile("plugins/koneko.koplugin/libshamuneko/build/src/shamuneko_amalgamation_header.lua"))
local C = ffi.C

local libshamuneko = {
	SHAMUNEKO_FLAG_SYNCHRONOUS = 4,
}

local libshamuneko_state = { __index = {} }
ffi.metatype("shamuneko_state_t", libshamuneko_state)

local libshamuneko_module = { __index = {} }
ffi.metatype("shamuneko_module_t", libshamuneko_module)

function libshamuneko_state.__index:module_load(file)
	return LS.shamuneko_module_load(self, file)
end

function libshamuneko_module.__index:get_pages(id, index, callback)
	return LS.shamuneko_module_get_pages(self, id, index, function(results, len, ignore)
		-- flatten the results into a simple table
		local flat_results = {}
		for i=0,tonumber(len)-1 do
			flat_results[#flat_results+1] = {
				img_url = ffi.string(results[i].img_url)
			}
		end
		callback(flat_results)
		C.free(results)
	end, ffi.cast('void*', 0))
end

function libshamuneko.new(flag, callbacks)
	local funcs = ffi.new("struct shamuneko_http_funcs")

	-- bind our callbacks through
	funcs.create_session = ffi.cast("void* (*)()", function()
		-- incomplete (not super useful for us right now)
		if callbacks and callbacks.create_session then callbacks.create_session() end
		return ffi.cast('void*', 0)
	end)
	funcs.request = ffi.cast("int (*)(void *, char const*, shamuneko_request_t *)", function (data, url, internal)
		if callbacks and callbacks.request then
			-- user can call this callback when they are finished with
			--  the data (this way it could be done asynchronously)
			callbacks.request(ffi.string(url), function(data)
				LS.shamuneko_process_request(internal, C.strdup(ffi.cast("char*", data)), #data)
			end)
		end
		return 0
	end)
	funcs.destroy_session = ffi.cast("void (*)(void *)", function(nada)
		if callbacks and callbacks.destroy_session then callbacks.destroy_session(nada) end
	end)

	return LS.shamuneko_new(flag, funcs)
end

return libshamuneko
