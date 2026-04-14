#!/bin/bash
# ==========================================================
# Advantech Edge - Device Library Test Tool (Container)
# ==========================================================
# Runtime test execution script for containerized testing
# Fetches NuGet packages, compiles, and executes C# tests
# ==========================================================
# Valid exit codes:
# 0 - Success: All tests passed and reports collected
# 1 - Failure: General failure (e.g. missing env vars, restore/build/test failures)
# 255 - Debug Stop: Script stopped for debugging purposes (not an error)
# ==========================================================

set -o pipefail

# --- Configuration ---
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXIT_CODE=0

# --- Color Definitions ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ------------------------------------------------------------
# --------------------- Helper Functions ---------------------
# ------------------------------------------------------------

print_header() {
    echo -e "\n[Container] ${BLUE}====== $1 ======${NC}"
}

print_success() {
    echo -e "[Container] ${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "[Container] ${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "[Container] ${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "[Container] ${BLUE}ℹ $1${NC}"
}

# ---------------------------------------------------------------
# --------------------- Main Flow Functions ---------------------
# ---------------------------------------------------------------

verify_required_environment_variables() {
    print_header "Step : Verifying Environment Variables"

    if [[ -z "${AZDO_PAT}" ]]; then
        print_error "Required environment variable not set: AZDO_PAT"
        return 1
    fi

    if [[ -z "${AZDO_ARTIFACTS_FEED_NAME}" ]]; then
        print_error "Required environment variable not set: AZDO_ARTIFACTS_FEED_NAME"
        return 1
    fi

    if [[ -z "${AZDO_ARTIFACTS_FEED_URL}" ]]; then
        print_error "Required environment variable not set: AZDO_ARTIFACTS_FEED_URL"
        return 1
    fi

    if [[ -z "${AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL}" ]]; then
        print_error "Required environment variable not set: AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL"
        return 1
    fi

    if [[ -z "${NUGET_PKG_TO_BE_TESTED}" ]]; then
        print_error "Required environment variable not set: NUGET_PKG_TO_BE_TESTED"
        return 1
    fi

    if [[ -z "${NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE}" ]]; then
        print_error "Required environment variable not set: NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE"
        return 1
    fi

    if [[ -z "${NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE}" ]]; then
        print_error "Required environment variable not set: NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE"
        return 1
    fi

    if [[ -z "${USE_LOCAL_NUGET_SOURCE}" ]]; then
        print_error "Required environment variable not set: USE_LOCAL_NUGET_SOURCE"
        return 1
    fi

    print_info "AZDO_ARTIFACTS_FEED_NAME: ${AZDO_ARTIFACTS_FEED_NAME}"
    print_info "AZDO_ARTIFACTS_FEED_URL: ${AZDO_ARTIFACTS_FEED_URL}"
    print_info "AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL: ${AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL}"
    print_info "NUGET_PKG_TO_BE_TESTED: ${NUGET_PKG_TO_BE_TESTED}"
    print_info "USE_LOCAL_NUGET_SOURCE: ${USE_LOCAL_NUGET_SOURCE}"
    print_info "NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE: ${NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE}"
    print_info "NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE: ${NUGET_PKG_PATH_RESOLVED_BY_LOCAL_SOURCE}"

    print_success "All required environment variables are set"
    
    return 0
}

configure_nuget_credentials_for_azdo_feed() {
    print_header "Step : Configure NuGet credentials for Azure DevOps feed"
    local nuget_source_exists=0

    export VSS_NUGET_ACCESSTOKEN="$AZDO_PAT"
    print_info "Azure DevOps PAT (show first 4 chars): ${AZDO_PAT:0:4}**** (hidden for security)"

    # Add PAT to global NuGet credentials for AZDO_ARTIFACTS_FEED_NAME.
    if dotnet nuget list source | grep -q "$AZDO_ARTIFACTS_FEED_NAME"; then
        nuget_source_exists=1
    fi

    if [[ $nuget_source_exists -eq 1 ]]; then
        dotnet nuget update source "$AZDO_ARTIFACTS_FEED_NAME" \
            --source "$AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL" \
            --username "azdo" \
            --password "$AZDO_PAT" \
            --store-password-in-clear-text >/dev/null 2>&1
    else
        dotnet nuget add source "$AZDO_ARTIFACTS_FEED_NUGET_SOURCE_URL" \
            --name "$AZDO_ARTIFACTS_FEED_NAME" \
            --username "azdo" \
            --password "$AZDO_PAT" \
            --store-password-in-clear-text >/dev/null 2>&1
    fi

    if [[ $? -ne 0 ]]; then
        print_error "Failed to configure global NuGet credentials for source: $AZDO_ARTIFACTS_FEED_NAME"
        return 1
    fi

    print_success "Configured global NuGet credentials for source: $AZDO_ARTIFACTS_FEED_NAME"

    return 0
}

change_to_project_directory() {
    print_header "Step : Change to project directory"

    # Change to project directory
    cd /app/TestToolProcess
    if [[ $? -ne 0 ]]; then
        print_error "Failed to change directory to /app/TestToolProcess"
        return 1
    fi

    print_success "Current working directory: $(pwd)"
    return 0
}

clean_previous_build_artifacts() {
    print_header "Step : Clean previous build artifacts"

    # Explicitly remove TestToolProcess build output directories
    print_info "Removing TestToolProcess bin and obj directories..."
    rm -rf ./bin ./obj
    if [[ -d "./bin" || -d "./obj" ]]; then
        print_error "Failed to remove TestToolProcess bin and obj directories"
        return 1
    else
        print_success "Removed TestToolProcess bin and obj directories"
    fi

    # Additionally run 'dotnet clean' to ensure any other build artifacts are cleared and check for success
    dotnet clean -v q -c Release -p:NUGET_PACKAGE_VERSION="$NUGET_PACKAGE_VERSION"
    if [[ $? -ne 0 ]]; then
        print_error "dotnet clean failed"
        return 1
    else
        print_success "dotnet clean completed successfully"
    fi

    return 0
}

verify_feed_connectivity_via_rest_api() {
    local encoded_pat="$1"
    local response=""

    if [[ -z "$encoded_pat" ]]; then
        encoded_pat=$(echo -n ":${AZDO_PAT}" | base64 | tr -d '\n')
    fi

    response=$(curl -s -L -o /dev/null -w "%{http_code}" \
        -H "Authorization: Basic ${encoded_pat}" \
        "${AZDO_ARTIFACTS_FEED_URL}?api-version=6.0-preview.1" 2>/dev/null)

    if [[ ! "$response" =~ ^[23][0-9]{2}$ ]]; then
        print_error "NuGet Feed connectivity failed (HTTP $response)"
        print_error "Please verify:"
        print_error "  1. Feed URL is correct and accessible: $AZDO_ARTIFACTS_FEED_URL"
        print_error "  2. AZDO_PAT has 'Package Read' permission scope"
        print_error "  3. Network connectivity to feeds.dev.azure.com"
        return 1
    fi

    print_success "NuGet Feed is reachable and authentication is valid (HTTP $response)"
    return 0
}

select_and_apply_advantech_edge_version_for_testprocess_csproj() {
    print_header "Step : Select and apply Advantech.Edge version in TestToolProcess.csproj"

    local pattern=""
    local encoded_pat=""
    local all_packages=""
    local resolved=""
    local testprocess_csproj_path="/app/TestToolProcess/TestToolProcess.csproj"

    if [[ $USE_LOCAL_NUGET_SOURCE -eq 0 ]]; then
        print_info "USE_LOCAL_NUGET_SOURCE is 0, resolving version by REST API using pattern: $NUGET_PKG_TO_BE_TESTED"

        # Resolve NuGet package version by REST API when local source is disabled
        print_info "Azure DevOps Artifacts Feed URL: $AZDO_ARTIFACTS_FEED_URL"

        if ! command -v curl &> /dev/null; then
            print_error "curl is required to resolve floating version"
            return 1
        fi

        pattern="$NUGET_PKG_TO_BE_TESTED"
        print_info "Input version pattern: $pattern"
        if [[ "$pattern" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?$ ]]; then
            print_info "Version is concrete (not floating): $pattern"
            NUGET_PKG_RESOLVED_BY_REST_API="$pattern"
        else
            encoded_pat=$(echo -n ":${AZDO_PAT}" | base64 | tr -d '\n')
            verify_feed_connectivity_via_rest_api "$encoded_pat"
            if [[ $? -ne 0 ]]; then
                return 1
            fi

            print_info "Step 1: Fetching packages matching 'Advantech.Edge' from feed..."
            all_packages=$(curl -s -L -H "Authorization: Basic ${encoded_pat}" \
                "${AZDO_ARTIFACTS_FEED_URL}/packages?packageNameQuery=Advantech.Edge&protocolType=nuget&includeAllVersions=true&api-version=6.0-preview.1" \
                2>/dev/null)

            if [[ "$all_packages" != *"advantech.edge"* ]]; then
                print_error "Package 'Advantech.Edge' not found in feed"
                return 1
            fi
            print_success "Package 'advantech.edge' found, proceeding to extract versions..."

            print_info "Step 2: Filtering versions matching pattern: $pattern"
            resolved=$(echo "$all_packages" | \
                grep -o '"version":"[^"]*"' | \
                cut -d'"' -f4 | \
                grep -E "^${pattern//\*/[0-9]+}" | \
                sort -V | \
                tail -1)

            if [[ -z "$resolved" ]]; then
                print_error "Could not find any version matching pattern: $pattern"
                print_error "Please verify:"
                print_error "  1. NUGET_PKG_TO_BE_TESTED pattern in .env is correct"
                print_error "  2. Package 'Advantech.Edge' exists in the NuGet Feed"
                print_error "  3. At least one version matching the pattern exists"
                print_error "  4. Azure DevOps Packaging API is accessible"
                return 1
            fi

            NUGET_PKG_RESOLVED_BY_REST_API="$resolved"
            print_success "Resolved version: $NUGET_PKG_RESOLVED_BY_REST_API"
        fi

        NUGET_PACKAGE_VERSION="$NUGET_PKG_RESOLVED_BY_REST_API"
        if [[ -z "$NUGET_PACKAGE_VERSION" ]]; then
            print_error "Resolved REST API version is empty"
            return 1
        fi
        print_info "Version source: REST API"
    else
        print_info "USE_LOCAL_NUGET_SOURCE is not 0, using local resolved version directly"
        NUGET_PACKAGE_VERSION="$NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE"
        if [[ -z "$NUGET_PACKAGE_VERSION" ]]; then
            print_error "Local resolved version is empty: NUGET_PKG_RESOLVED_BY_LOCAL_SOURCE"
            return 1
        fi
        print_info "Version source: local NuGet source"
    fi

    export NUGET_PACKAGE_VERSION
    print_info "Selected Advantech.Edge version for test: $NUGET_PACKAGE_VERSION"

    if [[ ! -f "$testprocess_csproj_path" ]]; then
        print_error "TestToolProcess.csproj not found: $testprocess_csproj_path"
        return 1
    fi

    # Update Advantech.Edge PackageReference version in csproj to selected test version
    sed -i -E "s|(<PackageReference[^>]*Include=\"Advantech\\.Edge\"[^>]*Version=\")[^\"]*(\")|\1${NUGET_PACKAGE_VERSION}\2|" "$testprocess_csproj_path"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to update Advantech.Edge PackageReference version in TestToolProcess.csproj"
        return 1
    fi

    if ! grep -q "<PackageReference Include=\"Advantech.Edge\" Version=\"${NUGET_PACKAGE_VERSION}\"" "$testprocess_csproj_path"; then
        print_error "Failed to verify updated Advantech.Edge PackageReference version in TestToolProcess.csproj"
        return 1
    fi

    print_success "Updated Advantech.Edge PackageReference version to ${NUGET_PACKAGE_VERSION} in TestToolProcess.csproj"
    return 0
}

verify_local_nuget_source_if_enabled() {
    print_header "Step : Verify local NuGet source if enabled"

    local project_nuget_config_path=""
    local dotnet_nuget_sources_result=""
    local NUGET_LOCAL_SOURCE_NAME=""
    local NUGET_LOCAL_SOURCE_PATH=""

    if [[ $USE_LOCAL_NUGET_SOURCE -eq 0 ]]; then
        print_info "USE_LOCAL_NUGET_SOURCE is 0, skipping local NuGet source verification"
        return 0
    fi

    # Check existence
    project_nuget_config_path="$(pwd)/nuget.config"
    print_info "Project-level nuget.config path: $project_nuget_config_path"
    if [[ ! -f "$project_nuget_config_path" ]]; then
        print_error "Project-level NuGet configuration not found: $project_nuget_config_path"
        return 1
    fi
    print_success "Project-level NuGet configuration found"

    # List NuGet sources using --configfile to read ONLY project-level configuration (not global/user level)
    # This ensures we get accurate source information from nuget.config without interference from global config
    # Format of nuget.config :
    # <?xml version="1.0" encoding="utf-8"?>
    # <configuration>
    #   <packageSources>
    #     <clear />
    #     <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    #     <add key="EngineeringRelease" value="https://pkgs.dev.azure.com/Advantech-EBO/_packaging/EngineeringRelease/nuget/v3/index.json" />
    #     <add key="LocalTempSource" value="/app/TestToolProcess/local_nuget_source" />
    #   </packageSources>
    # </configuration>
    dotnet_nuget_sources_result=$(dotnet nuget list source --configfile "$project_nuget_config_path")
    if [[ $? -ne 0 ]]; then
        print_error "Failed to list NuGet sources from project-level configuration"
        return 1
    fi
    if [[ -z "$dotnet_nuget_sources_result" ]]; then
        print_error "No NuGet sources found in project-level configuration"
        return 1
    fi

    # Extract local NuGet source information (name and path) using awk
    # This approach is robust to source order changes because:
    # 1. It pairs source names with their paths sequentially
    # 2. It then finds the pair containing "local_nuget_source"
    # 3. No order dependency - works regardless of where local source is listed
    read -r NUGET_LOCAL_SOURCE_NAME NUGET_LOCAL_SOURCE_PATH < <(
        echo "$dotnet_nuget_sources_result" | awk '
        BEGIN { prev_name = "" }

        /^[[:space:]]*[0-9]+\./ {
            # Source name line (e.g.: 1.  LocalTempSource [Enabled])
            prev_name = $2
        }

        /local_nuget_source/ {
            # Path line - remove leading whitespace
            path = $0
            gsub(/^[[:space:]]+/, "", path)

            if (prev_name != "") {
                print prev_name, path
                exit
            }
        }
        '
    )

    if [[ -z "$NUGET_LOCAL_SOURCE_NAME" || -z "$NUGET_LOCAL_SOURCE_PATH" ]]; then
        print_error "Failed to extract local NuGet source (name: '$NUGET_LOCAL_SOURCE_NAME', path: '$NUGET_LOCAL_SOURCE_PATH')"
        return 1
    fi

    print_info "Extracted local NuGet source info from project-level nuget.config:"
    print_info "\t\tName: $NUGET_LOCAL_SOURCE_NAME"
    print_info "\t\tPath: $NUGET_LOCAL_SOURCE_PATH"

    # Verify the local NuGet source directory exists (should have been created by host before container start)
    if [[ ! -d "$NUGET_LOCAL_SOURCE_PATH" ]]; then
        print_error "Local NuGet source directory not found."
        return 1
    fi

    print_success "Local NuGet source directory found."

    return 0
}

ensure_selected_package_restored() {
    print_header "Step : Ensure selected package is restored"
    local restore_list_output=""
    local resolved_version=""

    # Clear NuGet cache to ensure we get the correct version and check clearance
    print_info "Clear NuGet cache..."
    rm -rf ~/.nuget/packages
    if [[ $? -ne 0 ]]; then
        print_error "Failed to clear NuGet cache"
        return 1
    fi
    print_success "NuGet cache cleared successfully"

    # Additionally clear local cache using dotnet CLI to ensure all sources are cleared and check clearance
    print_info "Additionally clearing local NuGet cache using dotnet CLI..."
    dotnet nuget locals all --clear >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        print_error "Failed to clear local NuGet cache"
        return 1     
    fi
    print_success "Executed successfully"

    # Restore NuGet packages for TestToolProcess
    print_info "Restoring NuGet packages for TestToolProcess..."
    dotnet restore
    if [[ $? -ne 0 ]]; then
        print_error "dotnet restore failed"
        return 1
    fi
    print_success "dotnet restore completed successfully"

    # Verify restored Advantech.Edge package version matches selected test version
    print_info "Executing 'dotnet list package' to verify restored package version..."
    restore_list_output=$(dotnet list package -v q)
    if [[ $? -ne 0 ]]; then
        print_error "Failed to list restored packages"
        return 1
    fi
    print_success "Listed restored packages successfully"

    resolved_version=$(echo "$restore_list_output" | grep "Advantech.Edge" | awk '{print $3}')
    if [[ -z "$resolved_version" ]]; then
        print_error "Failed to extract resolved version of Advantech.Edge package"
        return 1
    elif [[ "$resolved_version" != "$NUGET_PACKAGE_VERSION" ]]; then
        print_error "Resolved version ($resolved_version) does not match expected version ($NUGET_PACKAGE_VERSION)"
        return 1
    else
        print_success "Resolved version of Advantech.Edge package matched. Resolved version: $resolved_version"
    fi

    if [[ $? -ne 0 ]]; then
        print_error "Failed to restore and verify Advantech.Edge package version"
        return 1
    fi

    return 0
}

build_and_run_test_project() {
    print_header "Step : Build and run test project"
    local app_dll_path=""

    # Build the test project in Release configuration
    print_info "Building test project in Release configuration..."
    dotnet build -c Release
    if [[ $? -ne 0 ]]; then
        print_error "Failed to build test project. Exiting..."
        return 1
    else
        print_success "Test project built successfully"
    fi

    # Resolve compiled DLL path from Release output
    app_dll_path=$(find ./bin/Release -type f -name "TestToolProcess.dll" ! -path "*/ref/*" | sort | head -n 1)
    if [[ -z "$app_dll_path" ]]; then
        print_error "Failed to locate TestToolProcess.dll under ./bin/Release"
        return 1
    fi
    print_info "Resolved application DLL: $app_dll_path"

    # Run the test project via compiled DLL
    print_info "Running test project via dotnet DLL..."
    REPORT_DIR="/reports/CSharp/log"
    BYPASS_ADVANCED_TEST=${BYPASS_ADVANCED_TEST:-false}
    dotnet "$app_dll_path" "$REPORT_DIR" "$BYPASS_ADVANCED_TEST"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to run test project. Exiting..."
        return 1
    else
        print_success "Test project ran successfully"
    fi

    return 0
}

# --------------------------------------------------------------------------
# -------------------------- Main Flow Start HERE --------------------------
# --------------------------------------------------------------------------

# ---------------------------------------------
# ------------ Stage : Preparation ------------
# ---------------------------------------------

print_header "Stage : Preparation"

# --- Step 1: Verify required environment variables ---
verify_required_environment_variables
if [[ $? -ne 0 ]]; then
    print_error "Failed to verify required environment variables"
    exit 1
fi

# --- Step 2: Verify NuGet feed connectivity via REST API ---
verify_feed_connectivity_via_rest_api
if [[ $? -ne 0 ]]; then
    print_error "Failed to verify NuGet feed connectivity via REST API"
    exit 1
fi

# ---------------------------------------------
# --- Stage : Rebuild & Run TestToolProcess ---
# ---------------------------------------------

print_header "Stage : Rebuild & Run TestToolProcess"

# --- Step : Change to project directory for subsequent operations ---
change_to_project_directory
if [[ $? -ne 0 ]]; then
    print_error "Failed to change to project directory"
    exit 1
fi

# --- Step : Configure NuGet credentials for Azure DevOps feed ---
configure_nuget_credentials_for_azdo_feed
if [[ $? -ne 0 ]]; then
    print_error "Failed to configure NuGet credentials for Azure DevOps feed"
    exit 1
fi

# --- Step : Clean previous build artifacts before building and running tests ---
clean_previous_build_artifacts
if [[ $? -ne 0 ]]; then
    print_error "Failed to clean previous build artifacts"
    exit 1
fi

# --- Step : Select Advantech.Edge version and apply it to TestToolProcess.csproj ---
select_and_apply_advantech_edge_version_for_testprocess_csproj
if [[ $? -ne 0 ]]; then
    print_error "Failed to select and apply Advantech.Edge version for TestToolProcess.csproj"
    exit 1
fi

# --- Step : Verify local NuGet source if enabled ---
verify_local_nuget_source_if_enabled
if [[ $? -ne 0 ]]; then
    print_error "Failed to verify local NuGet source when enabled"
    exit 1
fi

# --- Step : Ensure selected package is restored ---
ensure_selected_package_restored
if [[ $? -ne 0 ]]; then
    print_error "Failed to ensure selected package is restored"
    exit 1
fi

# --- Step : Build and run the test project in Release configuration ---
build_and_run_test_project
if [[ $? -ne 0 ]]; then
    print_error "Failed to build and run test project"
    exit 1
fi

# --- Step : Summary ---
print_header "Execution Summary"

if [[ $EXIT_CODE -eq 0 ]]; then
    print_success "Test execution completed successfully"
    print_info "Reports location: $REPORT_DIR"
else
    print_error "Test execution failed with exit code: $EXIT_CODE"
fi
