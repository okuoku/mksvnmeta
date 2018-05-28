cmake_minimum_required(VERSION 3.0)

set(startrev ${STARTREV})
set(endrev ${ENDREV})

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
