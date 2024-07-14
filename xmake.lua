add_repositories("3dskit git@github.com:ys-3dskit/3dskit-repo")

add_requires("libctru ~2.3.1", "citro3d ~1.7.1", "citro2d ~1.6.0", "3dskit-dlang ~0.1.1")

includes("toolchain/*.lua")

add_rules("mode.debug", "mode.release")

target("3ds-http")
	set_kind("binary")
	set_plat("3ds")

	set_arch("arm")
	add_rules("3ds")
	set_toolchains("devkitarm")
	set_languages("c11")

	set_values("3ds.name", "3dshttp")
	set_values("3ds.description", "http download client for the 3ds")
	set_values("3ds.author", "Hazel Atkinson")

	-- TODO: this does not belong here. it NEEDS to go. xmake won't play without it.
	add_ldflags("-specs=3dsx.specs", "-g", "-march=armv6k", "-mtune=mpcore", "-mtp=soft", "-mfloat-abi=hard", {force = true})

	add_files("src/**.d")

	add_packages("libctru", "3dskit-dlang")

	-- fix imports
	add_dcflags("-Isrc", {force = true})

	set_strip("debug")
