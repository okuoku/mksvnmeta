cmake_minimum_required(VERSION 3.0)

set(LOGDATA "${CMAKE_CURRENT_BINARY_DIR}/../wrk")

set(ENV{LANG} "C.UTF8")
set(startrev 1)

include(${CMAKE_CURRENT_LIST_DIR}/branchmgr.cmake)

function(xml_xslt res xslt input)
    execute_process(
        COMMAND xsltproc ${xslt} ${input}
        OUTPUT_VARIABLE out
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "xsltproc: ${rr}")
    endif()
    set(${res} "${out}" PARENT_SCOPE)
endfunction()

file(READ ${LOGDATA}/currev.txt in)
if("${in}" MATCHES "revision:([0-9]*)")
    set(endrev ${CMAKE_MATCH_1})
else()
    message(FATAL_ERROR "currev parse error: ${in}")
endif()

message(STATUS "startrev = ${startrev}")
message(STATUS "endrev = ${endrev}")

execute_process(
    COMMAND ${CMAKE_CURRENT_LIST_DIR}/runrevpar.sh
    ${startrev}
    ${endrev}
    -DLOGDATA=${LOGDATA}
    -P ${CMAKE_CURRENT_LIST_DIR}/revbranch.cmake
    RESULT_VARIABLE rr)

if(rr)
    message(FATAL_ERROR "Revbranch err: ${rr}")
endif()
