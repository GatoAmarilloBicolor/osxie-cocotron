project(TestWindow)

include(osxie_exe)

add_osxie_executable(TestWindow
    AppDelegate.m
    main.m
)

target_link_libraries(TestWindow
    AppKit
    Foundation
    CoreGraphics
    ${CMAKE_SOURCE_DIR}/src/external/swift/libswiftCore.dylib
    ${CMAKE_SOURCE_DIR}/src/external/swift/libswiftFoundation.dylib
    ${CMAKE_SOURCE_DIR}/src/external/swift/libswiftAppKit.dylib
)

target_link_options(TestWindow PRIVATE "-rpath" "/usr/lib/swift")
