function (set_sanitizer TARGET)
    if(LINUX_PC)
        # Set compile- and link-flags for target.
        set_property(TARGET ${TARGET} APPEND_STRING
            PROPERTY COMPILE_FLAGS_DEBUG "-fsanitize=address")
        set_property(TARGET ${TARGET} APPEND_STRING
            PROPERTY LINK_FLAGS_DEBUG "-fsanitize=address")
    
    endif()
endfunction ()
