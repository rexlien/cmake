macro(xln_build_app APP_EXE)
    add_custom_command(TARGET ${APP_EXE} PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/asset $<TARGET_FILE_DIR:${APP_EXE}>/App/asset)

    if(MSVC)
      add_custom_command ( TARGET ${APP_EXE} POST_BUILD 
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:pthread> 
        $<TARGET_FILE_DIR:${APP_EXE}> 
      )
      ##TODO: don't know why VS throws pthread.lib not found error. and there's no pthread.lib set in the link commands.
      SET(CMAKE_EXE_LINKER_FLAGS /NODEFAULTLIB:\"pthread.lib\") 
    endif()

endmacro()