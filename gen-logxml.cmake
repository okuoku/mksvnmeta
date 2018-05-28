set(REPO "file:///home/oku/repos/svn/irrlicht")
set(ENV{LANG} "C.UTF8")

include(${CMAKE_CURRENT_LIST_DIR}/branchmgr.cmake)

function(parse_isodate var str)
    # => var_YYYY, var_MM, var_DD
    set(d "[0-9]")
    if(${str} MATCHES "(${d}${d}${d}${d})-(${d}${d})-(${d}${d})T(${d}${d}):(${d}${d}):([^Z])Z")
        set(${var}_YYYY ${CMAKE_MATCH_1} PARENT_SCOPE)
        set(${var}_MM ${CMAKE_MATCH_2} PARENT_SCOPE)
        set(${var}_DD ${CMAKE_MATCH_3} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Invalid format for isodate [${str}]")
    endif()
endfunction()

function(svn_getlogxml pth repo rev)
    get_filename_component(dir ${pth} PATH)
    file(MAKE_DIRECTORY ${dir})
    execute_process(
        COMMAND svn log -v --xml -r ${rev} ${repo}
        OUTPUT_FILE ${pth}
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "failed to generate log: ${rr}")
    endif()
endfunction()

function(svn_getinfoxml res repo rev)
    execute_process(
        COMMAND svn info --xml -r ${rev} ${repo}
        OUTPUT_VARIABLE out
        RESULT_VARIABLE rr)
    if(NOT rr)
        set(${res} "${out}" PARENT_SCOPE)
    endif()
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

# Get startrev
if(EXISTS logcurrev.txt)
    file(READ logcurrev.txt in)
    if("${in}" MATCHES "revision:([0-9]*)")
        set(startrev ${CMAKE_MATCH_1})
    else()
        message(FATAL_ERROR "logcurrev parse error: ${in}")
    endif()
else()
    set(startrev 1)
endif()

# Get endrev
svn_getinfoxml(res ${REPO} HEAD)
message(STATUS "Info: ${res}")
file(WRITE tmp.xml "${res}")
xml_xslt(out ${CMAKE_CURRENT_LIST_DIR}/parseinfo.xml tmp.xml)
message(STATUS "Rev: ${out}")
if("${out}" MATCHES "revision:([0-9]*)")
    set(endrev ${CMAKE_MATCH_1})
else()
    message(FATAL_ERROR "Invalid info output ${res}")
endif()
file(REMOVE tmp.xml)
file(WRITE logcurrev.txt "${out}")

message(STATUS "startrev = ${startrev}")
message(STATUS "endrev = ${endrev}")

# Acquire logs
set(currev ${startrev})
while(1)
    if(${currev} GREATER ${endrev})
        break()
    endif()
    make_revfile_path(pth ${CMAKE_CURRENT_BINARY_DIR} ${currev})
    svn_getlogxml(${pth} ${REPO} ${currev})
    message(STATUS "Save(${currev}/${endrev}): ${pth}")
    math(EXPR currev "${currev}+1")
endwhile()

