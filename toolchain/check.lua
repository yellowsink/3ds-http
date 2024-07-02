-- import("core.project.config")
-- import("lib.detect.find_tool")

function main(toolchain)
	if not is_plat("3ds") then
		cprint("Use 3ds platform")
		return
	end

	local paths
	local devkitpro = os.getenv("DEVKITPRO")
	local devkitarm = path.join(devkitpro, "/devkitARM")
	if not os.isdir(devkitarm) then
		return false
	end

	toolchain:config_set("devkitarm", devkitarm)
	toolchain:config_set("bindir", path.join(devkitarm, "bin"))
	return true
end