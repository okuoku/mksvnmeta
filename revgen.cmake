#
# revgen: Generate revision data for a revision + branch
#
#  XXXX/YYY_bZZZZZ/*
#    dirname.txt : Branch name
#    props.txt : Properties list
#
#  INPUTs:
#    REV: Revision
#    DIR: Directory in the repository
#    IDX: Branch index

cmake_minimum_required(VERSION 3.0)

set(ENV{LANG} "C.UTF8")

set(REPO "file:///home/oku/repos/svn/irrlicht")
set(REPOPATH "${REPO}${DIR}")

string(LENGTH "${REPOPATH}" repopathlen)

set(TMP "${CMAKE_CURRENT_BINARY_DIR}/tmp${REV}_${IDX}")

function(make_revdata_path2 res)
    # Output {CURPATH}/branchdata/XXXX/YYY_bZZZZZ with zero-filled
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
    if(${IDX} LESS 10)
        set(zzzzz "0000${IDX}")
    elseif(${IDX} LESS 100)
        set(zzzzz "000${IDX}")
    elseif(${IDX} LESS 1000)
        set(zzzzz "00${IDX}")
    elseif(${IDX} LESS 10000)
        set(zzzzz "0${IDX}")
    else()
        set(zzzzz ${IDX})
    endif()

    set(${res} "${CMAKE_CURRENT_BINARY_DIR}/branchdata/${xxxx}/${yyy}_b${zzzzz}" PARENT_SCOPE)
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

function(svn_getproplist res pth repo rev)
    get_filename_component(dir ${pth} PATH)
    file(MAKE_DIRECTORY ${dir})
    execute_process(
        COMMAND svn proplist --xml -R -r ${rev} ${repo}
        OUTPUT_FILE ${pth}
        RESULT_VARIABLE rr)
    if(rr)
        # Perhaps no properties available
        message(STATUS "failed to generate proplist: ${rr} ${repo}@${rev} (IGNORED)")
        set(${res} OFF PARENT_SCOPE)
    else()
        set(${res} ON PARENT_SCOPE)
    endif()
endfunction()

function(svn_getpropcontent pth repo prop rev)
    get_filename_component(dir ${pth} PATH)
    file(MAKE_DIRECTORY ${dir})
    execute_process(
        COMMAND svn propget ${prop} --xml -R -r ${rev} ${repo}
        OUTPUT_FILE ${pth}
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "failed to generate log: ${rr}")
    endif()
endfunction()

function(checkpath url)
    string(LENGTH "${url}" urllen)
    if(${repopathlen} GREATER ${urllen})
        message(STATUS "SOMETHINGWRONG: ${url} ## ${REPOPATH}")
    elseif(${repopathlen} EQUAL ${urllen})
        message(STATUS "Suspicious: ${url} ## ${REPOPATH}")
    endif()
endfunction()

macro(register_prop url prop val)
    #checkpath(${url})
    if("${url}/" STREQUAL ${REPOPATH})
        set(__prefix "/")
    elseif(${url} STREQUAL ${REPOPATH})
        set(__prefix "/")
    else()
        string(SUBSTRING ${url} ${repopathlen} -1 __prefix)
    endif()
    set(prop_${prop}_${__prefix} ${val})
    if(NOT prefixes_${__prefix})
        set(prefixes_${__prefix} ON)
        list(APPEND prefixes ${__prefix})
    endif()
endmacro()

make_revdata_path2(pth)
file(MAKE_DIRECTORY ${pth})

file(WRITE ${pth}/dirname.txt ${DIR})

set(props ${TMP}.props.xml)
set(propcontent ${TMP}.propcontent.xml)

svn_getproplist(res ${props} ${REPOPATH} ${REV})

if(${res} STREQUAL ON)
    xml_xslt(res ${CMAKE_CURRENT_LIST_DIR}/prop-enum.xml ${props})
    file(REMOVE ${props})
    string(REGEX REPLACE "\n" ";" res "${res}")
else()
    set(res)
endif()

set(propnames)
foreach(l ${res})
    if(NOT haveprop_${l})
        set(haveprop_${l} ON)
        list(APPEND propnames ${l})
    endif()
endforeach()

set(prefixes)
foreach(p ${propnames})
    svn_getpropcontent(${propcontent} ${REPOPATH} ${p} ${REV})
    xml_xslt(res ${CMAKE_CURRENT_LIST_DIR}/prop-rip.xml ${propcontent})
    string(REGEX REPLACE "\n" ";" res "${res}")
    set(cururl)
    set(acc)
    foreach(l ${res})
        #message(STATUS "LINE: ${l}")
        if(NOT cururl)
            if(${l} MATCHES "@@\\?(.*)")
                set(cururl ${CMAKE_MATCH_1})
            else()
                message(FATAL_ERROR "Invalid header ${l}")
            endif()
        elseif(${l} MATCHES "@@\\?(.*)")
            # Finish current cururl:p:acc
            register_prop(${cururl} ${p} ${acc})
            # Start new cururl
            set(cururl ${CMAKE_MATCH_1})
            set(acc)
        elseif(${l} MATCHES "\t(.*)")
            set(acc "\t\t${CMAKE_MATCH_1}")
        else()
            set(acc "${acc}\n\t\t${l}")
        endif()
    endforeach()
    if(cururl AND acc)
        register_prop(${cururl} ${p} ${acc})
    endif()
    file(REMOVE ${propcontent})
endforeach()


#message(STATUS "CALC...")
set(out)
foreach(u ${prefixes})
    set(out "${out}${u}\n")
    foreach(p ${propnames})
        if(prop_${p}_${u})
            set(out "${out}\t${p}\n${prop_${p}_${u}}\n")
        endif()
    endforeach()
endforeach()

file(WRITE ${pth}/props.txt ${out})

#message(STATUS "Done ${REV}.")
