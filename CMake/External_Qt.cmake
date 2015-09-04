# The Qt external project for fletch

option(BUILD_QT_WEBKIT "Should the Qt Webkit module be built?" FALSE)
if(BUILD_QT_WEBKIT)
  set(Qt_args_webkit "-webkit")
else()
  set(Qt_args_webkit "-no-webkit")
endif()

if (CMAKE_BUILD_TYPE)
  string(TOLOWER "${CMAKE_BUILD_TYPE}" QT_BUILD_TYPE)
  if(QT_BUILD_TYPE STREQUAL "debug")
    set(Qt_args_build_type "-debug")
  else()
    set(Qt_args_build_type "-release")
  endif()
else()
  # Multi-configuration projects. Build debug AND release to be safe
  set(Qt_args_build_type "-debug-and-release")
endif()

# JPEG
add_package_dependency(
  PACKAGE Qt
  PACKAGE_DEPENDENCY libjpeg-turbo
  PACKAGE_DEPENDENCY_ALIAS JPEG
  OPTIONAL
  EMBEDDED
)
if(Qt_WITH_libjpeg-turbo)
  set(Qt_args_jpeg
    -system-libjpeg
    -I ${fletch_BUILD_INSTALL_PREFIX}/include
    -L ${fletch_BUILD_INSTALL_PREFIX}/lib
    )
endif()

# ZLib
add_package_dependency(
  PACKAGE Qt
  PACKAGE_DEPENDENCY ZLib
  PACKAGE_DEPENDENCY_ALIAS ZLIB
  OPTIONAL
  EMBEDDED
)
if(Qt_WITH_ZLib)
  set(Qt_args_zlib
    -system-zlib
    -I ${fletch_BUILD_INSTALL_PREFIX}/include
    -L ${fletch_BUILD_INSTALL_PREFIX}/lib
    )
endif()

# PNG
add_package_dependency(
  PACKAGE Qt
  PACKAGE_DEPENDENCY PNG
  OPTIONAL
  EMBEDDED
)
if(Qt_WITH_PNG)
  set(Qt_args_PNG
    -system-libpng
    -I ${fletch_BUILD_INSTALL_PREFIX}/include
    -L ${fletch_BUILD_INSTALL_PREFIX}/lib
    )
endif()

if(WIN32)
  include(External_jom) # since this is only used by Qt on windows include here
  list(APPEND Qt_DEPENDS jom)

  set(JOM_EXE "${fletch_BUILD_PREFIX}/src/jom/jom.exe")
  if(Qt_WITH_ZLib)
    # Jom needs the path to zlib.dll to build correctly with zlib
    set(JOM_ADDITIONAL_PATH ${fletch_BUILD_INSTALL_PREFIX}/bin)
  endif()

  set(Qt_build ${fletch_BUILD_PREFIX}/src/Qt-build/BuildQt.bat)
  configure_file(
    ${fletch_SOURCE_DIR}/Patches/Qt/BuildQt.bat.in
    ${Qt_build}
    )

  set(Qt_install_cmd ${JOM_EXE} install)
  set(Qt_configure configure.exe)
  if(MSVC12)
    #We have some trouble determining the correct platform for VS2013
    list(APPEND Qt_args_arch -platform win32-msvc2013)
  endif()
else()
  option(BUILD_QT_JAVASCRIPTJIT "Should the Qt Javascript JIT module be built?" FALSE)
  if(BUILD_QT_JAVASCRIPTJIT)
    set(Qt_args_javascriptjit "-javascript-jit")
  else()
    set(Qt_args_javascriptjit "-no-javascript-jit")
  endif()

  Fletch_Require_Make()
  set(Qt_build ${MAKE_EXECUTABLE})
  set(Qt_install_cmd ${MAKE_EXECUTABLE} install)
  set(Qt_configure ./configure)
  set(Qt_args_other -no-cups -optimized-qmake)

  if(APPLE)
    #Qt does not allow pure debug builds with frameworks.
    #So far it only appears to cause an issue with APPLE,
    #Until we decide framework is important, disable it.
    #For reference, see http://qt-project.org/doc/qt-4.8/debug.html
    set(Qt_args_framework "-no-framework")
    set(Qt_args_arch -arch x86_64 -cocoa)
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # Create a spec file for gcc44 on RHEL5
    if(CMAKE_C_COMPILER MATCHES "gcc44" OR CMAKE_CXX_COMPILER MATCHES "g\\+\\+44")
      list(APPEND Qt_args_arch -platform linux-g++44)
    endif()

    # Disable AVX support if the kernel is too old
    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.([0-9]+)?" KERNEL_VERSION "${CMAKE_SYSTEM_VERSION}")
    if(KERNEL_VERSION VERSION_LESS "2.6.30")
      list(APPEND Qt_args_arch -no-avx)
    endif()
  endif()
endif()

set(Qt_configure ${Qt_configure}
  -prefix ${fletch_BUILD_INSTALL_PREFIX}
  -docdir ${fletch_BUILD_INSTALL_PREFIX}/share/doc/qt4-${Qt_version}
  -datadir ${fletch_BUILD_INSTALL_PREFIX}/lib/qt4
  -plugindir ${fletch_BUILD_INSTALL_PREFIX}/lib/qt4/plugins
  -importdir ${fletch_BUILD_INSTALL_PREFIX}/lib/qt4/imports
  -opensource -confirm-license -fast
  -nomake examples -nomake demos -nomake translations -nomake linguist
  ${Qt_args_build_type}
  ${Qt_args_webkit}
  ${Qt_args_javascriptjit}
  ${Qt_args_arch}
  ${Qt_args_jpeg}
  ${Qt_args_zlib}
  ${Qt_args_PNG}
  ${Qt_args_other}
  ${Qt_args_framework}
  )

ExternalProject_Add(Qt
  DEPENDS ${Qt_DEPENDS}
  URL ${Qt_file}
  URL_MD5 ${Qt_md5}
  PREFIX ${fletch_BUILD_PREFIX}
  DOWNLOAD_DIR ${fletch_DOWNLOAD_DIR}
  INSTALL_DIR ${fletch_BUILD_INSTALL_PREFIX}
  BUILD_IN_SOURCE 1
  PATCH_COMMAND ${CMAKE_COMMAND}
  -DQt_CFLAGS:STRING=${CMAKE_C_FLAGS}
  -DQt_CXXFLAGS:STRING=${CMAKE_CXX_FLAGS}
  -DQt_patch:PATH=${fletch_SOURCE_DIR}/Patches/Qt
  -DQt_source:PATH=${fletch_BUILD_PREFIX}/src/Qt
  -DQt_install:PATH=${fletch_BUILD_INSTALL_PREFIX}
  -P ${fletch_SOURCE_DIR}/Patches/Qt/Patch.cmake
  CONFIGURE_COMMAND ${Qt_configure}
  BUILD_COMMAND ${Qt_build}
  INSTALL_COMMAND ${Qt_install_cmd}
  STEP_TARGETS download
  )
add_dependencies(Download Qt-download)

set(QT_QMAKE_EXECUTABLE ${fletch_BUILD_INSTALL_PREFIX}/bin/qmake
  CACHE FILEPATH "" FORCE )

file(APPEND ${fletch_CONFIG_INPUT} "
########################################
# Qt
########################################
set(QT_QMAKE_EXECUTABLE @QT_QMAKE_EXECUTABLE@)
")

