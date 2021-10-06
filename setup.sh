#!/bin/bash

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    printf "${0} uses get-opt(); on ubuntu install util-linux package / on mac install gnu-getopt\n"
    exit 1
fi

# Exit the script as soon as a command fails
# set -exit
set -o pipefail

# Global variables
red=$'\e[1;31m'
green=$'\e[1;32m'
yellow=$'\e[1;33m'
blue=$'\e[1;34m'
magenta=$'\e[1;35m'
cyan=$'\e[1;36m'
normal=$'\e[0m'
bold=$'\e[1m'

gs_install=false
gs_clean=false
gs_build=false
gs_format=false
gs_sym_links=false
gs_create_project=false
gs_project_name=""

usage() {
    printf ${yellow}
    printf "Usage of $(basename ${0})\n"
    printf "\n"
    printf "%s | %-25s  %-5s\n" "-h" "--help"                   "Prints the help menu"
    printf "%s | %-25s  %-5s\n" "-i" "--install"                "Installs the rust compiler and cargo"
    printf "%s | %-25s  %-5s\n" "-c" "--clean"                  "Cleans the build directory"
    printf "%s | %-25s  %-5s\n" "-b" "--build"                  "Builds all the apps"
    printf "%s | %-25s  %-5s\n" "-f" "--format"                 "Format code in all the apps"
    printf "%s | %-25s  %-5s\n" "-l" "--links"                  "Creates a symbolic link of all the executable in the executables dir"
    printf "%s | %-25s  %-5s\n" "-p" "--project <project-name>" "Creates a project folder with the provided name based on the template"
    printf "${normal}\n"
    exit 0
}

#parameter parsing
short_options=h,i,c,b,f,l,p:
long_options=help,install,clean,build,format,links,project:

script_options=$(getopt --options=${short_options} --longoptions=${long_options} --name "${0}" -- "$@")
if [[ $? -ne 0 ]]; then
    #getopt error
    exit 2
fi

# Necessary for proper parsing of getopt results
eval set -- "${script_options}"

# Primary bash argumenst parsing loop; new arguments are added as a switch parameter
while true ; do
    case "${1}" in
    -h|--help)
        usage
        ;;
    -i|--install)
        gs_install=true
        break
        ;;
    -c|--clean)
        printf "${cyan}Cleaning the build directory${normal}\n"
        gs_clean=true
        rm -rf ./build/*
        rm -rf ./executables/*
        shift
        ;;
    -b|--build)
        gs_build=true
        shift
        ;;
    -f|--format)
        gs_format=true
        shift
        ;;
    -l|--links)
        gs_sym_links=true
        shift
        ;;
    -p|--project)
        gs_create_project=true
        gs_project_name=$2
        shift 2
        ;;
    --)
        shift
        break
        ;;
    esac
done

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     
        printf "${green}Running on Linux!${normal}\n"
        gs_sed="sed"
        gs_find="find"
        ;;
    Darwin*)    
        printf "${green}Running on MacOS!${normal}\n"
        gs_sed="gsed"
        gs_find="gfind"
        ;;
    *)      
        printf "${red}Unsupported OS!${normal}\n"
        ;;
esac

which ${gs_sed} > /dev/null
if [[ $? -ne 0 ]]; then
    printf "${red}Install gnu-sed${normal}\n"
fi

if [[ ${gs_install} == true ]]; then
    printf "${green}Installing rustup${normal}\n"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env
    rustup update

    cargo_version=$( cargo --version )
    printf "\nSuccessfully installed Cargo: ${blue}${cargo_version}${normal}\n"
fi

which cargo > /dev/null
if [[ $? -ne 0 ]]; then
    printf "${red}Rust compiler and cargo not installed\n"
    printf "Run setup.sh -i to install rust and cargo${normal}\n"
    exit 13
fi

mkdir -p $PWD/apps

if [[ ! -f $PWD/apps/Cargo.toml ]]; then
    printf "${yellow}Creating:${normal} ${bold}$PWD/apps/Cargo.toml${normal}\n"
    printf "# Add the required apps in this file\n" >> "$PWD/apps/Cargo.toml"
    printf "[workspace]\n" >> "$PWD/apps/Cargo.toml"
    printf "members = [\n" >> "$PWD/apps/Cargo.toml"
    printf "]\n" >> "$PWD/apps/Cargo.toml"

fi

if [[ ! -f $PWD/apps/rustfmt.toml ]]; then
    printf "${yellow}Creating:${normal} ${bold}$PWD/apps/rustfmt.toml${normal}\n"
    printf "max_width=120" >> "$PWD/apps/rustfmt.toml"
fi

if [[ ${gs_clean=} == true ]]; then
    pushd $PWD/apps > /dev/null
    cargo clean
    popd > /dev/null
    rm -rf ../executables/*
fi

if [[ ${gs_create_project} == true ]]; then
    if [[ -d $PWD/apps/${gs_project_name} ]]; then
        printf "${bold}${gs_project_name}${normal}: ${red}Project already exists${normal}\n"
    else
        pushd $PWD/apps > /dev/null

        grep ${gs_project_name} "./Cargo.toml" > /dev/null
        if [[ $? -ne 0 ]]; then 
            ${gs_sed} -i "$ s/]/    \"${gs_project_name}\",/" Cargo.toml
            printf "]\n" >> "./Cargo.toml"
        fi

        cargo new ${gs_project_name}
        if [[ $? -ne 0 ]]; then
            exit 13
        fi

        popd > /dev/null
    fi
fi

if [[ ${gs_build} == true ]]; then
    printf "${green}Building all projects${normal}\n"
    pushd $PWD/apps > /dev/null

    cargo build --workspace
    if [[ $? -ne 0 ]]; then
        exit 13
    else 
        if [[ ${gs_sym_links} == true ]]; then
            printf "${yellow}Creating symbolic links of the executables${normal}\n"

            rm -rf ../executables/*
            mkdir -p ../executables
            exe_files=($( ${gs_find} ./target/debug -executable -type f | grep -v bin | grep -v out | grep -v lock | grep -v deps))
            for i in "${exe_files[@]}"
            do 
                ln -sfn "$PWD/${i}" "../executables/$(basename ${i})"
            done
        fi
    fi

    popd > /dev/null
fi

if [[ ${gs_format} == true ]]; then
    printf "${green}Formatting all projects${normal}\n"
    pushd $PWD/apps > /dev/null

    cargo fmt --all
    if [[ $? -ne 0 ]]; then
        exit 13
    fi

    popd > /dev/null
fi

exit 0