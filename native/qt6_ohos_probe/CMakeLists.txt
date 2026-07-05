cmake_minimum_required(VERSION 3.20)
project(geonest_qt6_ohos_probe LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(QT6_PREFIX "" CACHE PATH "Staged Qt6/OHOS install prefix")

if(QT6_PREFIX)
    set(GEONEST_QT6_EFFECTIVE_PREFIX "${QT6_PREFIX}")
    if(CMAKE_OHOS_ARCH_ABI AND EXISTS "${QT6_PREFIX}/${CMAKE_OHOS_ARCH_ABI}")
        set(GEONEST_QT6_EFFECTIVE_PREFIX "${QT6_PREFIX}/${CMAKE_OHOS_ARCH_ABI}")
    elseif(OHOS_ARCH AND EXISTS "${QT6_PREFIX}/${OHOS_ARCH}")
        set(GEONEST_QT6_EFFECTIVE_PREFIX "${QT6_PREFIX}/${OHOS_ARCH}")
    endif()

    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib64/cmake")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib/cmake/Qt6")
    list(APPEND CMAKE_PREFIX_PATH "${GEONEST_QT6_EFFECTIVE_PREFIX}/lib64/cmake/Qt6")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Xml)

add_library(geonestqt6probe SHARED
    src/qt6_ohos_probe.cpp
)

target_compile_definitions(geonestqt6probe PRIVATE QT_NO_KEYWORDS)
target_link_libraries(geonestqt6probe PRIVATE Qt6::Core Qt6::Xml)

set_target_properties(geonestqt6probe PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "$ORIGIN"
)
