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
)
