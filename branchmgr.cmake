
#
#
# Branch Mgr:
#
#   branches : LIST for all available branch roots
#   branch_<root>_regions : branch regions
#   branchregion_r<startrev>_<root>_start : startrev
#   branchregion_r<startrev>_<root>_end   : endrev
#   branchregion_r<startrev>_<root>_from  : source branch


function(branch_dump out)
    set(accs)
    set(res)
    foreach(e ${branches})
        set(acc "${e}")
        foreach(p ${branch_${e}_regions})
            set(start ${${p}_start})
            if(${p}_end)
                set(end ${${p}_end})
            else()
                set(end)
            endif()
            set(from ${${p}_from})
            set(fromrev ${${p}_fromrev})
            if(end)
                set(acc "${acc}\t${start}-${end}:${fromrev}:${from}")
            else()
                set(acc "${acc}\t${start}:${fromrev}:${from}")
            endif()
        endforeach()
        list(APPEND accs "${acc}")
    endforeach()
    list(SORT accs)
    foreach(e ${accs})
        set(res "${res}${e}\n")
    endforeach()
    set(${out} "${res}" PARENT_SCOPE)
endfunction()

macro(branch_read) # FIXME: Should we take a list here? don't we have to escape ;?
    foreach(l ${ARGN})
        if("${l}" MATCHES "([^\t]*)(.*)") # Don't consume \t here
            set(__branchname ${CMAKE_MATCH_1})
            set(__branchpointq ${CMAKE_MATCH_2})
            #message(STATUS "Branch: ${__branchname}:${__branchpointq}")
            while(NOT "${__branchpointq}" STREQUAL "")
                if("${__branchpointq}" MATCHES "\t([^\t]*)(.*)")
                    set(__branchentry ${CMAKE_MATCH_1})
                    set(__branchpointq ${CMAKE_MATCH_2})
                    if("${__branchentry}" MATCHES "([0-9]*)-([0-9]*):([0-9]*):(.*)")
                        set(__start ${CMAKE_MATCH_1})
                        set(__end ${CMAKE_MATCH_2})
                        set(__fromrev ${CMAKE_MATCH_3})
                        set(__from ${CMAKE_MATCH_4})
                        #message(STATUS "OpenClose: ${__branchname} <= ${__from}@${__fromrev}:${__start}-${__end}")
                        branch_open(${__branchname} ${__start} ${__from} ${__fromrev})
                        branch_close(${__branchname} ${__end})
                    elseif("${__branchentry}" MATCHES "([0-9]*):([0-9]*):(.*)")
                        set(__start ${CMAKE_MATCH_1})
                        set(__fromrev ${CMAKE_MATCH_2})
                        set(__from ${CMAKE_MATCH_3})
                        #message(STATUS "Open: ${__branchname} <= ${__from}@${__fromrev}:${__start}")
                        branch_open(${__branchname} ${__start} ${__from} ${__fromrev})
                    else()
                        message(FATAL_ERROR "Invalid branchentry format: ${__branchentry}")
                    endif()
                else()
                    message(FATAL_ERROR "Invalid branchpoint format: ${__branchpointq}")
                endif()
            endwhile()
        else()
            message(FATAL_ERROR "Invalid line format: ${l}")
        endif()
    endforeach()
endmacro()

function(branch__expandrev out rev)
    set(maxrev 10000000)
    if(${rev} GREATER ${maxrev})
        message(FATAL_ERROR "Revision id overflow ${rev}")
    endif()
    math(EXPR count "${rev}+${maxrev}")
    if(${count} MATCHES "1(.*)")
        set(${out} ${CMAKE_MATCH_1} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "huh? ${count}")
    endif()
endfunction()

macro(branch_init)
    if(branches)
        message(FATAL_ERROR "Double init..?")
    endif()
    set(branches)
endmacro()

macro(branch_open branchpath rev frompath fromrev)
    # NB: Silently ignore duplicate open OPs
    branch__expandrev(__r ${rev})
    set(__nam branchregion_r${__r}_${branchpath})
    if(${__nam}_start)
        return()
    endif()
    set(${__nam}_start ${rev})
    set(${__nam}_from ${frompath})
    set(${__nam}_fromrev ${fromrev})
    if(NOT branch_${branchpath}_regions)
        list(APPEND branches ${branchpath})
    endif()
    list(APPEND branch_${branchpath}_regions ${__nam})
    list(SORT branch_${branchpath}_regions)
endmacro()

macro(branch_close branchpath rev)
    # Detect half-open region
    if(NOT branch_${branchpath}_regions)
        message(FATAL_ERROR "Closing unknown branch ${branchpath}")
    endif()
    set(__toclose)
    foreach(e ${branch_${branchpath}_regions})
        if(NOT ${e}_end)
            if(__toclose)
                message(FATAL_ERROR "two or more open regions ${__toclose} ${e}")
            endif()
            set(__toclose ${e})
        endif()
    endforeach()
    set(${__toclose}_end ${rev})
endmacro()

function(branch_get_active_paths out rev)
    set(acc)
    foreach(e ${branches})
        set(acc0)
        # regions are SORTed so we can do linear scan
        foreach(p ${branch_${e}_regions})
            set(start ${${p}_start})
            if(${p}_end)
                set(end ${${p}_end})
            else()
                set(end)
            endif()

            if(${start} LESS ${rev} OR 
                    ${start} EQUAL ${rev})
                if(end)
                    if(${end} GREATER ${rev} OR
                            ${end} EQUAL ${rev})
                        set(acc0 ${e})
                        break()
                    endif()
                else()
                    set(acc0 ${e})
                    break()
                endif()
            endif()
        endforeach()
        if(acc0)
            list(APPEND acc ${acc0})
        endif()
    endforeach()
    set(${out} ${acc} PARENT_SCOPE)
endfunction()

function(branch_map_path out path rev)
    branch_get_active_paths(p ${rev})
    foreach(e ${p})
        if(NOT "/" STREQUAL ${e})
            set(e ${e}/)
        endif()
        string(LENGTH ${e} len)
        math(EXPR len "${len}+1")
        string(SUBSTRING ${path} 0 ${len} ck)
        #message(STATUS "Map: ${path} => ${ck} ${e}")
        if(${ck} STREQUAL ${e})
            set(${out} ${e} PARENT_SCOPE)
            break()
        endif()
    endforeach()
endfunction()

function(branch_p out nam rev)
    # Pass1: Early cut
    list(FIND branches ${nam} idx) 
    if(${idx} EQUAL -1)
        set(${out} OFF PARENT_SCOPE)
    else()
        # Pass2: Search active branch
        set(pth)
        branch_get_active_paths(pth ${rev})
        list(FIND pth ${nam} idx)
        if(${idx} EQUAL -1)
            set(${out} OFF PARENT_SCOPE)
        else()
            set(${out} ON PARENT_SCOPE)
        endif()
    endif()
endfunction()

