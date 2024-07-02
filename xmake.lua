includes("toolchain/*.lua")

add_rules("mode.debug", "mode.release")

target("3ds-http")
	set_kind("binary")
	if not is_plat("3ds") then
		return
	end

	set_arch("arm")
	add_rules("3ds")
	set_toolchains("devkitarm")
	set_languages("c11")

	set_values("3ds.name", "3dshttp")
	set_values("3ds.description", "http download client for the 3ds")
	set_values("3ds.author", "Hazel Atkinson")

	add_files("src/**.c")

	set_strip("debug")