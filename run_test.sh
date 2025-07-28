#!/bin/bash
# ==========================================================
# Advantech EBO - Device Library In-Container Test Tool
# ==========================================================
# Created and maintained by Vincent Hung <Vincent.Hung@advantech.com.tw>

#################################################################

# host_dependency_check_str=$(./host_dependency_check.sh)
# host_dependency_check_result=$?

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

#################################################################

# --- Helper Functions ---

print_header() {
    echo -e "\n${BOLD}${BLUE}====== $1 ======${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_info() {
    echo ""
    # mkdir -p ./log
    # echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> ./log/host_dependency_check_output
}

resolve_link() {

    local TARGET="$1"

    # If it is a symbolic link, keep resolving it until the actual file is found.
    while [ -L "$TARGET" ]; do
        TARGET="$(readlink -f "$TARGET")"
    done

    # Finally, perform a final check to confirm that it is a existing file or directory.
    if [ -e "$TARGET" ]; then
        echo "$TARGET"
        return 0
    else
        return 1
    fi
}

check_image_locally() {

    local IMAGE_NAME="$1"

    # Check if the image tag is provided
    if [[ -z "$IMAGE_NAME" ]]; then
        echo "Please provide an image name and tag, e.g., nginx:latest"
        return 2
    fi

    # Use docker inspect to check if the image exists locally
    if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        return 0  # Image exists
    else
        return 1  # Image does not exist
    fi
}

#################################################################

# --- Hardware API Verification Functions ---

verify_platform_info() {

    print_header "Platform Information"

    local arch=$(uname -m)
    local kernel_version=$(uname -r)
    print_info "Architecture : $arch"
    print_info "Kernel Version : $kernel_version"
}

verify_install_susi() {

    print_header "Verify installation : SUSI"

    local source_path=""
    local resolved_path=""
    local arr_paths=()
    local arr_path_found_flags=()
    local found_count=0
    local all_path_found=1

    # Get machine architecture 
    local arch=$(uname -m)

    # Check dependencies according to machine architecture
    if [[ "$arch" == "x86_64" ]]; then

        # Create array of checked paths.
        arr_paths+=(/opt/Advantech/)
        arr_paths+=(/etc/Advantech/)
        arr_paths+=(/usr/lib/Advantech/)
        arr_paths+=(/usr/lib/x86_64-linux-gnu/)
        arr_paths+=(/usr/lib/libSUSI-4.00.so)
        arr_paths+=(/usr/lib/libSUSI-4.00.so.1)
        arr_paths+=(/usr/lib/libSUSI-3.02.so)
        arr_paths+=(/usr/lib/libSUSI-3.02.so.1)
        arr_paths+=(/usr/lib/libSusiIoT.so)
        arr_paths+=(/usr/lib/libSusiIoT.so.1.0.0)
        arr_paths+=(/usr/lib/libjansson.so)
        arr_paths+=(/usr/lib/libjansson.so.4)
        arr_paths+=(/usr/lib/libSUSIDevice.so)
        arr_paths+=(/usr/lib/libSUSIDevice.so.1)
        arr_paths+=(/usr/lib/libSUSIAI.so)
        arr_paths+=(/usr/lib/libSUSIAI.so.1)

    elif [[ "$arch" == "aarch64" ]]; then

        # Create array of checked paths.
        arr_paths+=(/etc/board)
        arr_paths+=(/usr/lib/Advantech/)
        arr_paths+=(/usr/lib/aarch64-linux-gnu)
        arr_paths+=(/lib/libSUSI-4.00.so)
        arr_paths+=(/lib/libSUSI-4.00.so.1)
        arr_paths+=(/lib/libSUSI-4.00.so.1.0.0)
        arr_paths+=(/lib/libjansson.so)
        arr_paths+=(/lib/libjansson.so.4)
        arr_paths+=(/lib/libjansson.so.4.11.0)
        arr_paths+=(/lib/libSusiIoT.so)
        arr_paths+=(/lib/libSusiIoT.so.1.0.0)

    else

        echo "Unknown architecture : $arch"
        return 1

    fi

    # Check existence for every path in checked path array.
    for checked_path in "${arr_paths[@]}"; do

        source_path=$checked_path
        resolved_path=$(resolve_link $source_path)
        if [ $? -eq 0 ]; then
            print_info "Source path: $source_path, Resolved path: $resolved_path"
            found_count=$((found_count + 1))
            arr_path_found_flags+=(1)
        else
            arr_path_found_flags+=(0)
            all_path_found=0
        fi

        sleep 0.1

    done

    # Return result
    local not_found_count=$(( ${#arr_paths[@]} - found_count ))
    if [ $all_path_found -eq 1 ]; then
        print_success "Paths $found_count found, $not_found_count not found"
        return 0
    else
        print_error "Paths $found_count found, $not_found_count not found"
        return 1
    fi
}

verify_install_platformsdk() {

    print_header "Verify installation : PlatformSDK"

    local source_path=""
    local resolved_path=""
    local arr_paths=()
    local arr_path_found_flags=()
    local found_count=0
    local all_path_found=1

    # Get machine architecture 
    local arch=$(uname -m)

    # Check dependencies according to machine architecture
    if [[ "$arch" == "x86_64" ]] || [[ "$arch" == "aarch64" ]]; then

        # Create array of checked paths.
        arr_paths+=(/usr/src/advantech)
        arr_paths+=(/usr/lib/libATAuxIO.so)
        arr_paths+=(/usr/lib/libATGPIO.so)
        arr_paths+=(/usr/lib/libBoardResource.so)
        arr_paths+=(/usr/lib/libEAPI-IPS.so)
        arr_paths+=(/usr/lib/libEAPI.so)
        arr_paths+=(/usr/lib/libECGPIO.so)
        arr_paths+=(/usr/lib/libATSMBUS.so)

    else

        echo "Unknown architecture : $arch"
        return 1

    fi

    # Check existence for every path in checked path array.
    for checked_path in "${arr_paths[@]}"; do

        source_path=$checked_path
        resolved_path=$(resolve_link $source_path)
        if [ $? -eq 0 ]; then
            print_info "Source path: $source_path, Resolved path: $resolved_path"
            found_count=$((found_count + 1))
            arr_path_found_flags+=(1)
        else
            arr_path_found_flags+=(0)
            all_path_found=0
        fi

        sleep 0.1

    done

    # Return result
    local not_found_count=$(( ${#arr_paths[@]} - found_count ))
    if [ $all_path_found -eq 1 ]; then
        print_success "Paths $found_count found, $not_found_count not found"
        return 0
    else
        print_error "Paths $found_count found, $not_found_count not found"
        return 1
    fi
}

output_verify_result() {

    print_header "Verification Result"

    if [ $SUSI_INSTALL_RESULT -eq 0 ]; then
        print_success "SUSI is installed."
        log_info "SUSI is installed."
    else
        print_error "SUSI is not installed."
        log_info "SUSI is not installed."
    fi

    if [ $PLATFORMSDK_INSTALL_RESULT -eq 0 ]; then
        print_success "PlatformSDK is installed."
        log_info "PlatformSDK is installed."
    else
        print_error "PlatformSDK is not installed."
        log_info "PlatformSDK is not installed."
    fi
}

run_test_image() {

    print_header "Running Test Container"

    echo ""

    local CONTAINER_NAME=$1

    # Get machine architecture 
    local arch=$(uname -m)

    # Run docker compose according to installed Advantech API and machine architecture.
    local FILE_PATH=""
    if [[ $SUSI_INSTALL_RESULT -eq 0 ]]; then

        if [[ "$arch" == "x86_64" ]]; then

            FILE_PATH="./docker-compose_susi_x86.yml"

        elif [[ "$arch" == "aarch64" ]]; then

            FILE_PATH="./docker-compose_susi_arm.yml"

        else

            echo "Unknown architecture : $arch"
            return 1

        fi

    elif [[ $PLATFORMSDK_INSTALL_RESULT -eq 0 ]]; then

        FILE_PATH="./docker-compose_platformsdk.yml"

    else

        echo "Advantech API not installed"
        return 1

    fi

    print_info "Run docker-compose file : $FILE_PATH"

    # Run container via docker-compose.
    docker-compose -f $FILE_PATH run --rm device_library_test

    print_info "Run container done"

    echo ""
}

#################################################################

# Clear the terminal
clear

# Check platform
verify_platform_info

# Check SUSI
verify_install_susi
SUSI_INSTALL_RESULT=$?

# Check PlatformSDK
verify_install_platformsdk
PLATFORMSDK_INSTALL_RESULT=$?

# Output verify result
output_verify_result

# Run test image
run_test_image