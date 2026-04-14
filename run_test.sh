#!/bin/bash
# ==========================================================
# Advantech EBO - Device Library In-Container Test Tool
# ==========================================================
# Created and maintained by Vincent Hung <Vincent.Hung@advantech.com.tw>
#
# Usage: ./run_test.sh [OPTIONS]
# Options:
#   --pull-image      Remove local Docker image and pull latest from Harbor
#   --help            Show this help message

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

# --- Azure DevOps and NuGet Configuration ---
IMAGE="harbor.edgesync.cloud/weda-internal/device_library_test_base:Ubuntu2204-0.0.2"
TEST_CONTAINER_NAME="device_library_test"
AZDO_ARTIFACTS_FEED_NAME="EngineeringRelease"
AZDO_ARTIFACTS_FEED_URL="https://feeds.dev.azure.com/Advantech-EBO/_apis/packaging/feeds/${AZDO_ARTIFACTS_FEED_NAME}"
AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL="https://pkgs.dev.azure.com/Advantech-EBO/_packaging/${AZDO_ARTIFACTS_FEED_NAME}/nuget/v3/index.json"
TOOL_LEVEL_NUGET_SRC_HOST_PATH="./tool_level_local_nuget_source"
TOOL_LEVEL_NUGET_SRC_CONTAINER_PATH="/app/TestToolProcess/local_nuget_source"
DEBUG_MODE=1
USE_LOCAL_NUGET_SOURCE=0
BYPASS_ADVANCED_TEST=true

#################################################################

# --- Command-line Arguments ---
PULL_IMAGE=0

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pull-image)
            PULL_IMAGE=1
            shift
            ;;
        --help)
            echo "Usage: ./run_test.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pull-image      Remove local Docker image and pull latest from Harbor"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

#################################################################

# --- Main Execution Functions ---

load_env_file() {
    print_header "Loading Configuration"
    
    # Check if .env file exists
    if [[ ! -f ".env" ]]; then
        print_error ".env file not found in $(pwd)"
        return 1
    fi
    
    # Load environment variables from .env file
    source .env
    print_success ".env file loaded"
    
    # Validate required variables (TEST_ENVIRONMENT_TYPE is optional - will be auto-detected if not set)
    if [[ -z "${NUGET_PKG_TO_BE_TESTED}" ]]; then
        print_error "Required variable not set: NUGET_PKG_TO_BE_TESTED"
        return 1
    fi

    if [[ -z "${AZDO_PAT}" ]]; then
        print_error "Required variable not set: AZDO_PAT"
        print_error "AZDO_PAT must have at least 'Package Read' permission scope"
        print_error "Please configure .env with a valid Azure DevOps Personal Access Token"
        return 1
    fi
    
    # Show TEST_ENVIRONMENT_TYPE status
    if [[ -z "$TEST_ENVIRONMENT_TYPE" ]]; then
        print_info "TEST_ENVIRONMENT_TYPE not specified - will use auto-detection"
    else
        print_info "TEST_ENVIRONMENT_TYPE specified: $TEST_ENVIRONMENT_TYPE"
    fi
}

check_docker_available() {
    print_header "Checking Docker Availability"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        print_error "docker compose is not installed or not in PATH"
        return 1
    fi
    
    # Check if docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return 1
    fi
    
    print_success "Docker and docker compose commands are available"
    return 0
}

verify_harbor_image_availability() {
    print_header "Verifying Docker Image Availability"
    
    print_info "Docker image reference: $IMAGE"
    
    # Step 0: Handle --pull-image flag (force refresh)
    if [[ $PULL_IMAGE -eq 1 ]]; then
        print_info "Removing local Docker image (--pull-image flag set)..."
        if docker rmi "$IMAGE" > /dev/null 2>&1; then
            print_success "Local Docker image removed successfully"
        else
            print_info "Local Docker image not found or already removed"
        fi
    fi
    
    # Step 1: Check if image exists locally
    if docker image inspect "$IMAGE" > /dev/null 2>&1; then
        print_success "Docker image is available locally"
        return 0
    fi
    
    print_info "Image not found locally, checking Harbor Registry..."
    
    # Step 2: Extract registry hostname from IMAGE reference
    local REGISTRY=$(echo "$IMAGE" | cut -d'/' -f1)
    print_info "Registry hostname: $REGISTRY"
    
    # Step 3: Check if Harbor Registry is authenticated
    print_info "Checking Harbor Registry authentication..."
    if ! grep -q "\"$REGISTRY\"" ~/.docker/config.json 2>/dev/null; then
        print_warning "Harbor Registry is not authenticated: $REGISTRY"
        print_error "Please login to Harbor Registry first:"
        print_error "  docker login $REGISTRY"
        print_error "Then run this script again"
        return 1
    fi
    
    print_success "Harbor Registry authentication found"
    
    # Step 4: Check if image exists in Harbor Registry using manifest inspect (fail-fast without pulling)
    if docker manifest inspect "$IMAGE" > /dev/null 2>&1; then
        print_success "Docker image exists in Harbor Registry and will be pulled on first container run"
        return 0
    fi
    
    # Image not found either locally or in Harbor
    print_error "Docker image not found in Harbor Registry: $IMAGE"
    print_error "Please verify:"
    print_error "  1. IMAGE name and tag are correct in .env"
    print_error "  2. Harbor Registry is accessible at: $REGISTRY"
    print_error "  3. You are authenticated to the Harbor Registry"
    print_error "  4. Network connectivity to Harbor Registry"
    return 1
}

setup_and_verify_environment() {
    print_header "Setting Up and Verifying Environment"
    
    # Step 1: Check if TEST_ENVIRONMENT_TYPE is manually specified
    if [[ ! -z "$TEST_ENVIRONMENT_TYPE" ]]; then
        print_info "Step 1: Using manually specified environment type: $TEST_ENVIRONMENT_TYPE"
    else
        print_info "Step 1: Auto-detecting hardware environment (TEST_ENVIRONMENT_TYPE not specified in .env)"
        
        local arch=$(uname -m)
        print_info "  Detected architecture: $arch"
        
        # Check if SUSI is installed
        local susi_detected=0
        if [[ -f "/usr/lib/libSUSI-4.00.so" ]] || [[ -f "/usr/lib/libSUSI-3.02.so" ]]; then
            susi_detected=1
            print_info "  Found SUSI library"
        elif [[ -f "/lib/libSUSI-4.00.so" ]] || [[ -f "/lib/libSUSI-3.02.so" ]]; then
            susi_detected=1
            print_info "  Found SUSI library"
        fi
        
        # Check if PlatformSDK is installed
        local platformsdk_detected=0
        if [[ -f "/usr/lib/libEAPI.so" ]]; then
            platformsdk_detected=1
            print_info "  Found PlatformSDK library"
        fi
        
        # Determine environment type based on detection
        if [[ $susi_detected -eq 1 ]]; then
            if [[ "$arch" == "aarch64" ]]; then
                TEST_ENVIRONMENT_TYPE="SUSI_ARM"
            elif [[ "$arch" == "x86_64" ]]; then
                TEST_ENVIRONMENT_TYPE="SUSI_X86"
            else
                TEST_ENVIRONMENT_TYPE="SUSI_ARM"
            fi
            print_success "  Detected: $TEST_ENVIRONMENT_TYPE environment"
        elif [[ $platformsdk_detected -eq 1 ]]; then
            TEST_ENVIRONMENT_TYPE="PlatformSDK"
            print_success "  Detected: PlatformSDK environment"
        else
            TEST_ENVIRONMENT_TYPE="PlatformSDK"
            print_warning "  No hardware libraries detected, defaulting to PlatformSDK"
        fi
    fi
    
    # Step 2: Validate environment type
    print_info "Step 2: Validating environment type: $TEST_ENVIRONMENT_TYPE"
    
    local valid_types=("PlatformSDK" "SUSI_ARM" "SUSI_X86")
    local is_valid=0
    
    for type in "${valid_types[@]}"; do
        if [[ "$TEST_ENVIRONMENT_TYPE" == "$type" ]]; then
            is_valid=1
            break
        fi
    done
    
    if [[ $is_valid -eq 0 ]]; then
        print_error "Invalid TEST_ENVIRONMENT_TYPE: $TEST_ENVIRONMENT_TYPE"
        print_info "Valid values: PlatformSDK, SUSI_ARM, SUSI_X86"
        return 1
    fi
    
    # Step 3: Verify docker compose file exists
    print_info "Step 3: Verifying docker compose file for environment: $TEST_ENVIRONMENT_TYPE"
    
    local compose_file=""
    case "$TEST_ENVIRONMENT_TYPE" in
        "PlatformSDK")
            compose_file="./docker-compose_platformsdk.yml"
            ;;
        "SUSI_ARM")
            compose_file="./docker-compose_susi_arm.yml"
            ;;
        "SUSI_X86")
            compose_file="./docker-compose_susi_x86.yml"
            ;;
    esac
    
    if [[ ! -f "$compose_file" ]]; then
        print_error "Docker Compose file not found: $compose_file"
        return 1
    fi
    
    DOCKER_COMPOSE_FILE="$compose_file"
    export TEST_ENVIRONMENT_TYPE
    
    print_success "Environment setup verified: $TEST_ENVIRONMENT_TYPE, Chosen file : $DOCKER_COMPOSE_FILE"
    return 0
}

verify_and_prepare_local_nuget_source() {

    local -a nuget_packages=()
    local -a nupkg_versions=()
    local -a matched_versions=()
    local detected_versions=""
    local version_pattern="$NUGET_PKG_TO_BE_TESTED"
    local version_regex=""
    local resolved_version=""
    local resolved_package_path=""

    # Early exit if local NuGet source is not enabled
    if [[ $USE_LOCAL_NUGET_SOURCE -eq 0 ]]; then
        print_info "USE_LOCAL_NUGET_SOURCE is disabled, skipping local NuGet source verification and preparation"
        return 0
    fi

    print_header "Verifying and Preparing Local NuGet Source"
    
    # Verify local NuGet source directory if USE_LOCAL_NUGET_SOURCE is enabled
    # If USE_LOCAL_NUGET_SOURCE is enabled, copy local NuGet packages from host to container before running the container
    # Using docker compose cp command to copy the local NuGet packages from TOOL_LEVEL_NUGET_SRC_HOST_PATH on host to TOOL_LEVEL_NUGET_SRC_CONTAINER_PATH in container,
    # so that the test can restore from the local NuGet source during execution without needing to pull from Azure DevOps Artifacts Feed,
    # and this also allows users to easily use a local NuGet source with the following workflow:
    # 1. Enable USE_LOCAL_NUGET_SOURCE flag (not equals 0) and run the script once to create directory: $TOOL_LEVEL_NUGET_SRC_HOST_PATH
    # 2. Pack Advantech.Edge NuGet package locally with expected version and naming (e.g. Advantech.Edge.1.2.3.nupkg)
    # 3. Copy packed NuGet package to $TOOL_LEVEL_NUGET_SRC_HOST_PATH directory on the host
    # 4. Run the test script again, it will automatically copy packages to container and restore from local NuGet source

    if [[ ! -d "$TOOL_LEVEL_NUGET_SRC_HOST_PATH" ]]; then
        print_warning "Local NuGet source directory does not exist, creating: $TOOL_LEVEL_NUGET_SRC_HOST_PATH"
        mkdir -p "$TOOL_LEVEL_NUGET_SRC_HOST_PATH"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to create local NuGet source directory: $TOOL_LEVEL_NUGET_SRC_HOST_PATH"
            return 1
        fi
        print_warning "Please add the packed NuGet package to the local NuGet source directory: $TOOL_LEVEL_NUGET_SRC_HOST_PATH"
        print_warning "Then run the test script again to use the local NuGet source for test execution"
        return 0  # Early return - user needs to add packages first
    else
        print_info "Local NuGet source directory already exists: $TOOL_LEVEL_NUGET_SRC_HOST_PATH"
    fi

    # (Critical) Check if any Advantech.Edge NuGet package exists in local source directory
    # Using find command instead of glob to reliably detect files (glob fails silently if no matches)
    mapfile -t nuget_packages < <(find "$TOOL_LEVEL_NUGET_SRC_HOST_PATH" -maxdepth 1 -name "Advantech.Edge*.nupkg" -type f) 
    if [[ ${#nuget_packages[@]} -eq 0 ]]; then
        print_error "No Advantech.Edge NuGet packages found in local NuGet source directory: $TOOL_LEVEL_NUGET_SRC_HOST_PATH"
        print_error "Please add the packed NuGet package to this directory and run the script again"
        return 1
    fi

    detected_versions=$(printf '%s\n' "${nuget_packages[@]}" | sed -nE 's|^.*/Advantech\.Edge\.([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)\.nupkg$|\1|p' | awk '{ if (NR > 1) printf ", "; printf "%s", $0 } END { if (NR > 0) print "" }')
    print_info "NuGet package versions detected: $detected_versions"
    print_success "Found ${#nuget_packages[@]} NuGet package(s) in local source directory"

    # Extract package versions from filenames and determine the latest version to use for testing
    mapfile -t nupkg_versions < <(printf '%s\n' "${nuget_packages[@]}" | sed -nE 's|^.*/Advantech\.Edge\.([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)\.nupkg$|\1|p')
    if [[ ${#nupkg_versions[@]} -eq 0 ]]; then
        print_error "Failed to extract any package version from local nupkg filenames"
        return 1
    fi

    # Resolve package by requested version pattern from NUGET_PKG_TO_BE_TESTED
    # Example: 2.0.* -> latest matching 2.0.x, 2.*.* -> latest matching major 2
    version_regex=$(printf '%s' "$version_pattern" | sed -E 's/[.]/\\./g; s/\*/[0-9]+(-[0-9A-Za-z.-]+)?/g')
    mapfile -t matched_versions < <(printf '%s\n' "${nupkg_versions[@]}" | grep -E "^${version_regex}$")
    if [[ ${#matched_versions[@]} -eq 0 ]]; then
        print_error "No local package version matches NUGET_PKG_TO_BE_TESTED pattern: $version_pattern"
        print_error "Detected local versions: $detected_versions"
        return 1
    fi

    print_info "Requested version pattern: $version_pattern"
    print_info "Matched versions: $(printf '%s\n' "${matched_versions[@]}" | awk '{ if (NR > 1) printf ", "; printf "%s", $0 } END { if (NR > 0) print "" }')"

    resolved_version=$(printf '%s\n' "${matched_versions[@]}" | sort -V | tail -n 1)
    if [[ -z "$resolved_version" ]]; then
        print_error "Failed to resolve latest package version from local nupkg filenames"
        return 1
    fi

    resolved_package_path=$(printf '%s\n' "${nuget_packages[@]}" | grep -E "/Advantech\.Edge\.${resolved_version//./\.}\.nupkg$" | head -n 1)
    if [[ -z "$resolved_package_path" ]]; then
        print_error "Failed to resolve latest package path from local nupkg filenames"
        return 1
    fi

    NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE="$resolved_version"
    if command -v realpath >/dev/null 2>&1; then
        NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE="$(realpath "$resolved_package_path")"
    else
        NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE="$(cd "$(dirname "$resolved_package_path")" && pwd)/$(basename "$resolved_package_path")"
    fi
    export NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE

    print_info "NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE: $NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE"
    print_info "NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE: $NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE"
    print_success "Package selected: $NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE"

    return 0
}

run_test_image() {
    print_header "Run Test Container"

    # Check if docker compose file exists before attempting to run
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        print_error "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        return 1
    fi

    # Export variables so they're available to docker compose
    # Note: docker compose will automatically pick up environment variables from the shell,
    #       but we explicitly export them here for clarity
    export AZDO_PAT
    export AZDO_ARTIFACTS_FEED_NAME
    export AZDO_ARTIFACTS_FEED_URL
    export AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL
    export NUGET_PKG_TO_BE_TESTED
    export USE_LOCAL_NUGET_SOURCE
    export NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE
    export NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE
    export BYPASS_ADVANCED_TEST
    export REPORT_DIR
    export IMAGE
    
    # Stop & remove any existing container with the same name to avoid conflicts.
    # Try force-removal first; only fail if the container still exists afterwards.
    print_info "Ensuring no existing test container remains: $TEST_CONTAINER_NAME"
    if docker compose -f "$DOCKER_COMPOSE_FILE" rm -fs "$TEST_CONTAINER_NAME" > /dev/null 2>&1; then
        print_success "Existing test container removed (if present): $TEST_CONTAINER_NAME"
    else
        if docker compose -f "$DOCKER_COMPOSE_FILE" ps "$TEST_CONTAINER_NAME" | grep -q "$TEST_CONTAINER_NAME"; then
            print_error "Failed to remove existing container: $TEST_CONTAINER_NAME"
            return 1
        fi
        print_info "No existing test container found to remove: $TEST_CONTAINER_NAME"
    fi

    # If USE_LOCAL_NUGET_SOURCE is enabled, copy local NuGet packages from host to container before running the container
    # Using docker compose cp command to copy the local NuGet packages from TOOL_LEVEL_NUGET_SRC_HOST_PATH on host to TOOL_LEVEL_NUGET_SRC_CONTAINER_PATH in container,
    # so that the test can restore from the local NuGet source during execution without needing to pull from Azure DevOps Artifacts Feed,
    # and this also allows users to easily use a local NuGet source with the following steps:
    # 1. Enable USE_LOCAL_NUGET_SOURCE flag (not equals 0) in run_test.sh and run the script once to let it create directory specified by TOOL_LEVEL_NUGET_SRC_HOST_PATH (e.g. ./tool_level_local_nuget_source)
    # 2. Pack Advantech.Edge NuGet package locally with the expected version and naming convention (e.g. Advantech.Edge.1.2.3.nupkg)
    # 3. Copy the packed NuGet package to TOOL_LEVEL_NUGET_SRC_HOST_PATH directory on the host (e.g. ./tool_level_local_nuget_source)
    # 4. Run the test script again, and the script will automatically copy the package from TOOL_LEVEL_NUGET_SRC_HOST_PATH to 
    #    path specified by TOOL_LEVEL_NUGET_SRC_CONTAINER_PATH mounted on the container for restore during test execution.
    if [[ $USE_LOCAL_NUGET_SOURCE -ne 0 ]]; then
        local host_testtoolprocess_path="$(pwd)/src/TestToolProcess"
        local host_local_nuget_source_path="$host_testtoolprocess_path/local_nuget_source"

        print_info "USE_LOCAL_NUGET_SOURCE is enabled - preparing to copy local NuGet package to container"
        if [[ -z "$NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE" ]]; then
            print_error "Selected local NuGet package path is empty: NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE"
            return 1
        fi

        # Step 1: Ensure existing test container is removed to avoid lock issues when copying files to container
        print_info "Removing existing test container (if present)..."
        docker compose -f "$DOCKER_COMPOSE_FILE" rm -fs "$TEST_CONTAINER_NAME" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            print_error "Failed to remove existing test container"
            return 1
        fi
        print_success "Existing test container removed (if present)"

        # Step 2: Create local_nuget_source directory on host under TestToolProcess
        print_info "Creating local_nuget_source directory on host: $host_local_nuget_source_path"
        mkdir -p "$host_local_nuget_source_path"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to create local_nuget_source on host: $host_local_nuget_source_path"
            return 1
        fi
        print_success "Directory ready on host: $host_local_nuget_source_path"

        # Step 3: Create a fresh test container
        print_info "Creating a new test container..."
        docker compose -f "$DOCKER_COMPOSE_FILE" create "$TEST_CONTAINER_NAME"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to create test container"
            return 1
        fi
        print_success "New test container created successfully"

        # Step 4: Copy the package to the container using docker compose cp
        print_info "NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE: $NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE"
        docker compose -f "$DOCKER_COMPOSE_FILE" cp "$NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE" "$TEST_CONTAINER_NAME:$TOOL_LEVEL_NUGET_SRC_CONTAINER_PATH/"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to copy selected local NuGet package from host to container"
            return 1
        fi
        print_success "Selected local NuGet package copied to container successfully."
    fi

    echo ""
    echo "================================================================="
    echo "====== Starting running test container with docker compose ======"
    echo "================================================================="
    echo ""

    # Pass environment variables to docker-compose
    print_info "Run test container with the following configuration:"
    print_info "\tContainer image: $IMAGE"
    print_info "\tTest environment: $TEST_ENVIRONMENT_TYPE"
    print_info "\tDocker compose file: $DOCKER_COMPOSE_FILE"
    print_info "\tEnvironment variables used in container (Azure DevOps) :"
    print_info "\t\tPAT (show first 4 chars): $(echo "$AZDO_PAT" | sed 's/^\(....\).*/\1****/')"
    print_info "\t\tAZDO_ARTIFACTS_FEED_NAME: $AZDO_ARTIFACTS_FEED_NAME"
    print_info "\t\tAZDO_ARTIFACTS_FEED_URL: $AZDO_ARTIFACTS_FEED_URL"
    print_info "\t\tAZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL: $AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL"
    print_info "\tEnvironment variables used in container (NuGet Package Version) :"
    print_info "\t\tNUGET_PKG_TO_BE_TESTED: $NUGET_PKG_TO_BE_TESTED"
    print_info "\t\tNUGET_PKG_RESOLVED_BY_LOCAL_SOURCE: $NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE"
    print_info "\t\tNUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE: $NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE"
    print_info "\t\tUSE_LOCAL_NUGET_SOURCE: $USE_LOCAL_NUGET_SOURCE"

    # Run container via docker compose  
    docker compose -f "$DOCKER_COMPOSE_FILE" run --rm "$TEST_CONTAINER_NAME"
    local result=$?
    if [[ $result -eq 0 ]]; then
        print_success "Test container completed successfully"
    else
        print_error "Test container failed with exit code: $result"
    fi

    echo ""
    echo "================================================================="
    echo "====== End running test container with docker compose ======"
    echo "================================================================="
    echo ""
    
    return $result
}

cleanup_report_directory() {
    local host_report_dir=""

    print_header "Cleaning Previous Report Directory"

    # Container /reports is bind-mounted to host ./reports in docker-compose.
    # Convert container report path to host path for cleanup.
    host_report_dir=".${REPORT_DIR}"

    if [[ -d "$host_report_dir" ]]; then
        print_info "Removing report directory: $host_report_dir"
        rm -rf "$host_report_dir"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to remove report directory: $host_report_dir"
            return 1
        fi
        print_success "Removed report directory: $host_report_dir"
    else
        print_info "Report directory does not exist, skip remove: $host_report_dir"
    fi

    return 0
}

#################################################################

# --- Main Execution ---

clear

print_header "Advantech Device Library Test Tool"

# Load environment configuration
load_env_file
if [[ $? -ne 0 ]]; then
    print_error "Failed to load environment configuration"
    exit 1
fi

# Check Docker is available first (fail-fast)
check_docker_available
if [[ $? -ne 0 ]]; then
    print_error "Docker is not available - please install Docker and docker compose"
    exit 1
fi

# Verify Harbor image is available (fail-fast)
verify_harbor_image_availability
if [[ $? -ne 0 ]]; then
    print_error "Failed to verify Harbor image availability"
    exit 1
fi

# Setup and verify environment (detect, validate, verify docker-compose file)
setup_and_verify_environment
if [[ $? -ne 0 ]]; then
    print_error "Failed to setup and verify environment"
    exit 1
fi

# Verify and prepare local NuGet source if enabled
verify_and_prepare_local_nuget_source
if [[ $? -ne 0 ]]; then
    exit 0  # Early exit if user needs to add packages first
fi

# Run test image
run_test_image
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    print_success "Test execution completed successfully"
else
    print_error "Test execution failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
