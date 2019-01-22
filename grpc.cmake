function(xln_protobuf_generate_grpc_cpp)
  set(oneValueArgs  PACKAGE OUTPUT_PATH INCLUDE_PATH)
  set(multiValueArgs PROTO)

  cmake_parse_arguments(xln_protobuf_generate_grpc_cpp "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  
  if(NOT ARGN)
    message(SEND_ERROR "Error: PROTOBUF_GENERATE_GRPC_CPP() called without any proto files")
    return()
  endif()
  if("${xln_protobuf_generate_grpc_cpp_INCLUDE_PATH}" STREQUAL "")
    set(_protobuf_include_path -I .)
  else()
    set(_protobuf_include_path -I . -I ${xln_protobuf_generate_grpc_cpp_INCLUDE_PATH})
  endif()

  set(_tmpSrc "")
  set(_tmpHeader "")
  
  foreach(FIL ${xln_protobuf_generate_grpc_cpp_PROTO})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)
    file(RELATIVE_PATH REL_FIL ${CMAKE_CURRENT_SOURCE_DIR} ${ABS_FIL})
    get_filename_component(REL_DIR ${REL_FIL} DIRECTORY)
    set(RELFIL_WE "${xln_protobuf_generate_grpc_cpp_OUTPUT_PATH}/${FIL_WE}")

    add_custom_command(
      OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.grpc.pb.cc"
             "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.grpc.pb.h"
             "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}_mock.grpc.pb.h"
             "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.pb.cc"
             "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.pb.h"
      COMMAND ${Protobuf_PROTOC_EXECUTABLE}
      ARGS --grpc_out=${CMAKE_CURRENT_SOURCE_DIR}/${xln_protobuf_generate_grpc_cpp_OUTPUT_PATH}
           --cpp_out=${CMAKE_CURRENT_SOURCE_DIR}/${xln_protobuf_generate_grpc_cpp_OUTPUT_PATH}
           --plugin=protoc-gen-grpc=$<TARGET_FILE:grpc_cpp_plugin>
           ${_protobuf_include_path}
           ${REL_FIL}
      DEPENDS ${ABS_FIL} ${Protobuf_PROTOC_EXECUTABLE} $<TARGET_FILE:grpc_cpp_plugin>
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      COMMENT "Running gRPC C++ protocol buffer compiler on ${FIL}"
      VERBATIM)
    list(APPEND _tmpSrc  "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.pb.cc" "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.grpc.pb.cc")
    list(APPEND _tmpHeader  "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.grpc.pb.h" "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}_mock.grpc.pb.h" "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.pb.h")

    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.grpc.pb.cc" "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.grpc.pb.h"  "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}_mock.grpc.pb.h" "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.pb.cc" "${CMAKE_CURRENT_SOURCE_DIR}/${RELFIL_WE}.pb.h" PROPERTIES GENERATED TRUE)
  endforeach()

  message(WARNING ${_tmpSrc})
  set(${xln_protobuf_generate_grpc_cpp_PACKAGE}_src ${_tmpSrc} PARENT_SCOPE)
  set(${xln_protobuf_generate_grpc_cpp_PACKAGE}_header ${_tmpHeader} PARENT_SCOPE)
  
endfunction()

if(MSVC)
    add_definitions(-D_WIN32_WINNT=0x600)
endif()