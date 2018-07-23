macro(get_transitive_libs target out_list path_list)
  if (TARGET ${target})
    
    set(import_location "")
    set(found_repeat FALSE) 
    get_target_property(import_location ${target} IMPORTED_LOCATION)
    if(import_location AND ${import_location} IN_LIST path_list)
      set(found_repeat TRUE)
    else()
      list(INSERT ${path_list} 0 "${import_location}")
    endif()
    get_target_property(libtype ${target} TYPE)
    # If this target is a static library, get anything it depends on.
    if ("${libtype}" STREQUAL "STATIC_LIBRARY")
      if(NOT found_repeat)
        list(INSERT ${out_list} 0 "${target}")
      endif()
      get_target_property(libs ${target} LINK_LIBRARIES)
      if (libs)
        foreach(lib ${libs})   
          get_transitive_libs(${lib} ${out_list} ${path_list})
        endforeach()
      endif()
    endif()
  endif()
  # If we know the location (i.e. if it was made with CMake) then we
  # can add it to our list.
  LIST(REMOVE_DUPLICATES ${out_list})
endmacro()



function(combine_static_lib new_target target)

  set(all_libs "")
  set(path_list "")
  get_transitive_libs(${target} all_libs path_list)
  #message(FATAL_ERROR ${all_libs})
  if(APPLE)
    set(libname
      "/$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/${CMAKE_STATIC_LIBRARY_PREFIX}${new_target}${CMAKE_STATIC_LIBRARY_SUFFIX}")
  else()
     set(libname
      ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${new_target}${CMAKE_STATIC_LIBRARY_SUFFIX})   
  endif()
  if (CMAKE_CONFIGURATION_TYPES)
    list(LENGTH CMAKE_CONFIGURATION_TYPES num_configurations)
    if (${num_configurations} GREATER 1)
      if(APPLE)
        set(libname
            "/$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/${CMAKE_STATIC_LIBRARY_PREFIX}${new_target}${CMAKE_STATIC_LIBRARY_SUFFIX}")
      else()
        set(libname
            ${CMAKE_CFG_INTDIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${new_target}${CMAKE_STATIC_LIBRARY_SUFFIX})
      endif()
    endif()
  endif()

  if (MSVC)
    string(REPLACE ";" ">;$<TARGET_FILE:" temp_string "${all_libs}")
    set(lib_target_list "$<TARGET_FILE:${temp_string}>")

    add_custom_command(OUTPUT ${libname}
      DEPENDS ${all_libs}
      COMMAND lib.exe ${lib_target_list} /OUT:${libname} /NOLOGO)
  elseif(APPLE)
    string(REPLACE ";" ">;$<TARGET_FILE:" temp_string "${all_libs}")
    set(lib_target_list "$<TARGET_FILE:${temp_string}>")
    add_custom_command(OUTPUT ${libname}
      DEPENDS ${all_libs}
      COMMAND libtool -static -o ${libname} ${lib_target_list})
  else()
    string(REPLACE ";" "> \naddlib $<TARGET_FILE:" temp_string "${all_libs}")
    set(start_of_file
      "create ${libname}\naddlib $<TARGET_FILE:${temp_string}>")
    set(build_script_file "${start_of_file}\nsave\nend\n")

    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${new_target}.ar"
        CONTENT ${build_script_file}
        CONDITION 1)

    add_custom_command(OUTPUT  ${libname}
      DEPENDS ${all_libs}
      COMMAND ${CMAKE_AR} -M < ${new_target}.ar)
  endif()

  add_custom_target(${new_target}_genfile ALL
    DEPENDS ${libname})

  # CMake needs to be able to see this as another normal library,
  # so import the newly created library as an imported library,
  # and set up the dependencies on the custom target.
  add_library(${new_target} STATIC IMPORTED GLOBAL)
if(IOS)
  set_target_properties(${new_target} PROPERTIES
                      ARCHIVE_OUTPUT_DIRECTORY_DEBUG "/$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)"
                      ARCHIVE_OUTPUT_DIRECTORY_RELEASE "/$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)")
  set_target_properties(${new_target}
    PROPERTIES IMPORTED_LOCATION "/$(BUILD_DIR)$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/${libname}")
else()  
  set_target_properties(${new_target}
    PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/${libname})
endif()  
  add_dependencies(${new_target} ${new_target}_genfile)
  
endfunction()

function (getCmakeProperties)
get_cmake_property(_variableNames VARIABLES)
foreach (_variableName ${_variableNames})
    message(STATUS "${_variableName}=${${_variableName}}")
endforeach()
endfunction()


execute_process(COMMAND cmake --help-property-list OUTPUT_VARIABLE CMAKE_PROPERTY_LIST)

# Convert command output into a CMake list
STRING(REGEX REPLACE ";" "\\\\;" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
STRING(REGEX REPLACE "\n" ";" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
function(print_properties)
    message ("CMAKE_PROPERTY_LIST = ${CMAKE_PROPERTY_LIST}")
endfunction(print_properties)

function(print_target_properties tgt)
    if(NOT TARGET ${tgt})
      message("There is no target named '${tgt}'")
      return()
    endif()

    foreach (prop ${CMAKE_PROPERTY_LIST})
        string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" prop ${prop})
         
        get_property(propval TARGET ${tgt} PROPERTY ${prop} SET)
        if (propval)
            get_target_property(propval ${tgt} ${prop})
            message ("${tgt} ${prop} = ${propval}")
        endif()
    endforeach(prop)
endfunction(print_target_properties)


function(xln_auto_source_group rootName rootDir)
file(TO_CMAKE_PATH "${rootDir}" rootDir)
string(LENGTH "${rootDir}" rootDirLength)
set(sourceGroups)
foreach (fil ${ARGN})
  file(TO_CMAKE_PATH "${fil}" filePath)
  string(FIND "${filePath}" "/" rIdx REVERSE)
  if (rIdx EQUAL -1)
    message(FATAL_ERROR "Unable to locate the final forward slash in '${filePath}'!")
  endif()
  string(SUBSTRING "${filePath}" 0 ${rIdx} filePath)

  string(LENGTH "${filePath}" filePathLength)
  string(FIND "${filePath}" "${rootDir}" rIdx)
  if (rIdx EQUAL 0)
    math(EXPR filePathLength "${filePathLength} - ${rootDirLength}")
    string(SUBSTRING "${filePath}" ${rootDirLength} ${filePathLength} fileGroup)

    string(REPLACE "/" "\\" fileGroup "${fileGroup}")
    set(fileGroup "\\${rootName}${fileGroup}")

    list(FIND sourceGroups "${fileGroup}" rIdx)
    if (rIdx EQUAL -1)
      list(APPEND sourceGroups "${fileGroup}")
      source_group("${fileGroup}" REGULAR_EXPRESSION "${filePath}/[^/.]+.(cpp|h)$")
    endif()
  endif()
endforeach()
endfunction()

function(xln_auto_sources RETURN_VALUE PATTERN SOURCE_SUBDIRS)

  if ("${SOURCE_SUBDIRS}" STREQUAL "RECURSE")
    SET(PATH ".")
    if (${ARGC} EQUAL 4)
      list(GET ARGV 3 PATH)
    endif ()
  endif()

  if ("${SOURCE_SUBDIRS}" STREQUAL "RECURSE")
    unset(${RETURN_VALUE})
    file(GLOB SUBDIR_FILES "${PATH}/${PATTERN}")
    list(APPEND ${RETURN_VALUE} ${SUBDIR_FILES})

    file(GLOB subdirs RELATIVE ${PATH} ${PATH}/*)

    foreach(DIR ${subdirs})
      if (IS_DIRECTORY ${PATH}/${DIR})
        if (NOT "${DIR}" STREQUAL "CMakeFiles")
          file(GLOB_RECURSE SUBDIR_FILES "${PATH}/${DIR}/${PATTERN}")
          list(APPEND ${RETURN_VALUE} ${SUBDIR_FILES})
        endif()
      endif()
    endforeach()
  else ()
    file(GLOB ${RETURN_VALUE} "${PATTERN}")

    foreach (PATH ${SOURCE_SUBDIRS})
      file(GLOB SUBDIR_FILES "${PATH}/${PATTERN}")
      list(APPEND ${RETURN_VALUE} ${SUBDIR_FILES})
    endforeach(PATH ${SOURCE_SUBDIRS})
  endif ()

  if (${FILTER_OUT})
    list(REMOVE_ITEM ${RETURN_VALUE} ${FILTER_OUT})
  endif()

  set(${RETURN_VALUE} ${${RETURN_VALUE}} PARENT_SCOPE)
endfunction(xln_auto_sources)


function(xln_add_dependency dependency dep_path dep_output_path extra_path libname debug_libname)
  
  ##set(multiValueArgs LIBNAMES CONFIGURATIONS)
  ##cmake_parse_arguments(XLN "${multiValueArgs}" ${ARGN} )
  #if(NOT DEFINED extra_path)
  #  set(extra_path ".")
  #endif()
  if(XLN_BUILD_SOURCE OR XLN_BUILD_${dependency})
    macro (install)
    endmacro ()
    if(MSVC)
      add_subdirectory(${dep_path} ${dep_output_path}/msvc/${dependency})
    elseif(ANDROID)
      add_subdirectory(${dep_path} ${dep_output_path}/android/${dependency}/${ANDROID_ABI})
    elseif(LINUX_PC)
      add_subdirectory(${dep_path} ${dep_output_path}/linux/x64/${dependency})
    endif()
    macro (install)
    _install(${ARGV})
    endmacro(install)
  else()
    add_library(${dependency} STATIC IMPORTED)
    set_property(TARGET ${dependency} APPEND PROPERTY IMPORTED_CONFIGURATIONS Debug)
    if(MSVC)
      set_target_properties(${dependency} PROPERTIES
          IMPORTED_LOCATION_DEBUG ${dep_output_path}/msvc/${dependency}/${extra_path}/Debug/${debug_libname}.lib
          IMPORTED_LOCATION_RELEASE ${dep_output_path}/msvc/${dependency}/${extra_path}/Release/${libname}.lib
      )
    elseif(ANDROID)
        set_target_properties(${dependency} PROPERTIES
        IMPORTED_LOCATION_DEBUG ${dep_output_path}/android/${dependency}/${ANDROID_ABI}/${extra_path}/lib${debug_libname}.a
        IMPORTED_LOCATION_RELEASE ${dep_output_path}/android/${dependency}/${ANDROID_ABI}/${extra_path}/lib${libname}.a
      )
    elseif(LINUX_PC)
       set_target_properties(${dependency} PROPERTIES
          IMPORTED_LOCATION_DEBUG ${dep_output_path}/linux/x64/${dependency}/${extra_path}/lib${debug_libname}.a
          IMPORTED_LOCATION_RELEASE ${dep_output_path}/linux/x64/${dependency}/${extra_path}/lib${libname}.a
      )
    endif()
  endif()
  
endfunction()

function(xln_add_binary_dependency project dependency dep_binary_path extra_path libname debug_libname)
  
  add_library(${dependency} STATIC IMPORTED)
  set_property(TARGET ${dependency} APPEND PROPERTY IMPORTED_CONFIGURATIONS Debug)
  if(MSVC)
    set_target_properties(${dependency} PROPERTIES
        IMPORTED_LOCATION_DEBUG ${dep_binary_path}/msvc/${project}/${extra_path}/Debug/${debug_libname}.lib
        IMPORTED_LOCATION_RELEASE ${dep_binary_path}/msvc/${project}/${extra_path}/Release/${libname}.lib
    )
  elseif(ANDROID)
      set_target_properties(${dependency} PROPERTIES
      IMPORTED_LOCATION_DEBUG ${dep_binary_path}/android/${project}/${ANDROID_ABI}/${extra_path}/lib${debug_libname}.a
      IMPORTED_LOCATION_RELEASE ${dep_binary_path}/android/${project}/${ANDROID_ABI}/${extra_path}/lib${libname}.a
    )
  elseif(LINUX_PC)
    set_target_properties(${dependency} PROPERTIES
      IMPORTED_LOCATION_DEBUG ${dep_binary_path}/linux/x64/${project}/${extra_path}/lib${debug_libname}.a
      IMPORTED_LOCATION_RELEASE ${dep_binary_path}/linux/x64/${project}/${extra_path}/lib${libname}.a
   )
  endif()

endfunction()
