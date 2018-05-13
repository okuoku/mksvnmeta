cmake_minimum_required(VERSION 3.0)

set(ENV{LANG} "C.UTF8")
set(REV 5605)

set(REPO "file:///home/oku/repos/svn/irrlicht")
set(DIR "/trunk")
set(REPOPATH "${REPO}${DIR}")

string(LENGTH "${REPOPATH}" repopathlen)

set(TMP "${CMAKE_CURRENT_BINARY_DIR}/tmp${REV}") # FIXME: Add path info, / => _

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

function(svn_getproplist pth repo rev)
    get_filename_component(dir ${pth} PATH)
    file(MAKE_DIRECTORY ${dir})
    execute_process(
        COMMAND svn proplist --xml -R -r ${rev} ${repo}
        OUTPUT_FILE ${pth}
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "failed to generate log: ${rr}")
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

macro(register_prop url prop val)
    string(SUBSTRING ${url} ${repopathlen} -1 __prefix)
    set(prop_${prop}_${__prefix} ${val})
    if(NOT prefixes_${__prefix})
        set(prefixes_${__prefix} ON)
        list(APPEND prefixes ${__prefix})
    endif()
endmacro()

set(props ${TMP}.props.xml)
set(propcontent ${TMP}.propcontent.xml)

svn_getproplist(${props} ${REPOPATH} ${REV})
xml_xslt(res ${CMAKE_CURRENT_LIST_DIR}/prop-enum.xml ${props})
file(REMOVE ${props})
string(REGEX REPLACE "\n" ";" res "${res}")

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
        message(STATUS "LINE: ${l}")
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
message(STATUS ${out})

