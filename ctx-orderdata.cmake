cmake_minimum_required(VERSION 3.0)

set(ENV{LANG} "C.UTF8")
set(startrev ${STARTREV})
set(endrev ${ENDREV})

include(${CMAKE_CURRENT_LIST_DIR}/branchmgr.cmake)

function(make_revdir_path res rev)
    # Output {CURPATH}/order/XXXX with zero-filled
    math(EXPR yyy "${rev}%1000")
    math(EXPR xxxx "(${rev}-${yyy})/1000")
    if(${xxxx} LESS 10)
        set(xxxx "000${xxxx}")
    elseif(${xxxx} LESS 100)
        set(xxxx "00${xxxx}")
    elseif(${xxxx} LESS 1000)
        set(xxxx "0${xxxx}")
    endif()
    set(${res} "${CMAKE_CURRENT_BINARY_DIR}/order/${xxxx}" PARENT_SCOPE)
endfunction()

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

message(STATUS "startrev = ${startrev}")
message(STATUS "endrev = ${endrev}")

message(STATUS "Generating output dirs...")
set(currev ${startrev})
while(1)
    make_revdir_path(dir ${currev})
    file(MAKE_DIRECTORY ${dir})
    if(${currev} EQUAL ${endrev})
        break()
    endif()
    math(EXPR currev "${currev}+1")
endwhile()
message(STATUS "Output ${startrev} ... ${endrev}")

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
