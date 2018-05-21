# INPUTs:
#  REV: Revision number

cmake_minimum_required(VERSION 3.0)

function(make_revdata_path res suffix)
    # Output {CURPATH}/order/XXXX/YYY.{suffix} with zero-filled
    set(rev ${REV})
    math(EXPR yyy "${rev}%1000")
    math(EXPR xxxx "(${rev}-${yyy})/1000")
    if(${xxxx} LESS 10)
        set(xxxx "000${xxxx}")
    elseif(${xxxx} LESS 100)
        set(xxxx "00${xxxx}")
    elseif(${xxxx} LESS 1000)
        set(xxxx "0${xxxx}")
    endif()
    if(${yyy} LESS 10)
        set(yyy "00${yyy}")
    elseif(${yyy} LESS 100)
        set(yyy "0${yyy}")
    endif()
    set(${res} "${CMAKE_CURRENT_BINARY_DIR}/order/${xxxx}/${yyy}.${suffix}" PARENT_SCOPE)
endfunction()

make_revdata_path(affected_path affected.txt)
if(EXISTS ${affected_path})
    file(STRINGS ${affected_path} affected)

    set(idx 1)
    foreach(l ${affected})
        execute_process(
            COMMAND ${CMAKE_COMMAND}
            -DREV=${REV}
            -DIDX=${idx}
            -DDIR=${l}
            -P ${CMAKE_CURRENT_LIST_DIR}/revgen.cmake
            RESULT_VARIABLE rr)
        if(rr)
            message(FATAL_ERROR "Failed(${REV} ${l} ${idx}): ${rr}")
        endif()
        math(EXPR idx "${idx}+1")
    endforeach()
else()
    message(STATUS "Skip ${REV}.")
endif()
