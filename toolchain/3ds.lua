local DEVKITPRO = os.getenv("DEVKITPRO")
if not DEVKITPRO then
	DEVKITPRO = "/opt/devkitpro"
	return
end

local DKP_TOOLS = path.join(DEVKITPRO, "/tools/bin")

rule("3ds")
	on_config(function(target)
		target:set("toolchains", "devkitarm")
	end)

	after_build(function(target)
		if not target:kind() == "binary" then
			print("plat 3ds only works with binary targets")
			return
		end

		local _3dsxtool = path.join(DKP_TOOLS, "3dsxtool")

		local smdhtool = path.join(DKP_TOOLS, "smdhtool")

		local name = target:values("3ds.name")
		name = name or io.popen("pwd"):read() --"a"

		local author = target:values("3ds.author")
		author = author or "Unspecified Author"

		local description = target:values("3ds.description")
		description = description or "Built with devkitARM & libctru"

		local icon = target:values("3ds.icon")
		icon = icon or path.join(DEVKITPRO, "/libctru/default_icon.png")

		local romfsdir = target:values("3ds.romfs")

		cprint("${color.build.target}Generating smdh metadata")

		local smdhfile = path.absolute(path.join(target:targetdir(), name .. ".smdh"))

		local smdh_args = { "--create", name, description, author, icon, smdhfile }

		vprint(smdhtool, table.unpack(smdh_args))
		local outdata, errdata = os.iorunv(smdhtool, smdh_args)
		vprint(outdata)
		assert(errdata, errdata)

		local target_file = target:targetfile()
		local file_3dsx = target_file .. ".3dsx"

		cprint("${color.build.target}Generating 3dsx file")

		local _3dsxtool_args = { target_file, file_3dsx, "--smdh=".. smdhfile }

		if romfsdir ~= nil and romfsdir ~= "" then
			table.insert(_3dsxtool_args, "--romfs=" .. romfsdir)
		end

		vprint(_3dsxtool, table.unpack(_3dsxtool_args))
		outdata, errdata = os.iorunv(_3dsxtool, _3dsxtool_args)
		vprint(outdata)
		assert(errdata, errdata)

	end)

	--[[on_run(function(target)
		if not target:kind() == "binary" then
			return
		end

		import("core.base.option")
		import("core.project.config")

		if(os.isexec("Ryujinx")) then
			ryujinx = "Ryujinx"
		elseif(os.isexec("ryujinx")) then
			ryujinx = "ryujinx"
		else
			cprint("${color.build.target}Please install Ryujinx first")
			ryujinx = "ryujinx"
		end

		local target_file = target:targetfile()
		local executable = target_file .. ".nro"

		os.run(ryujinx, {executable})
	end)]]