set(REPOPATH "/home/oku/repos/svn/irrlicht")
set(ENV{LANG} "C.UTF-8")

function(make_propfile_path res prefix rev)
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
    set(${res} "${prefix}/${xxxx}/${yyy}.prop.txt" PARENT_SCOPE)
endfunction()

# Calc startrev, endrev
if(EXISTS propcurrev.txt)
    file(READ propcurrev.txt in)
    if("${in}" MATCHES "revision:([0-9]*)")
        set(startrev ${CMAKE_MATCH_1})
    else()
        message(FATAL_ERROR "propcurrev parse error: ${in}")
    endif()
else()
    set(startrev 1)
endif()

file(READ logcurrev.txt in)
if("${in}" MATCHES "revision:([0-9]*)")
    set(endrev ${CMAKE_MATCH_1})
else()
    message(FATAL_ERROR "logcurrev parse error: ${in}")
endif()

# Generate split executable
execute_process(
    COMMAND cc
    -O2
    ${CMAKE_CURRENT_LIST_DIR}/splitsvndump/splitsvndump.c
    -o splitsvndump
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to generate splitsvndump: ${rr}")
endif()

# Run split process
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

    # Dump 100 revisions
    execute_process(
        COMMAND svnadmin dump
        ${REPOPATH}
        -r ${curstartrev}:${curendrev}
        --incremental
        OUTPUT_FILE the_dump
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "Failed to dump repository: ${rr}")
    endif()

    # Split props
    execute_process(
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/splitsvndump the_dump
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "Split svn dump failed: ${rr}")
    endif()

    # Move props.txt
    foreach(r RANGE ${curstartrev} ${curendrev})
        if(NOT EXISTS ${r}.prop.txt)
            message(FATAL_ERROR "WARNING: ${r}.prop.txt did not found!")
        else()
            make_propfile_path(propfile ${CMAKE_CURRENT_BINARY_DIR} ${r})
            file(RENAME ${r}.prop.txt ${propfile})
        endif()
    endforeach()

    math(EXPR curstartrev "${curendrev}+1")
endwhile()

# Cleanup
if(EXISTS the_dump)
    file(REMOVE the_dump)
endif()

if(EXISTS splitsvndump)
    file(REMOVE splitsvndump)
endif()

if(EXISTS splitsvndump.exe)
    file(REMOVE splitsvndump.exe)
endif()

file(WRITE propcurrev.txt "revision:${endrev}\n")
