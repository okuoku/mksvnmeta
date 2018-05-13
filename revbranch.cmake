#
# INPUTs:
#  LOGDATA: Full path to logdata dir
#  REV: Revision to process

set(BRANCHDATA ${CMAKE_CURRENT_BINARY_DIR})

cmake_minimum_required(VERSION 3.0)

set(ENV{LANG} "C.UTF8")

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

function(make_revfile_path res prefix rev)
    # Output ${prefix}/XXXX/YYY.log.xml with zero-filled
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
    set(${res} "${prefix}/${xxxx}/${yyy}.log.xml" PARENT_SCOPE)
endfunction()

function(path_includes_p out base pth)
    string(LENGTH ${base} len)
    string(SUBSTRING ${pth} 0 ${len} ck)
    if(${ck} STREQUAL ${base})
        set(${out} ON PARENT_SCOPE)
    else()
        set(${out} OFF PARENT_SCOPE)
    endif()
endfunction()

file(STRINGS ${LOGDATA}/branches.txt lines)

branch_init()
branch_read(${lines})

make_revfile_path(pth ${LOGDATA} ${REV})

xml_xslt(res ${CMAKE_CURRENT_LIST_DIR}/parselog2.xml ${pth})
string(REGEX REPLACE "\n" ";" res "${res}")

branch_get_active_paths(paths ${REV})
set(affected)
set(unhandled)

foreach(p ${res})
    set(cur)
    set(is_branch)
    foreach(a ${paths})
        if(${p} STREQUAL ${a})
            set(is_branch ON)
            break()
        endif()
        if(${a} STREQUAL "/")
            # Special handling for /
            path_includes_p(out ${a} ${p})
        else()
            path_includes_p(out ${a}/ ${p})
        endif()
        if(${out})
            #message(STATUS "Map: ${a} <= ${p}")
            set(cur ${a})
            break()
        endif()
    endforeach()
    if(is_branch)
        # message(STATUS "Branchmod: ${p}")
        list(APPEND affected "${p}")
    elseif(cur)
        list(APPEND affected "${cur}")
    else()
        message(STATUS "Unhandled(${REV}): ${p}")
    endif()
endforeach()

