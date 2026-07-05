cmake_minimum_required(VERSION 3.20)
project(geonest_qgis_core_probe LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(QGIS_PREFIX "" CACHE PATH "Staged QGIS install prefix containing include/qgis and lib/qgis_core")

if(NOT QGIS_PREFIX)
    message(FATAL_ERROR "Set -DQGIS_PREFIX=/path/to/staged/qgis before configuring this probe.")
endif()

list(APPEND CMAKE_PREFIX_PATH "${QGIS_PREFIX}")
list(APPEND CMAKE_PREFIX_PATH "${QGIS_PREFIX}/lib/cmake")
list(APPEND CMAKE_PREFIX_PATH "${QGIS_PREFIX}/lib64/cmake")

find_package(Qt6 COMPONENTS Core Xml QUIET)
if(Qt6_FOUND)
    set(GEONEST_QT_CORE_TARGET Qt6::Core)
    set(GEONEST_QT_XML_TARGET Qt6::Xml)
else()
    find_package(Qt5 COMPONENTS Core Xml REQUIRED)
    set(GEONEST_QT_CORE_TARGET Qt5::Core)
    set(GEONEST_QT_XML_TARGET Qt5::Xml)
endif()

find_path(QGIS_CORE_INCLUDE_DIR
    NAMES qgsapplication.h
    PATHS
        "${QGIS_PREFIX}/include/qgis"
        "${QGIS_PREFIX}/include"
    REQUIRED
)

find_library(QGIS_CORE_LIBRARY
    NAMES qgis_core libqgis_core
    PATHS
        "${QGIS_PREFIX}/lib"
        "${QGIS_PREFIX}/lib64"
    REQUIRED
)

add_executable(geonest_qgis_vector_probe
    src/qgis_core_vector_probe.cpp
)

target_include_directories(geonest_qgis_vector_probe PRIVATE
    "${QGIS_CORE_INCLUDE_DIR}"
)

target_compile_definitions(geonest_qgis_vector_probe PRIVATE
    QT_NO_KEYWORDS
)

target_link_libraries(geonest_qgis_vector_probe PRIVATE
    ${GEONEST_QT_CORE_TARGET}
    ${GEONEST_QT_XML_TARGET}
    "${QGIS_CORE_LIBRARY}"
)
