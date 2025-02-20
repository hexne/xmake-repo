package("dartsim")

    set_homepage("https://dartsim.github.io/")
    set_description("Dynamic Animation and Robotics Toolkit")
    set_license("BSD-2-Clause")

    add_urls("https://github.com/dartsim/dart/archive/refs/tags/$(version).tar.gz",
             "https://github.com/dartsim/dart.git")
    add_versions("v6.14.5", "eb89cc01f4f48c399b055d462d8ecd2a3f846f825a35ffc67f259186b362e136")
    add_versions("v6.14.4", "f5fc7f5cb1269cc127a1ff69be26247b9f3617ce04ff1c80c0f3f6abc7d9ab70")
    add_versions("v6.13.0", "4da3ff8cee056252a558b05625a5ff29b21e71f2995e6d7f789abbf6261895f7")
    add_versions("v6.14.2", "6bbaf452f8182b97bf22adeab6cc7f3dc1cd2733358543131fa130e07c0860fc")

    add_configs("dartpy", {description = "Build dartpy interface.", default = false, type = "boolean"})
    local configdeps = {bullet3 = "Bullet",
                        freeglut = "GLUT",
                        nlopt = "NLOPT",
                        ode = "ODE",
                        openscenegraph = "OpenSceneGraph",
                        tinyxml2 = "tinyxml2",
                        urdfdom = "urdfdom",
                        spdlog = "spdlog"}
    for config, dep in pairs(configdeps) do
        add_configs(config, {description = "Enable " .. config .. " support.", default = false, type = "boolean"})
    end
    if is_plat("windows") then
        add_configs("shared", {description = "Build shared library.", default = false, type = "boolean", readonly = true})
        add_cxxflags("/permissive-")
        add_syslinks("user32")
        -- https://gitlab.kitware.com/cmake/cmake/-/issues/20222
        set_policy("package.cmake_generator.ninja", false)
    end

    add_deps("cmake")
    add_deps("assimp", "libccd", "eigen", "fcl", "octomap", "fmt")
    on_load("windows|x64", "linux", "macosx", function (package)
        for config, dep in pairs(configdeps) do
            if package:config(config) then
                package:add("deps", config)
            end
        end
        if package:config("dartpy") then
            package:add("deps", "python 3.x")
        end
        if package:config("openscenegraph") then
            package:add("deps", "imgui")
        end
    end)

    on_install("windows|x64", "linux", "macosx", function (package)
        io.replace("CMakeLists.txt", "/GL", "", {plain = true})
        io.replace("CMakeLists.txt", "if(TARGET dart)", "if(FALSE)", {plain = true})
        io.replace("dart/CMakeLists.txt", "/LTCG", "", {plain = true})
        io.replace("python/CMakeLists.txt", "add_subdirectory(tests)", "", {plain = true})
        io.replace("python/CMakeLists.txt", "add_subdirectory(examples)", "", {plain = true})
        io.replace("python/CMakeLists.txt", "add_subdirectory(tutorials)", "", {plain = true})
        io.replace("cmake/DARTFindDependencies.cmake", "dart_check_required_package(assimp \"assimp\")", "dart_check_required_package(assimp \"assimp\")\nfind_package(ZLIB)\ntarget_link_libraries(assimp INTERFACE ZLIB::ZLIB)", {plain = true})
        io.replace("cmake/DARTFindDependencies.cmake", "dart_check_required_package(fcl \"fcl\")", "dart_check_required_package(fcl \"fcl\")\ntarget_link_libraries(fcl INTERFACE ccd)", {plain = true})
        io.replace("cmake/DARTFindDependencies.cmake", "check_cxx_source_compiles%(.-\".-\".-(ASSIMP.-DEFINED)%)", "set(%1 1)")
        local configs = {
            "-DDART_USE_SYSTEM_IMGUI=ON",
            "-DDART_SKIP_lz4=ON",
            "-DDART_SKIP_flann=ON",
            "-DDART_SKIP_IPOPT=ON",
            "-DDART_SKIP_pagmo=ON",
            "-DDART_SKIP_DOXYGEN=ON",
            "-DDART_TREAT_WARNINGS_AS_ERRORS=OFF",
        }
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        for config, dep in pairs(configdeps) do
            table.insert(configs, "-DDART_SKIP_" .. dep .. "=" .. (package:config(config) and "OFF" or "ON"))
        end
        if package:is_plat("windows") then
            table.insert(configs, "-DDART_RUNTIME_LIBRARY=" .. (package:config("vs_runtime"):startswith("MT") and "/MT" or "/MD"))
        end
        table.insert(configs, "-DDART_BUILD_DARTPY=" .. (package:config("dartpy") and "ON" or "OFF"))
        table.insert(configs, "-DDART_BUILD_GUI_OSG=" .. (package:config("openscenegraph") and "ON" or "OFF"))
        import("package.tools.cmake").install(package, configs)
        local suffix = package:is_debug() and "d" or ""
        for _, lib in ipairs({"dart-collision-bullet", "dart-collision-ode", "dart-gui-osg", "dart-gui", "dart-optimizer-ipopt", "dart-optimizer-nlopt", "dart-optimizer-pagmo", "dart-utils-urdf", "dart-utils", "dart", "dart-external-odelcpsolver", "dart-external-lodepng"}) do
            package:add("links", lib .. suffix)
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <dart/dart.hpp>
            void test() {
                dart::simulation::WorldPtr world = dart::simulation::World::create();
            }
        ]]}, {configs = {languages = "c++17"}}))
    end)
