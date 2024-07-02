toolchain("devkitarm")
	set_kind("standalone")

	local DEVKITPRO = os.getenv("DEVKITPRO")
	if not DEVKITPRO then
		DEVKITPRO = "/opt/devkitpro"
		return
	end

	set_toolset("cc", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-gcc")
	set_toolset("cxx", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-g++")
	set_toolset("ld", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-g++")
	set_toolset("sh", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-g++")
	set_toolset("ar", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-ar")
	set_toolset("strip", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-strip")
	set_toolset("objcopy", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-objcopy")
	set_toolset("ranlib", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-ranlib")
	set_toolset("as", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-gcc")

	add_defines("__3DS__", "HAVE_LIBCTRU")

	local arch = { "-march=armv6k", "-mtune=mpcore", "-mtp=soft", "-mfloat-abi=hard" }

	add_cflags("-g", "-Wall", "-O2", "-mword-relocations", "-ffunction-sections")
	add_cxflags(arch)
	--add_cxxflags({ "-frtti", "-std=gnu++11", "-fexceptions" })

	add_asflags("-g", arch)
	add_ldflags("-specs=3dsx.specs", "-g", arch)

	on_check("check")

	add_linkdirs(path.join(DEVKITPRO, "/libctru/lib") --[[, path.join(DEVKITPRO, "/portlibs/3ds/lib")]])
	add_includedirs(path.join(DEVKITPRO, "/libctru/include") --[[, path.join(DEVKITPRO, "/portlibs/3ds/include")]])

	add_links("ctru", "m")

	on_load(function(toolchain)
		--toolchain:add("defines",  "HAVE_LIBCTRU", "STBI_NO_THREAD_LOCALS")
		--toolchain:add("arch", "-march=armv6k", "-mtune=mpcore", "-mtp=soft", "-mfloat-abi=hard")

		--toolchain:add("cflags", "-g", "-Wall", "-O2", "-mword-relocations", "-ffunction-sections", {force = true})
		--toolchain:add("cxflags", "-march=armv6k", "-mtune=mpcore", "-mfloat-abi=hard", "-mtp=soft", {force = true})
		--toolchain:add("cxxflags", "-frtti", "-std=gnu++11", "-fexceptions", {force = true})

		--toolchain:add("asflags", "-g", "-march=armv6k", "-mtune=mpcore", "-mtp=soft", "-mfloat-abi=hard", {force = true})
		--toolchain:add("ldflags", "-specs=3dsx.specs", "-g", "-march=armv6k", "-mtune=mpcore", "-mfloat-abi=hard", "-mtp=soft" --[[,"-Wl,-Map,3ds-http.map"]], {force = true})

		--toolchain:add("linkdirs", path.join(DEVKITPRO, "/libctru/lib")--[[, path.join(DEVKITPRO, "/portlibs/3ds/lib")]])
		--toolchain:add("syslinks",--[[ "gcc", "c",]] "m"--[[, "3ds"]])
		--toolchain:add("links", "ctru")
	end)
toolchain_end()