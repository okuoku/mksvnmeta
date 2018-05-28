set(LOGDATA "${CMAKE_CURRENT_BINARY_DIR}/../wrk")
set(CTXREPO "${CMAKE_CURRENT_BINARY_DIR}/ctx")
set(TMP "${CMAKE_CURRENT_BINARY_DIR}/tmp")

function(clear_tmp)
    if(IS_DIRECTORY ${TMP})
        file(REMOVE_RECURSE ${TMP})
    else()
        message(FATAL_ERROR "Huh?")
    endif()

    file(MAKE_DIRECTORY ${TMP})
endfunction()

if(EXISTS ${TMP})
    if(EXISTS ${TMP}/currev.txt)
        clear_tmp()
    else()
        message(FATAL_ERROR 
            "It seems something wrong had happened in previous run")
    endif()
else()
    file(MAKE_DIRECTORY ${TMP})
endif()




if(EXISTS ${CTXREPO}/currev.txt)
    file(READ ${CTXREPO}/currev.txt in)
    if("${in}" MATCHES "revision:([0-9]*)")
        set(startrev ${CMAKE_MATCH_1})
    else()
        message(FATAL_ERROR "currev parse error: ${in}")
    endif()
else()
    set(startrev 1)
endif()


file(READ ${LOGDATA}/currev.txt in)
if("${in}" MATCHES "revision:([0-9]*)")
    set(endrev ${CMAKE_MATCH_1})
else()
    message(FATAL_ERROR "currev parse error: ${in}")
endif()


message(STATUS "startrev = ${startrev}")
message(STATUS "endrev = ${endrev}")

set(curstartrev ${startrev})
set(curendrev -1)
while(1)
    if(${curstartrev} GREATER ${endrev})
        break()
    endif()

    # Calc curendrev
    math(EXPR curendrev "${curstartrev}+100-1")
    if(${curendrev} GREATER ${endrev})
        set(curendrev ${endrev})
    endif()

    # Run order => branchdata 
    execute_process(
        COMMAND ${CMAKE_COMMAND}
        -DSTARTREV=${curstartrev}
        -DENDREV=${curendrev}
        -DLOGDATA=${LOGDATA}
        -P ${CMAKE_CURRENT_LIST_DIR}/ctx-orderdata.cmake
        WORKING_DIRECTORY ${TMP}
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "orderdata error: ${rr}")
    endif()

    execute_process(
        COMMAND ${CMAKE_COMMAND}
        -DSTARTREV=${curstartrev}
        -DENDREV=${curendrev}
        -DLOGDATA=${LOGDATA}
        -P ${CMAKE_CURRENT_LIST_DIR}/ctx-branchdata.cmake
        WORKING_DIRECTORY ${TMP}
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "branchdata error: ${rr}")
    endif()

    # Collect order data, generate branch mapping
    set(branchq)
    foreach(b ${branchq})
    endforeach()

    # Clear tmp dir
    clear_tmp()

    math(EXPR curstartrev "${curendrev}+1")
endwhile()

# Mark as successful run
file(WRITE ${TMP}/currev.txt "revision:${endrev}")

# Register currev.txt to CTX and commit it
file(WRITE ${CTXREPO}/currev.txt "revision:${endrev}")
