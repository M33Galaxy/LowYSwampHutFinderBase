cmake_minimum_required(VERSION 3.16)
project(LowYSwampHutFinderBase C)

# ---------------------------------------------------------------------------
# LowYSwampHutFinderBase —— LowYSwampHut 的完整 C 内核（阶段 1 + 阶段 2）。
#
# 本仓库**独立可构建**，不依赖 Java 源码树：
#   LowYSwampHutFinderBase_core     静态内核库（唯一实现；CLI 与 JNI 都链它）
#   LowYSwampHutFinderBase-cli      CLI（scan / hut / selftest）—— 可独立分发
#   LowYSwampHutFinderBase_jni      JNI 桥（→ project.NativePhase1 / NativePhase2）
#
# 独立构建 CLI（不需要 JAVA_HOME）：
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DLYSH_JNI=OFF
#   cmake --build build --target LowYSwampHutFinderBase-cli
#   build\bin\LowYSwampHutFinderBase-cli.exe scan --seed <long> --out hits.txt
#
# 同时构建 JNI 库（需要 JAVA_HOME 指向 JDK 17+，包含 include\jni.h）：
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build build
#   产物：build\bin\LowYSwampHutFinderBase-cli.exe / LowYSwampHutFinderBase.dll
#
# 主仓库（LowYSwampHut）通过 Gradle 子工程调用本目录的 CMake 构建，并把
# LowYSwampHutFinderBase.dll 嵌进可执行 jar（/native/LowYSwampHutFinderBase.dll）。
# JNI 函数名仍是 Java_project_*（Java 包名/类名未变），改的只是动态库文件名。
# ---------------------------------------------------------------------------

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# ---------------------------------------------------------------------------
# 逐位一致的硬性要求：
#   必须禁止 FP contraction / 重结合。gcc/clang 用 -ffp-contract=off，
#   MSVC 用默认的 /fp:precise（绝不可用 /fp:fast）。
#   -O3 -mavx2 不影响结果（已实测），但任何 fast-math 都会破坏一致性。
# ---------------------------------------------------------------------------
if(MSVC)
  # /source-charset:utf-8 必需：源码注释是 UTF-8 中文；MSVC 默认按系统 ANSI
  # 解码时会吞换行，导致后面的代码静默消失。
  add_compile_options(/W4 /fp:precise /source-charset:utf-8)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
else()
  add_compile_options(-Wall -Wextra -O3 -ffp-contract=off)
  if(NOT APPLE)
    add_compile_options(-mavx2)
  endif()
  # LTO：让 lysh_dblnoise_sample_y0 能跨编译单元内联进扫描循环。
  # -ffp-contract=off 必须同时出现在【编译】和【链接】阶段 —— LTO 的代码生成发生在链接期。
  option(LYSH_LTO "Enable interprocedural optimization" ON)
  if(LYSH_LTO)
    add_compile_options(-flto)
    add_link_options(-flto -ffp-contract=off)
  endif()
endif()

# ---------------------------------------------------------------------------
# 内核静态库
# ---------------------------------------------------------------------------
add_library(LowYSwampHutFinderBase_core STATIC
  src/rng.c
  src/noise.c
  src/structure.c
  src/climate.c
  src/caves.c
  src/phase1.c
  src/biome.c
  src/spline.c
  src/terrain.c
  src/column_top.c
  src/density.c
  src/interp_noise.c
  src/aquifer.c
  src/carver.c
  src/phase2.c
  src/eval.c
  src/search.c
)
target_include_directories(LowYSwampHutFinderBase_core PUBLIC src)

if(NOT WIN32)
  find_package(Threads REQUIRED)
  target_link_libraries(LowYSwampHutFinderBase_core PUBLIC m Threads::Threads)
endif()

# ---------------------------------------------------------------------------
# 独立 CLI（筛选程序本体：scan / hut / selftest）
#   --out <file> 把通过阶段 2 的结果按 /tp x y z 写入 txt（每行一条）。
# ---------------------------------------------------------------------------
option(LYSH_BUILD_CLI "Build the standalone LowYSwampHutFinderBase CLI" ON)
if(LYSH_BUILD_CLI)
  add_executable(LowYSwampHutFinderBase-cli src/main.c)
  target_link_libraries(LowYSwampHutFinderBase-cli PRIVATE LowYSwampHutFinderBase_core)
  set_target_properties(LowYSwampHutFinderBase-cli PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  )
  if(MINGW)
    # 独立 exe：静态链接 libgcc / winpthread，复制到其他 Windows 机器即可运行。
    target_link_options(LowYSwampHutFinderBase-cli PRIVATE -static -static-libgcc)
  endif()
endif()

# ---------------------------------------------------------------------------
# JNI 壳：把阶段 1 + 阶段 2 暴露给 Java GUI
#   （project.NativePhase1 / project.NativePhase2）
# 用 JAVA_HOME 定位 jni.h；找不到就跳过（CLI 仍然可用）。
# ---------------------------------------------------------------------------
option(LYSH_JNI "Build the JNI bridge (needs JAVA_HOME)" ON)
if(LYSH_JNI)
  if(NOT JAVA_HOME)
    set(JAVA_HOME "$ENV{JAVA_HOME}")
  endif()
  find_path(JNI_INCLUDE_DIR jni.h
    HINTS
      "${JAVA_HOME}/include"
      "$ENV{JAVA_HOME}/include"
      "C:/Program Files/Java/jdk-17/include"
      "C:/Program Files/Java/jdk-21/include"
      "C:/Program Files/Eclipse Adoptium/jdk-17/include"
      "C:/Program Files/Eclipse Adoptium/jdk-21/include"
    NO_DEFAULT_PATH)
  if(JNI_INCLUDE_DIR)
    add_library(LowYSwampHutFinderBase_jni SHARED src/jni_bridge.c)
    target_link_libraries(LowYSwampHutFinderBase_jni PRIVATE LowYSwampHutFinderBase_core)
    target_include_directories(LowYSwampHutFinderBase_jni PRIVATE "${JNI_INCLUDE_DIR}")
    if(WIN32)
      target_include_directories(LowYSwampHutFinderBase_jni PRIVATE "${JNI_INCLUDE_DIR}/win32")
    elseif(APPLE)
      target_include_directories(LowYSwampHutFinderBase_jni PRIVATE "${JNI_INCLUDE_DIR}/darwin")
    else()
      target_include_directories(LowYSwampHutFinderBase_jni PRIVATE "${JNI_INCLUDE_DIR}/linux")
    endif()
    # 输出名固定为 LowYSwampHutFinderBase（Windows 下即 LowYSwampHutFinderBase.dll）。
    # Java 侧 NativePhase1 按这个名字查找/加载；JNI 符号仍是 Java_project_*。
    set_target_properties(LowYSwampHutFinderBase_jni PROPERTIES
      PREFIX ""
      OUTPUT_NAME "LowYSwampHutFinderBase"
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )
    if(MINGW)
      # Keep the JNI DLL independent of the MSYS2 runtime DLLs (it still uses
      # the Windows UCRT, which is part of Windows 10/11).
      target_link_options(LowYSwampHutFinderBase_jni PRIVATE -static -static-libgcc)
    endif()
    message(STATUS "LowYSwampHutFinderBase: JNI bridge enabled (jni.h at ${JNI_INCLUDE_DIR})")
  else()
    message(STATUS "LowYSwampHutFinderBase: JNI bridge skipped (set JAVA_HOME to enable)")
  endif()
endif()

include(GNUInstallDirs)
if(TARGET LowYSwampHutFinderBase-cli)
  install(TARGETS LowYSwampHutFinderBase-cli
          RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()
if(TARGET LowYSwampHutFinderBase_jni)
  install(TARGETS LowYSwampHutFinderBase_jni
          RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
          LIBRARY DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()

message(STATUS "LowYSwampHutFinderBase: build type = ${CMAKE_BUILD_TYPE}")
message(STATUS "LowYSwampHutFinderBase: targets = core, LowYSwampHutFinderBase-cli, LowYSwampHutFinderBase_jni")
