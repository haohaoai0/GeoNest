cmake_minimum_required(VERSION 3.5.0)
project(geonest_gis_native)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
set(GEONEST_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../../..)
option(GEONEST_USE_QGIS_CORE "Build GeoNest GIS core with QGIS Core vector backend" OFF)
option(GEONEST_USE_GDAL "Build GeoNest GIS core with GDAL/OGR vector backend" OFF)
set(QGIS_PREFIX "" CACHE PATH "Staged QGIS install prefix used when GEONEST_USE_QGIS_CORE is ON")
set(GDAL_PREFIX "" CACHE PATH "Staged GDAL install prefix used when GEONEST_USE_GDAL is ON")
set(QT6_PREFIX "" CACHE PATH "Staged Qt6 install prefix used when GEONEST_USE_QGIS_CORE is ON")

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
    ${GEONEST_ROOT_PATH}/native/gis_core/include
    ${GEONEST_ROOT_PATH}/native/napi_bridge/include
)

if(GEONEST_USE_QGIS_CORE AND GEONEST_USE_GDAL)
    message(FATAL_ERROR "Choose only one GIS backend: GEONEST_USE_QGIS_CORE or GEONEST_USE_GDAL")
endif()

if(GEONEST_USE_QGIS_CORE)
    if(NOT QGIS_PREFIX)
        message(FATAL_ERROR "GEONEST_USE_QGIS_CORE=ON requires -DQGIS_PREFIX=/path/to/staged/qgis")
    endif()

    set(GEONEST_OHOS_ABI "")
    foreach(GEONEST_ABI_VAR CMAKE_OHOS_ARCH_ABI OHOS_ARCH)
        if(DEFINED ${GEONEST_ABI_VAR} AND NOT "${${GEONEST_ABI_VAR}}" STREQUAL "")
            set(GEONEST_OHOS_ABI "${${GEONEST_ABI_VAR}}")
            break()
        endif()
        get_property(GEONEST_ABI_CACHE_SET CACHE ${GEONEST_ABI_VAR} PROPERTY VALUE SET)
        if(GEONEST_ABI_CACHE_SET)
            get_property(GEONEST_ABI_CACHE_VALUE CACHE ${GEONEST_ABI_VAR} PROPERTY VALUE)
            if(NOT "${GEONEST_ABI_CACHE_VALUE}" STREQUAL "")
                set(GEONEST_OHOS_ABI "${GEONEST_ABI_CACHE_VALUE}")
                break()
            endif()
        endif()
    endforeach()

    set(GEONEST_QGIS_EFFECTIVE_PREFIX "${QGIS_PREFIX}")
    if(GEONEST_OHOS_ABI AND EXISTS "${QGIS_PREFIX}/${GEONEST_OHOS_ABI}")
        set(GEONEST_QGIS_EFFECTIVE_PREFIX "${QGIS_PREFIX}/${GEONEST_OHOS_ABI}")
    endif()

    set(GEONEST_QT6_EFFECTIVE_PREFIX "${QT6_PREFIX}")
    if(QT6_PREFIX)
        if(GEONEST_OHOS_ABI AND EXISTS "${QT6_PREFIX}/${GEONEST_OHOS_ABI}")
            set(GEONEST_QT6_EFFECTIVE_PREFIX "${QT6_PREFIX}/${GEONEST_OHOS_ABI}")
        endif()
    endif()

    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib/cmake")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib64/cmake")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib/cmake/Qt6")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib64/cmake/Qt6")
    if(QT6_PREFIX)
        list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}")
        list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake")
        list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib64/cmake")
        list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6")
        list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib64/cmake/Qt6")
        if(EXISTS "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6/Qt6Config.cmake")
            set(Qt6_DIR "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6")
        endif()
        if(EXISTS "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6Core/Qt6CoreConfig.cmake")
            set(Qt6Core_DIR "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6Core")
        endif()
        if(EXISTS "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6Xml/Qt6XmlConfig.cmake")
            set(Qt6Xml_DIR "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6Xml")
        endif()
        foreach(GEONEST_QT_COMPONENT Gui Widgets Network Sql Concurrent Svg PrintSupport Core5Compat DBus)
            if(EXISTS "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6${GEONEST_QT_COMPONENT}/Qt6${GEONEST_QT_COMPONENT}Config.cmake")
                set(Qt6${GEONEST_QT_COMPONENT}_DIR "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6${GEONEST_QT_COMPONENT}")
            endif()
        endforeach()
    endif()

    set(QT_ALLOW_MISSING_TOOLS_PACKAGES ON)
    find_package(Qt6 COMPONENTS Core Gui Widgets Network Xml Sql Concurrent Svg PrintSupport Core5Compat DBus QUIET)
    if(Qt6_FOUND)
        set(GEONEST_QT_TARGETS
            Qt6::Core
            Qt6::Gui
            Qt6::Widgets
            Qt6::Network
            Qt6::Xml
            Qt6::Sql
            Qt6::Concurrent
            Qt6::Svg
            Qt6::PrintSupport
            Qt6::Core5Compat
            Qt6::DBus
        )
    else()
        find_package(Qt5 COMPONENTS Core Gui Widgets Network Xml Sql Concurrent Svg PrintSupport REQUIRED)
        set(GEONEST_QT_TARGETS
            Qt5::Core
            Qt5::Gui
            Qt5::Widgets
            Qt5::Network
            Qt5::Xml
            Qt5::Sql
            Qt5::Concurrent
            Qt5::Svg
            Qt5::PrintSupport
        )
    endif()

    find_path(QGIS_CORE_INCLUDE_DIR
        NAMES qgsapplication.h
        PATHS
            "${GEONEST_QGIS_EFFECTIVE_PREFIX}/include/qgis"
            "${GEONEST_QGIS_EFFECTIVE_PREFIX}/include"
        NO_CMAKE_FIND_ROOT_PATH
        REQUIRED
    )

    find_library(QGIS_CORE_LIBRARY
        NAMES qgis_core libqgis_core
        PATHS
            "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib"
            "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib64"
        NO_CMAKE_FIND_ROOT_PATH
        REQUIRED
    )

    set(GEONEST_QGIS_PLUGIN_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib/qgis/plugins")
    if(EXISTS "${GEONEST_QGIS_EFFECTIVE_PREFIX}/plugins")
        set(GEONEST_QGIS_PLUGIN_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/plugins")
    elseif(EXISTS "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib")
        set(GEONEST_QGIS_PLUGIN_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib")
    endif()

    file(TO_CMAKE_PATH "${GEONEST_QGIS_EFFECTIVE_PREFIX}" GEONEST_QGIS_PREFIX_NORMALIZED)
    file(TO_CMAKE_PATH "${GEONEST_QGIS_PLUGIN_PATH}" GEONEST_QGIS_PLUGIN_PATH_NORMALIZED)
    set(GEONEST_GIS_CORE_SOURCE ${GEONEST_ROOT_PATH}/native/gis_core/src/geonest_gis_core_qgis.cpp)
elseif(GEONEST_USE_GDAL)
    if(NOT GDAL_PREFIX)
        message(FATAL_ERROR "GEONEST_USE_GDAL=ON requires -DGDAL_PREFIX=/path/to/staged/gdal")
    endif()

    set(GEONEST_GDAL_EFFECTIVE_PREFIX "${GDAL_PREFIX}")
    if(CMAKE_OHOS_ARCH_ABI AND EXISTS "${GDAL_PREFIX}/${CMAKE_OHOS_ARCH_ABI}")
        set(GEONEST_GDAL_EFFECTIVE_PREFIX "${GDAL_PREFIX}/${CMAKE_OHOS_ARCH_ABI}")
    elseif(OHOS_ARCH AND EXISTS "${GDAL_PREFIX}/${OHOS_ARCH}")
        set(GEONEST_GDAL_EFFECTIVE_PREFIX "${GDAL_PREFIX}/${OHOS_ARCH}")
    endif()

    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_GDAL_EFFECTIVE_PREFIX}")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/cmake")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/cmake/gdal")

    set(GDAL_INCLUDE_DIR "${GEONEST_GDAL_EFFECTIVE_PREFIX}/include")
    set(GDAL_LIBRARY "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/libgdal.so")
    if(NOT EXISTS "${GDAL_INCLUDE_DIR}/gdal.h")
        message(FATAL_ERROR "GDAL header not found: ${GDAL_INCLUDE_DIR}/gdal.h")
    endif()
    if(NOT EXISTS "${GDAL_LIBRARY}")
        message(FATAL_ERROR "GDAL library not found: ${GDAL_LIBRARY}")
    endif()

    set(GEONEST_GIS_CORE_SOURCE ${GEONEST_ROOT_PATH}/native/gis_core/src/geonest_gis_core_gdal.cpp)
else()
    set(GEONEST_GIS_CORE_SOURCE ${GEONEST_ROOT_PATH}/native/gis_core/src/geonest_gis_core.cpp)
endif()

add_library(geonestgis SHARED
    ${GEONEST_GIS_CORE_SOURCE}
    ${GEONEST_ROOT_PATH}/native/napi_bridge/src/geonest_napi_bridge.cpp
)

target_link_libraries(geonestgis PUBLIC libace_napi.z.so)

if(GEONEST_USE_QGIS_CORE)
    target_include_directories(geonestgis PRIVATE
        "${QGIS_CORE_INCLUDE_DIR}"
        "${GEONEST_QGIS_EFFECTIVE_PREFIX}/include"
    )
    target_compile_definitions(geonestgis PRIVATE
        GEONEST_QGIS_PREFIX="${GEONEST_QGIS_PREFIX_NORMALIZED}"
        GEONEST_QGIS_PLUGIN_PATH="${GEONEST_QGIS_PLUGIN_PATH_NORMALIZED}"
    )
    target_link_libraries(geonestgis PUBLIC
        ${GEONEST_QT_TARGETS}
        "${QGIS_CORE_LIBRARY}"
    )

    file(GLOB GEONEST_QGIS_PROVIDER_LIBS
        "${GEONEST_QGIS_PLUGIN_PATH}/*.so"
        "${GEONEST_QGIS_PLUGIN_PATH}/*.dll"
        "${GEONEST_QGIS_PLUGIN_PATH}/*.dylib"
    )
    foreach(GEONEST_QGIS_PROVIDER_LIB ${GEONEST_QGIS_PROVIDER_LIBS})
        add_custom_command(TARGET geonestgis POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:geonestgis>/qgis/plugins"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${GEONEST_QGIS_PROVIDER_LIB}"
                "$<TARGET_FILE_DIR:geonestgis>/qgis/plugins"
        )
    endforeach()

    file(GLOB GEONEST_QGIS_RUNTIME_LIBS
        "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib/lib*.so"
        "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib/lib*.so.*"
        "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib64/lib*.so"
        "${GEONEST_QGIS_EFFECTIVE_PREFIX}/lib64/lib*.so.*"
    )
    foreach(GEONEST_QGIS_RUNTIME_LIB ${GEONEST_QGIS_RUNTIME_LIBS})
        add_custom_command(TARGET geonestgis POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${GEONEST_QGIS_RUNTIME_LIB}"
                "$<TARGET_FILE_DIR:geonestgis>"
        )
    endforeach()

    if(QT6_PREFIX)
        file(GLOB GEONEST_QT6_RUNTIME_LIBS
            "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/libQt6*.so"
            "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/libQt6*.so.*"
            "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib64/libQt6*.so"
            "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib64/libQt6*.so.*"
        )
        foreach(GEONEST_QT6_RUNTIME_LIB ${GEONEST_QT6_RUNTIME_LIBS})
            add_custom_command(TARGET geonestgis POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${GEONEST_QT6_RUNTIME_LIB}"
                    "$<TARGET_FILE_DIR:geonestgis>"
            )
        endforeach()

        if(EXISTS "${GEONEST_QT6_EFFECTIVE_PREFIX}/plugins/platforms")
            add_custom_command(TARGET geonestgis POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory
                    "$<TARGET_FILE_DIR:geonestgis>/platforms"
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                    "${GEONEST_QT6_EFFECTIVE_PREFIX}/plugins/platforms"
                    "$<TARGET_FILE_DIR:geonestgis>/platforms"
            )
        endif()
    endif()

    if(EXISTS "${GEONEST_QGIS_EFFECTIVE_PREFIX}/share")
        add_custom_command(TARGET geonestgis POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:geonestgis>/qgis"
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${GEONEST_QGIS_EFFECTIVE_PREFIX}/share"
                "$<TARGET_FILE_DIR:geonestgis>/qgis/share"
        )
    endif()
endif()

if(GEONEST_USE_GDAL)
    target_include_directories(geonestgis PRIVATE "${GDAL_INCLUDE_DIR}")
    target_link_libraries(geonestgis PUBLIC "${GDAL_LIBRARY}")
    set_target_properties(geonestgis PROPERTIES
        BUILD_WITH_INSTALL_RPATH TRUE
        INSTALL_RPATH "$ORIGIN"
    )

    file(GLOB GEONEST_GDAL_RUNTIME_LIBS
        "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/libgdal.so*"
        "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/libgeos.so*"
        "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/libgeos_c.so*"
        "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/libproj.so*"
        "${GEONEST_GDAL_EFFECTIVE_PREFIX}/lib/libsqlite3.so*"
    )
    foreach(GEONEST_GDAL_RUNTIME_LIB ${GEONEST_GDAL_RUNTIME_LIBS})
        add_custom_command(TARGET geonestgis POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${GEONEST_GDAL_RUNTIME_LIB}"
                "$<TARGET_FILE_DIR:geonestgis>"
        )
    endforeach()
endif()
