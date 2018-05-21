cmake_minimum_required(VERSION 3.0)

set(LOGDATA "${CMAKE_CURRENT_BINARY_DIR}/../wrk")

set(startrev 1)

file(READ ${LOGDATA}/currev.txt in)
if("${in}" MATCHES "revision:([0-9]*)")
    set(endrev ${CMAKE_MATCH_1})
else()
    message(FATAL_ERROR "currev parse error: ${in}")
endif()

message(STATUS "startrev = ${startrev}")
message(STATUS "endrev = ${endrev}")

message(STATUS "Generate ${startrev} ... ${endrev}")

execute_process(
    COMMAND ${CMAKE_CURRENT_LIST_DIR}/runrevpar.sh
    ${startrev}
    ${endrev}
    -DLOGDATA=${LOGDATA}
    -P ${CMAKE_CURRENT_LIST_DIR}/revrunorder.cmake
    RESULT_VARIABLE rr)

if(rr)
    message(FATAL_ERROR "Revbranch err: ${rr}")
endif()
