project(TestWindow)

include(darling_exe)

add_darling_executable(TestWindow
    AppDelegate.m
    main.m
)

target_link_libraries(TestWindow
    AppKit
    Foundation
    CoreGraphics
)
