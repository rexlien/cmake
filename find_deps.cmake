if(LINUX_PC)

set(BOOST_LIBRARYDIR "/usr/lib/x86_64-linux-gnu")
find_package(Boost 1.55.0 MODULE
  COMPONENTS
    context
    chrono
    date_time
    filesystem
    program_options
    regex
    system
    thread
  REQUIRED
)
find_package(OpenSSL MODULE REQUIRED)

endif()