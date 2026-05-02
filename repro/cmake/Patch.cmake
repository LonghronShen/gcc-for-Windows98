# use GNU Patch from any platform

if(WIN32)
    # prioritize Git Patch on Windows as other Patches may be very old and incompatible.
    find_package(Git)
    if(Git_FOUND)
        get_filename_component(GIT_DIR ${GIT_EXECUTABLE} DIRECTORY)
        get_filename_component(GIT_DIR ${GIT_DIR} DIRECTORY)
    endif()
endif()

find_program(PATCH_EXECUTABLE
    NAMES patch
    HINTS ${GIT_DIR}
    PATH_SUFFIXES usr/bin
)

if(NOT PATCH_EXECUTABLE)
    message(FATAL_ERROR "Did not find GNU Patch")
endif()

function(patch_directory dir_to_patch patch_file)
    execute_process(COMMAND ${PATCH_EXECUTABLE} -s -p1 --forward
        INPUT_FILE "${patch_file}"
        WORKING_DIRECTORY "${dir_to_patch}"
        TIMEOUT 15
        COMMAND_ECHO STDOUT
        OUTPUT_VARIABLE patch_stdout
        RESULT_VARIABLE patch_ret
    )

    if(NOT (patch_ret EQUAL 0))
        if(NOT ("${patch_stdout}" MATCHES "Skipping patch"))
            message(FATAL_ERROR "Failed to apply patch \"${dir_to_patch}\" using \"${patch_file}\" with \"${PATCH_EXECUTABLE}\"")
        endif()
    endif()
endfunction()
