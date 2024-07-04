-- devkitarm, but with system LDC to allow D code to target the 3DS
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

	set_toolset("dc", "ldc2")
	set_toolset("dcld", DEVKITPRO .. "/devkitARM/bin/" .. "arm-none-eabi-g++")

	add_defines("__3DS__", "HAVE_LIBCTRU")

	local arch = { "-march=armv6k", "-mtune=mpcore", "-mtp=soft", "-mfloat-abi=hard" }

	add_cflags("-g", "-Wall", "-O2", "-mword-relocations", "-ffunction-sections")
	add_cxflags(arch)
	--add_cxxflags({ "-frtti", "-std=gnu++11", "-fexceptions" })
	add_dcflags("-mtriple=arm-freestanding-eabihf", "-float-abi=hard", "-mcpu=mpcore", "-mattr=armv6k", "-betterC")

	add_asflags("-g", arch)
	add_ldflags("-specs=3dsx.specs", "-g", arch)

	on_check("check")

	-- this is handled by the xmake package manager now, no need for system libctru :)
	--add_linkdirs(path.join(DEVKITPRO, "/libctru/lib") --[[, path.join(DEVKITPRO, "/portlibs/3ds/lib")]])
	--add_includedirs(path.join(DEVKITPRO, "/libctru/include") --[[, path.join(DEVKITPRO, "/portlibs/3ds/include")]])

	add_links("m")
