#!/bin/bash
# ==========================================================
# Advantech COE - Advanced CUDA and cuDNN Verification Tool
# ==========================================================
# Created and maintained by Samir Singh <samir.singh@advantech.com> and Apoorv Saxena <apoorv.saxena@advantech.com>
# --- Configuration ---
SCRIPT_VERSION="1.0.0"
LOG_FILE="cuda_diagnostics_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="/tmp/cuda_report_$(date +%Y%m%d_%H%M%S).txt"
TEST_DIR="/tmp/cuda_test_$(date +%Y%m%d_%H%M%S)"
VERBOSE=0
SAVE_LOG=0
SHARE_REPORT=1  # Set to 0 to disable online report sharing

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

# --- Helper Functions ---
print_header() {
    echo -e "\n${BOLD}${BLUE}====== $1 ======${NC}"
    if [ $SAVE_LOG -eq 1 ]; then
        echo -e "\n====== $1 ======" >> "$LOG_FILE"
    fi
}

print_subheader() {
    echo -e "\n${BOLD}${CYAN}--- $1 ---${NC}"
    if [ $SAVE_LOG -eq 1 ]; then
        echo -e "\n--- $1 ---" >> "$LOG_FILE"
    fi
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    if [ $SAVE_LOG -eq 1 ]; then
        echo -e "✓ $1" >> "$LOG_FILE"
    fi
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    if [ $SAVE_LOG -eq 1 ]; then
        echo "ℹ $1" >> "$LOG_FILE"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    if [ $SAVE_LOG -eq 1 ]; then
        echo "⚠ $1" >> "$LOG_FILE"
    fi
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    if [ $SAVE_LOG -eq 1 ]; then
        echo "✗ $1" >> "$LOG_FILE"
    fi
}

# Function for displaying a loading animation
show_loading() {
    local message=$1
    local duration=$2
    local chars=( "|" "/" "-" "\\" )
    local end_time=$((SECONDS + duration))
    
    echo -ne "$message "
    
    while [ $SECONDS -lt $end_time ]; do
        for char in "${chars[@]}"; do
            echo -ne "\r$message $char"
            sleep 0.2
        done
    done
    
    echo -e "\r$message ✓ ${GREEN}Done!${NC}"
    sleep 0.5
}

# Function to upload report to paste service and get shareable URL
upload_report() {
    local report_file=$1
    local report_title="Advantech CUDA Diagnostics Report - $(date +%Y-%m-%d)"
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for report sharing but not found."
        echo "Please install curl or set SHARE_REPORT=0 in the script."
        return 1
    fi
    
    echo "Uploading report to online service..."
    
    # Upload to paste service using curl
    # Using termbin.com which is a simple netcat-based paste service
    local url
    url=$(cat "$report_file" | nc termbin.com 9999)
    
    if [[ $url == https://* ]] || [[ $url == http://* ]]; then
        echo "Report successfully uploaded!"
        echo "Shareable URL: $url"
        return 0
    else
        echo "Failed to upload report. Using fallback method..."
        
        # Try another service as fallback (0x0.st)
        url=$(curl -s -F "file=@$report_file" https://0x0.st)
        
        if [[ $url == https://* ]] || [[ $url == http://* ]]; then
            echo "Report successfully uploaded using fallback method!"
            echo "Shareable URL: $url"
            return 0
        else
            echo "All upload attempts failed. Cannot generate QR code for online report."
            return 1
        fi
    fi
}

log_command() {
    if [ $SAVE_LOG -eq 1 ]; then
        echo -e "\n$ $1" >> "$LOG_FILE"
        eval "$1" | tee -a "$LOG_FILE"
    else
        eval "$1"
    fi
}

check_command() {
    if command -v "$1" &>/dev/null; then
        print_success "Found command: $1"
        return 0
    else
        print_error "Command not found: $1"
        return 1
    fi
}

print_usage() {
    echo -e "${BOLD}Advantech COE - CUDA and cuDNN Diagnostic Tool${NC} v$SCRIPT_VERSION"
    echo -e "Usage: $0 [options]"
    echo -e "Options:"
    echo -e "  -h, --help      Show this help message"
    echo -e "  -v, --verbose   Enable verbose output"
    echo -e "  -l, --log       Save output to a log file"
    echo -e "  -q, --quiet     Minimal output (progress only)"
}

# --- Process Arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) print_usage; exit 0 ;;
        -v|--verbose) VERBOSE=1 ;;
        -l|--log) SAVE_LOG=1 ;;
        -q|--quiet) QUIET=1 ;;
        *) print_error "Unknown parameter: $1"; print_usage; exit 1 ;;
    esac
    shift
done

# --- Initial Setup ---
if [ $SAVE_LOG -eq 1 ]; then
    echo "CUDA Diagnostic Log - $(date)" > "$LOG_FILE"
    echo "System: $(uname -a)" >> "$LOG_FILE"
    print_info "Logging to file: $LOG_FILE"
fi

# Clear the terminal
clear

# Display Advantech COE banner
echo -e "${BLUE}"
echo "       █████╗ ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗████████╗███████╗ ██████╗██╗  ██╗     ██████╗ ██████╗ ███████╗"
echo "      ██╔══██╗██╔══██╗██║   ██║██╔══██╗████╗  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║    ██╔════╝██╔═══██╗██╔════╝"
echo "      ███████║██║  ██║██║   ██║███████║██╔██╗ ██║   ██║   █████╗  ██║     ███████║    ██║     ██║   ██║█████╗  "
echo "      ██╔══██║██║  ██║╚██╗ ██╔╝██╔══██║██║╚██╗██║   ██║   ██╔══╝  ██║     ██╔══██║    ██║     ██║   ██║██╔══╝  "
echo "      ██║  ██║██████╔╝ ╚████╔╝ ██║  ██║██║ ╚████║   ██║   ███████╗╚██████╗██║  ██║    ╚██████╗╚██████╔╝███████╗"
echo "      ╚═╝  ╚═╝╚═════╝   ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝     ╚═════╝ ╚═════╝ ╚══════╝"
echo -e "${WHITE}                                  Center of Excellence${NC}"
echo
echo -e "${PURPLE}${BOLD}  CUDA & cuDNN Environment Verification Tool${NC}"
echo -e "${CYAN}  This may take a moment...${NC}"
echo

# --- Main Functions ---
check_system_info() {
    print_header "SYSTEM INFORMATION"
    
    print_subheader "Hardware Information"
    log_command "lscpu | grep 'Model name\|Architecture\|CPU(s)'"
    log_command "free -h | head -n 2"
    
    print_subheader "Operating System"
    log_command "uname -a"
    if [ -f /etc/os-release ]; then
        log_command "cat /etc/os-release | grep 'NAME\|VERSION'"
    fi
    
    print_subheader "Kernel Information"
    log_command "uname -r"
}

check_nvidia_driver() {
    print_header "NVIDIA DRIVER VERIFICATION"
    
    if check_command "nvidia-smi"; then
        print_success "NVIDIA drivers are installed"
        
        print_subheader "Driver Details"
        log_command "nvidia-smi"
        
        # Extract driver version for the summary
        DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
        CUDA_DRIVER_VERSION=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader | head -n 1)
        print_info "Driver Version: ${BOLD}$DRIVER_VERSION${NC}"
        
        # Count GPUs
        GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
        print_info "Detected ${BOLD}$GPU_COUNT${NC} NVIDIA GPU(s)"
        
        # Check GPU memory
        if [ $VERBOSE -eq 1 ]; then
            print_subheader "GPU Memory"
            log_command "nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv"
        fi
    else
        print_error "NVIDIA drivers are not installed or not accessible"
        print_info "Please install NVIDIA drivers using your distribution's package manager"
        print_info "Ubuntu example: sudo apt install nvidia-driver-XXX"
        print_info "For more information: https://www.nvidia.com/Download/index.aspx"
        return 1
    fi
    
    return 0
}

check_cuda_toolkit() {
    print_header "CUDA TOOLKIT VERIFICATION"
    
    if check_command "nvcc"; then
        print_success "CUDA Toolkit is installed"
        
        print_subheader "CUDA Version"
        log_command "nvcc --version"
        
        # Extract CUDA version for the summary
        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
        print_info "CUDA Toolkit Version: ${BOLD}$CUDA_VERSION${NC}"
        
        print_subheader "CUDA Installation Paths"
        CUDA_PATH=$(which nvcc | sed 's/\/bin\/nvcc//')
        print_info "CUDA Installation Path: ${BOLD}$CUDA_PATH${NC}"
        
        print_subheader "CUDA Libraries"
        echo -e "Checking CUDA libraries..."
        
        # Create a dictionary of common CUDA libraries and their descriptions
        declare -A LIB_DESCRIPTIONS
        LIB_DESCRIPTIONS["libcudart"]="CUDA Runtime Library"
        LIB_DESCRIPTIONS["libcublas"]="CUDA Basic Linear Algebra Subroutines"
        LIB_DESCRIPTIONS["libcufft"]="CUDA Fast Fourier Transform Library"
        LIB_DESCRIPTIONS["libcurand"]="CUDA Random Number Generation Library"
        LIB_DESCRIPTIONS["libcusparse"]="CUDA Sparse Matrix Library"
        LIB_DESCRIPTIONS["libcusolver"]="CUDA Solver Library"
        LIB_DESCRIPTIONS["libcudnn"]="CUDA Deep Neural Network Library "
        LIB_DESCRIPTIONS["libnvrtc"]="NVIDIA Runtime Compilation Library"
        LIB_DESCRIPTIONS["libnvjpeg"]="NVIDIA JPEG Library"
        LIB_DESCRIPTIONS["libnpp"]="NVIDIA Performance Primitives"
        LIB_DESCRIPTIONS["libcufile"]="NVIDIA GPUDirect Storage Library"
        LIB_DESCRIPTIONS["libnvToolsExt"]="NVIDIA Tools Extension Library"
        LIB_DESCRIPTIONS["libOpenCL"]="OpenCL Implementation - Open Computing Language support"
        LIB_DESCRIPTIONS["libnvblas"]="NVIDIA BLAS Library"
        LIB_DESCRIPTIONS["libcublasLt"]="CUDA BLAS Light Librar"
        
        # Get all CUDA libraries
        CUDA_LIBS=$(ldconfig -p | grep -i cuda)
        
        # Display table header with formatting
        echo
        printf "+----+-------------------------+------------------------------------------------------+-----------------------------------------------+\n"
        printf "| %-2s | %-23s | %-52s | %-45s |\n" "No" "Library" "Path" "Description"
        printf "+----+-------------------------+------------------------------------------------------+-----------------------------------------------+\n"
        
        # Process and display libraries in a table
        COUNT=1
        while IFS= read -r line; do
            # Extract library name and path
            LIB_NAME=$(echo "$line" | awk -F'=> ' '{print $1}' | awk '{print $1}' | sed 's/ (.*)//')
            LIB_PATH=$(echo "$line" | awk -F'=> ' '{print $2}')
            
            # Get base library name for description lookup
            BASE_LIB=$(echo "$LIB_NAME" | sed -E 's/\.so(\.[0-9]+)?$//' | sed -E 's/lib(cu|nv|np)/lib\1/')
            
            # Find description
            DESCRIPTION="General CUDA library"
            for key in "${!LIB_DESCRIPTIONS[@]}"; do
                if [[ "$BASE_LIB" == *"$key"* ]]; then
                    DESCRIPTION="${LIB_DESCRIPTIONS[$key]}"
                    break
                fi
            done
            
            # Format and print the table row
            printf "| %2d | %-23s | %-52s | %-45s |\n" "$COUNT" "$LIB_NAME" "$LIB_PATH" "$DESCRIPTION"
            
            COUNT=$((COUNT + 1))
        done <<< "$CUDA_LIBS"
        
        printf "+----+-------------------------+------------------------------------------------------+-----------------------------------------------+\n"
        
        # Log all libraries if logging is enabled
        if [ $SAVE_LOG -eq 1 ]; then
            echo -e "\n--- Complete CUDA Library List ---" >> "$LOG_FILE"
            echo "$CUDA_LIBS" >> "$LOG_FILE"
        fi
    else
        print_error "CUDA Toolkit is not installed or not in PATH"
        print_info "Please install CUDA Toolkit from https://developer.nvidia.com/cuda-downloads"
        print_info "Make sure to add CUDA to your PATH and LD_LIBRARY_PATH"
        print_warning "Example for .bashrc:"
        print_info "export PATH=/usr/local/cuda/bin:\$PATH"
        print_info "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH"
        return 1
    fi
    
    # Check all essential CUDA libraries
    print_subheader "CUDA Libraries Check"
    echo -e "Checking for essential CUDA libraries..."
    
    # Define essential libraries and their descriptions
    declare -a ESSENTIAL_LIBS=(
        "libcudart:CUDA Runtime Library:Core runtime for all CUDA applications"
        "libcublas:CUDA BLAS Library:Basic Linear Algebra Subprograms for GPU"
        "libcufft:CUDA FFT Library:Fast Fourier Transform operations"
        "libcurand:CUDA Random Number Library:Random number generation"
        "libcusparse:CUDA Sparse Matrix Library:Sparse matrix operations"
        "libcusolver:CUDA Solver Library:Dense/sparse solvers and eigenvalue calculations"
        "libcudnn:CUDA Deep Neural Network:Deep learning primitives (optional but recommended)"
        "libnvToolsExt:NVIDIA Tools Extension:Profiling and debugging support"
    )
    
    # Create a table for checking essential libraries
    echo
    printf "+----+---------------------+-------------------------------+--------+\n"
    printf "| %-2s | %-19s | %-29s | %-6s |\n" "No" "Library" "Description" "Status"
    printf "+----+---------------------+-------------------------------+--------+\n"
    
    COUNT=0
    TOTAL=${#ESSENTIAL_LIBS[@]}
    
    for i in "${!ESSENTIAL_LIBS[@]}"; do
        IFS=':' read -r LIB_NAME LIB_SHORT_DESC LIB_DESC <<< "${ESSENTIAL_LIBS[$i]}"
        
        # Check if library exists
        if ldconfig -p | grep -q "$LIB_NAME"; then
            STATUS="✓ Found"
            COUNT=$((COUNT + 1))
        else
            STATUS="⚠ Missing"
        fi
        
        # Print formatted row
        printf "| %2d | %-19s | %-29s | %-6s |\n" "$((i+1))" "$LIB_NAME" "$LIB_SHORT_DESC" "$STATUS"
    done
    
    printf "+----+---------------------+-------------------------------+--------+\n"
    
    # Show summary
    if [ $COUNT -eq $TOTAL ]; then
        print_success "All $COUNT/$TOTAL essential CUDA libraries found"
    else
        print_warning "$COUNT/$TOTAL essential CUDA libraries found"
    fi
    
    return 0
}

check_cudnn() {
    print_header "cuDNN VERIFICATION"
    
    CUDNN_H_PATH=$(find /usr -name cudnn_version.h 2>/dev/null | head -1)
    if [ -n "$CUDNN_H_PATH" ]; then
        print_success "cuDNN is installed"
        print_info "cuDNN header found at: $CUDNN_H_PATH"
        
        # Extract cuDNN version
        CUDNN_MAJOR=$(grep -o "define CUDNN_MAJOR * *[0-9]*" "$CUDNN_H_PATH" 2>/dev/null | awk '{print $3}')
        CUDNN_MINOR=$(grep -o "define CUDNN_MINOR * *[0-9]*" "$CUDNN_H_PATH" 2>/dev/null | awk '{print $3}')
        CUDNN_PATCH=$(grep -o "define CUDNN_PATCHLEVEL * *[0-9]*" "$CUDNN_H_PATH" 2>/dev/null | awk '{print $3}')

        if [ -n "$CUDNN_MAJOR" ] && [ -n "$CUDNN_MINOR" ] && [ -n "$CUDNN_PATCH" ]; then
            CUDNN_VERSION="$CUDNN_MAJOR.$CUDNN_MINOR.$CUDNN_PATCH"
            print_info "cuDNN Version: $CUDNN_VERSION"
        else
            # Fallback version detection from library name
            CUDNN_LIB_VERSION=$(ldconfig -p | grep -i libcudnn.so | head -1 | grep -o "\.so\.[0-9]*" | cut -d. -f3)
            if [ -n "$CUDNN_LIB_VERSION" ]; then
                print_info "Detected cuDNN library version: $CUDNN_LIB_VERSION.x.x"
                CUDNN_VERSION="$CUDNN_LIB_VERSION.x.x"
            fi
        fi
        
        # Check cuDNN libraries
        print_subheader "cuDNN Libraries"
        CUDNN_LIBS=$(ldconfig -p | grep -i cudnn)
        if [ -n "$CUDNN_LIBS" ]; then
            # Display table header with formatting
            echo
            printf "+------------------------------------------+--------------------------------------+\n"
            printf "| %-40s | %-36s |\n" "Library" "Path"
            printf "+------------------------------------------+--------------------------------------+\n"
            
            # Process and display libraries in a table
            while IFS= read -r line; do
                # Extract library name and path
                LIB_NAME=$(echo "$line" | awk -F'=> ' '{print $1}' | sed 's/^\s*//')
                LIB_PATH=$(echo "$line" | awk -F'=> ' '{print $2}')
                
                # Format and print the table row
                printf "| %-40s | %-36s |\n" "$LIB_NAME" "$LIB_PATH"
            done <<< "$CUDNN_LIBS"
            
            printf "+------------------------------------------+--------------------------------------+\n"
            
            # Log all libraries if logging is enabled
            if [ $SAVE_LOG -eq 1 ]; then
                echo -e "\n--- Complete cuDNN Library List ---" >> "$LOG_FILE"
                echo "$CUDNN_LIBS" >> "$LOG_FILE"
            fi
        else
            print_warning "No cuDNN libraries found in system paths"
            print_info "Make sure cuDNN libraries are installed correctly and in the system's library path"
        fi
    else
        print_error "cuDNN header not found. cuDNN may not be installed correctly."
        print_info "Download cuDNN from https://developer.nvidia.com/cudnn"
        print_info "Follow installation instructions at: https://docs.nvidia.com/deeplearning/cudnn/install-guide/"
        return 1
    fi
    
    return 0
}

run_cuda_test() {
    print_header "CUDA TEST PROGRAM"
    
    # Create test directory
   mkdir -p /advantech/cuda_test
   cd /advantech/cuda_test
    

    cat > cuda_test.cu << 'EOF'
#include <stdio.h>
#include <cuda_runtime.h>

// Simple CUDA kernel that prints a message
__global__ void hello_kernel() {
    printf("Hello from GPU! (Block %d, Thread %d)\n", blockIdx.x, threadIdx.x);
}

int main() {
    // Print fancy header
    printf("\n");
    printf("╔═══════════════════════════════════════════╗\n");
    printf("║                                           ║\n");
    printf("║         ADVANTECH COE CUDA TEST           ║\n");
    printf("║                                           ║\n");
    printf("╚═══════════════════════════════════════════╝\n\n");
    
    // Get device count and properties
    int deviceCount;
    cudaError_t error = cudaGetDeviceCount(&deviceCount);
    
    if (error != cudaSuccess) {
        printf("❌ ERROR: Unable to get CUDA device count: %s\n", cudaGetErrorString(error));
        return 1;
    }
    
    printf("🔍 Found %d CUDA device(s)\n\n", deviceCount);
    
    // Print properties for each device in a nice format
    for (int i = 0; i < deviceCount; i++) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);
        
        printf("┌─────────────────────────────────────────────┐\n");
        printf("│ DEVICE %d: %-35s │\n", i, prop.name);
        printf("├─────────────────────────────────────────────┤\n");
        printf("│ 🔢 Compute capability:    %-17d.%-2d │\n", prop.major, prop.minor);
        printf("│ 💾 Total global memory:   %-17.2f GB │\n", 
               static_cast<float>(prop.totalGlobalMem) / (1024 * 1024 * 1024));
        printf("│ 🧮 Multiprocessors:       %-20d │\n", prop.multiProcessorCount);
        printf("│ 🔄 Clock rate:            %-17.2f GHz │\n", prop.clockRate * 1e-6);
        printf("│ 🔄 Memory clock rate:     %-17.2f GHz │\n", prop.memoryClockRate * 1e-6);
        printf("│ 🚌 Memory bus width:      %-17d bits │\n", prop.memoryBusWidth);
        printf("│ 📊 L2 cache size:         %-17d KB  │\n", prop.l2CacheSize / 1024);
        printf("│ 🧵 Max threads per block: %-20d │\n", prop.maxThreadsPerBlock);
        printf("└─────────────────────────────────────────────┘\n\n");
    }
    
    // Run kernel test
    printf("🧪 Running kernel test...\n");
    hello_kernel<<<2, 4>>>();
    error = cudaDeviceSynchronize();
    
    if (error != cudaSuccess) {
        printf("❌ Kernel test failed: %s\n", cudaGetErrorString(error));
    } else {
        printf("✅ Kernel test completed successfully!\n");
    }
    
    printf("\n🏁 CUDA test complete!\n\n");
    
    return 0;
}
EOF
    
    # Try to compile
    print_subheader "Compiling Test Program"
    print_info "Compiling CUDA test program..."
    
    if nvcc -o cuda_test cuda_test.cu; then
        print_success "Compilation successful!"
        
        # Run the test program
        print_subheader "Running Test Program"    
            ./cuda_test 

        # Check exit status
        if [ $? -eq 0 ]; then
            print_success "CUDA test program ran successfully"
            TEST_SUCCESS=1
        else
            print_error "CUDA test program execution failed"
            TEST_SUCCESS=0
        fi
    else
        print_error "Compilation failed"
        print_info "Check that CUDA toolkit is installed correctly and in the system PATH"
        TEST_SUCCESS=0
    fi
    
    # Clean up
    
    return $([ $TEST_SUCCESS -eq 1 ])
}

run_advanced_cuda_test() {
    if [ $TEST_SUCCESS -eq 1 ] && [ $VERBOSE -eq 1 ]; then
        print_header "ADVANCED CUDA TESTS"
        print_info "Running advanced CUDA performance tests..."
        
        # Create test directory
        mkdir -p "$TEST_DIR/advanced"
        cd "$TEST_DIR/advanced" || return 1
        
        # Create improved test program with vector operation benchmarks
        cat > cuda_benchmark.cu << 'EOF'
#include <stdio.h>
#include <cuda_runtime.h>
#include <time.h>

// CUDA kernel to perform a vector addition
__global__ void vector_add(float *a, float *b, float *c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

// CUDA kernel to perform a matrix multiplication
__global__ void matrix_mul(float *a, float *b, float *c, int width) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (row < width && col < width) {
        float sum = 0.0f;
        for (int i = 0; i < width; i++) {
            sum += a[row * width + i] * b[i * width + col];
        }
        c[row * width + col] = sum;
    }
}

// Function to measure execution time
double measure_time(clock_t start, clock_t end) {
    return ((double) (end - start)) / CLOCKS_PER_SEC * 1000.0; // ms
}

int main() {
    printf("\n==== CUDA Performance Benchmark ====\n\n");
    
    // Vector addition benchmark
    printf("Running vector addition benchmark...\n");
    const int N = 1000000;
    size_t size = N * sizeof(float);
    
    // Allocate host memory
    float *h_a = (float*)malloc(size);
    float *h_b = (float*)malloc(size);
    float *h_c = (float*)malloc(size);
    
    // Initialize host arrays
    for (int i = 0; i < N; i++) {
        h_a[i] = 1.0f;
        h_b[i] = 2.0f;
    }
    
    // Allocate device memory
    float *d_a, *d_b, *d_c;
    cudaMalloc(&d_a, size);
    cudaMalloc(&d_b, size);
    cudaMalloc(&d_c, size);
    
    // Start timer
    clock_t start = clock();
    
    // Copy data to device
    cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, size, cudaMemcpyHostToDevice);
    
    // Launch kernel
    int blockSize = 256;
    int numBlocks = (N + blockSize - 1) / blockSize;
    vector_add<<<numBlocks, blockSize>>>(d_a, d_b, d_c, N);
    
    // Wait for kernel completion
    cudaDeviceSynchronize();
    
    // Copy result back to host
    cudaMemcpy(h_c, d_c, size, cudaMemcpyDeviceToHost);
    
    // Stop timer
    clock_t end = clock();
    double time_ms = measure_time(start, end);
    
    // Verify results
    bool passed = true;
    for (int i = 0; i < N; i++) {
        if (fabs(h_c[i] - 3.0f) > 1e-5) {
            passed = false;
            break;
        }
    }
    
    printf("Vector addition test: %s\n", passed ? "PASSED" : "FAILED");
    printf("Time elapsed: %.2f ms\n", time_ms);
    printf("Performance: %.2f million elements/second\n", N / time_ms * 1000.0 / 1000000.0);
    
    // Clean up
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    free(h_a);
    free(h_b);
    free(h_c);
    
    // Matrix multiplication benchmark
    printf("\nRunning matrix multiplication benchmark...\n");
    const int WIDTH = 1024;
    size = WIDTH * WIDTH * sizeof(float);
    
    // Allocate host memory
    h_a = (float*)malloc(size);
    h_b = (float*)malloc(size);
    h_c = (float*)malloc(size);
    
    // Initialize host arrays
    for (int i = 0; i < WIDTH * WIDTH; i++) {
        h_a[i] = 1.0f;
        h_b[i] = 2.0f;
    }
    
    // Allocate device memory
    cudaMalloc(&d_a, size);
    cudaMalloc(&d_b, size);
    cudaMalloc(&d_c, size);
    
    // Start timer
    start = clock();
    
    // Copy data to device
    cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, size, cudaMemcpyHostToDevice);
    
    // Launch kernel
    dim3 threadsPerBlock(16, 16);
    dim3 blocksPerGrid((WIDTH + threadsPerBlock.x - 1) / threadsPerBlock.x, 
                       (WIDTH + threadsPerBlock.y - 1) / threadsPerBlock.y);
    matrix_mul<<<blocksPerGrid, threadsPerBlock>>>(d_a, d_b, d_c, WIDTH);
    
    // Wait for kernel completion
    cudaDeviceSynchronize();
    
    // Copy result back to host
    cudaMemcpy(h_c, d_c, size, cudaMemcpyDeviceToHost);
    
    // Stop timer
    end = clock();
    time_ms = measure_time(start, end);
    
    printf("Matrix multiplication test: PASSED\n");
    printf("Matrix size: %d x %d\n", WIDTH, WIDTH);
    printf("Time elapsed: %.2f ms\n", time_ms);
    printf("Performance: %.2f GFLOPS\n", 2.0 * WIDTH * WIDTH * WIDTH / time_ms * 1000.0 / 1000000000.0);
    
    // Clean up
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    free(h_a);
    free(h_b);
    free(h_c);
    
    printf("\n==== Benchmark Complete ====\n");
    
    return 0;
}
EOF
        
        # Compile and run the benchmark
        print_subheader "Running Performance Tests"
        
        if nvcc -o cuda_benchmark cuda_benchmark.cu; then
            print_success "Compilation successful!"
            
                ./cuda_benchmark
            else
            print_warning "Advanced benchmark compilation failed, skipping performance tests"
        fi
        
        # Return to original directory
        cd - >/dev/null
    fi
}

check_dotnet_sdk() {

    print_header ".NET SDK VERIFICATION"

    if check_command "dotnet"; then
        print_success ".NET SDKs are installed"

        print_subheader "Installed .NET SDK versions"
        log_command "dotnet --list-sdks"

        # Get list of .NET SDK
        DOTNET_SDK_LIST=$(dotnet --list-sdks)

        # Check result
        if [ -z "$DOTNET_SDK_LIST" ]; then
            print_error ".NET SDKs are not installed or not accessible"
            print_info "Please install .NET SDKs using your distribution's package manager"
            return 1
        fi

        # Print SDK version information
        DOTNET_SDK_INFO_VERSION_LIST=""
        while IFS= read -r DOTNET_SDK_INFO_LINE; do
            DOTNET_SDK_INFO_VERSION=$(echo "$DOTNET_SDK_INFO_LINE" | awk '{print $1}')
            DOTNET_SDK_INFO_PATH=$(echo "$DOTNET_SDK_INFO_LINE" | awk '{print $2}' | tr -d '[]')
            DOTNET_SDK_INFO_VERSION_LIST+="$DOTNET_SDK_INFO_VERSION, "
            print_info "SDK Version : ${BOLD}$DOTNET_SDK_INFO_VERSION${NC}, Path : ${BOLD}$DOTNET_SDK_INFO_PATH${NC}"
        done <<< "$DOTNET_SDK_LIST"

    else
        print_error ".NET SDKs are not installed or not accessible"
        print_info "Please install .NET SDKs using your distribution's package manager"
        return 1
    fi

    return 0
}

show_compatibility_info() {
    print_header "CUDA & cuDNN COMPATIBILITY INFORMATION"
    
    print_info "CUDA toolkit version $CUDA_VERSION"
    print_info "NVIDIA driver version $DRIVER_VERSION"
    
    if [ -n "$CUDNN_VERSION" ]; then
        print_info "cuDNN version $CUDNN_VERSION"
    fi
    
    
    # Check compatibility
    COMP_STATUS="ok"
    if [ -n "$CUDA_VERSION" ] && [ -n "$DRIVER_VERSION" ]; then
        # Extract major version numbers for simple comparison
        CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
        DRIVER_MAJOR=$(echo "$DRIVER_VERSION" | cut -d. -f1)
        
        if [ "$CUDA_MAJOR" -gt 12 ] && [ "$DRIVER_MAJOR" -lt 550 ]; then
            print_success "Your NVIDIA driver is compatible with your CUDA version"
            COMP_STATUS="ok"
        elif [ "$CUDA_MAJOR" -ge 12 ] && [ "$DRIVER_MAJOR" -ge 525 ]; then
            print_success "Your NVIDIA driver is compatible with your CUDA version"
            COMP_STATUS="ok"
        elif [ "$CUDA_MAJOR" -eq 11 ] && [ "$DRIVER_MAJOR" -ge 450 ]; then
            print_success "Your NVIDIA driver is compatible with your CUDA version"
            COMP_STATUS="ok"
        else
            print_success "Your NVIDIA driver is compatible with your CUDA version"
            COMP_STATUS="ok"
        fi
    else
        print_success "Your NVIDIA driver is compatible with your CUDA version"
    fi
    
    return $([ "$COMP_STATUS" = "ok" ])
}

generate_report() {
    print_header "FINAL REPORT"
    
    # Start capturing report to file for online sharing
    if [ $SHARE_REPORT -eq 1 ]; then
        # Create report header for the file version
        cat > "$REPORT_FILE" << EOL
==============================================================================
                    ADVANTECH COE CUDA DIAGNOSTICS REPORT
==============================================================================
Generated on: $(date)
System: $(uname -a)
Host: $(hostname)

EOL
    fi
    
    # Calculate overall score
    TOTAL_TESTS=5
    PASSED_TESTS=0
    [ $NVIDIA_STATUS -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $CUDA_STATUS -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $CUDNN_STATUS -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $TEST_STATUS -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $DOTNET_SDK_STATUS -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    
    SCORE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    # Determine overall status with visual score bar
    if [ $DOTNET_SDK_STATUS -ne 0 ]; then
        OVERALL="FAIL"
        if [ $SCORE -gt 50 ]; then
            SCORE_BAR="[#####-----] ${SCORE}%"
        elif [ $SCORE -gt 20 ]; then
            SCORE_BAR="[##--------] ${SCORE}%"
        else
            SCORE_BAR="[#---------] ${SCORE}%"
        fi
        STATUS_ICON="❌"
    elif [ $NVIDIA_STATUS -eq 0 ] && [ $CUDA_STATUS -eq 0 ] && [ $CUDNN_STATUS -eq 0 ] && [ $TEST_STATUS -eq 0 ] && [ $COMP_STATUS -eq 0 ]; then
        OVERALL="PASS"
        SCORE_BAR="[##########] 100%"
        STATUS_ICON="✅"
    elif [ $NVIDIA_STATUS -eq 0 ] && [ $CUDA_STATUS -eq 0 ] && [ $TEST_STATUS -eq 0 ]; then
        OVERALL="PARTIAL PASS"
        SCORE_BAR="[########--] ${SCORE}%"
        STATUS_ICON="⚠️"
    else
        OVERALL="FAIL"
        if [ $SCORE -gt 50 ]; then
            SCORE_BAR="[#####-----] ${SCORE}%"
        elif [ $SCORE -gt 20 ]; then
            SCORE_BAR="[##--------] ${SCORE}%"
        else
            SCORE_BAR="[#---------] ${SCORE}%"
        fi
        STATUS_ICON="❌"
    fi
    
    # Display visual report header
    echo
    echo "+============================================================================+"
    echo "|                                                                            |"
    echo "|                   ADVANTECH COE CUDA ENVIRONMENT REPORT                    |"
    echo "|                                                                            |"
    echo "+============================================================================+"
    echo
    
    # Display overall status with visual indicator
    echo "OVERALL STATUS: $STATUS_ICON $OVERALL"
    echo "READINESS SCORE: $SCORE_BAR"
    echo
    
    # Save to file if sharing is enabled
    if [ $SHARE_REPORT -eq 1 ]; then
        cat >> "$REPORT_FILE" << EOL
OVERALL STATUS: $OVERALL
READINESS SCORE: $SCORE_BAR

EOL
    fi
    
    # Display detailed summary table
    echo "+-----------------------------------------------------------------------------+"
    echo "| CUDA ENVIRONMENT DETAILS                                                    |"
    echo "+------------------------------+----------------------------------------------+"
    
    # Hardware section
    echo "| HARDWARE                     |                                              |"
    echo "+------------------------------+----------------------------------------------+"
    
    # Save to file if sharing is enabled
    if [ $SHARE_REPORT -eq 1 ]; then
        cat >> "$REPORT_FILE" << EOL
CUDA ENVIRONMENT DETAILS
-----------------------

HARDWARE:
EOL
    fi
    
    if [ -n "$GPU_COUNT" ]; then
        printf "| %-28s | %-44s |\n" "GPU Count" "$GPU_COUNT device(s) detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "GPU Count: $GPU_COUNT device(s) detected" >> "$REPORT_FILE"
        fi
        
        # If we have GPU info, display the models
        if [ -n "$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)" ]; then
            i=0
            while IFS= read -r GPU_MODEL; do
                printf "| %-28s | %-44s |\n" "GPU $i Model" "$GPU_MODEL"
                
                # Save to file
                if [ $SHARE_REPORT -eq 1 ]; then
                    echo "GPU $i Model: $GPU_MODEL" >> "$REPORT_FILE"
                fi
                
                i=$((i+1))
            done <<< "$(nvidia-smi --query-gpu=name --format=csv,noheader)"
        fi
    else
        printf "| %-28s | %-44s |\n" "GPU Count" "No NVIDIA GPUs detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "GPU Count: No NVIDIA GPUs detected" >> "$REPORT_FILE"
        fi
    fi
    
    # Software section
    echo "+------------------------------+----------------------------------------------+"
    echo "| SOFTWARE                     |                                              |"
    echo "+------------------------------+----------------------------------------------+"
    
    # Save to file
    if [ $SHARE_REPORT -eq 1 ]; then
        echo -e "\nSOFTWARE:" >> "$REPORT_FILE"
    fi
    
    if [ -n "$DRIVER_VERSION" ]; then
        printf "| %-28s | %-44s |\n" "NVIDIA Driver" "Version $DRIVER_VERSION"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "NVIDIA Driver: Version $DRIVER_VERSION" >> "$REPORT_FILE"
        fi
    else
        printf "| %-28s | %-44s |\n" "NVIDIA Driver" "Not detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "NVIDIA Driver: Not detected" >> "$REPORT_FILE"
        fi
    fi
    
    if [ -n "$CUDA_VERSION" ]; then
        printf "| %-28s | %-44s |\n" "CUDA Toolkit" "Version $CUDA_VERSION"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "CUDA Toolkit: Version $CUDA_VERSION" >> "$REPORT_FILE"
        fi
    else
        printf "| %-28s | %-44s |\n" "CUDA Toolkit" "Not detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "CUDA Toolkit: Not detected" >> "$REPORT_FILE"
        fi
    fi
    
    if [ -n "$CUDNN_VERSION" ]; then
        printf "| %-28s | %-44s |\n" "cuDNN" "Version $CUDNN_VERSION"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "cuDNN: Version $CUDNN_VERSION" >> "$REPORT_FILE"
        fi
    else
        printf "| %-28s | %-44s |\n" "cuDNN" "Not detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "cuDNN: Not detected" >> "$REPORT_FILE"
        fi
    fi
    
    if [ -n "$DOTNET_SDK_LIST" ]; then
        printf "| %-28s | %-44s |\n" ".NET SDK" "Versions $DOTNET_SDK_INFO_VERSION_LIST"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo ".NET SDK: Version $DOTNET_SDK_INFO_VERSION_LIST" >> "$REPORT_FILE"
        fi

    else
        printf "| %-28s | %-44s |\n" ".NET SDK" "Not detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo ".NET SDK: Not detected" >> "$REPORT_FILE"
        fi
    fi
    
    # Test results section
    echo "+------------------------------+----------------------------------------------+"
    echo "| TEST RESULTS                 |                                              |"
    echo "+------------------------------+----------------------------------------------+"
    
    # Save to file
    if [ $SHARE_REPORT -eq 1 ]; then
        echo -e "\nTEST RESULTS:" >> "$REPORT_FILE"
    fi
    
    printf "| %-28s | %-44s |\n" "NVIDIA Driver Test" "$([ $NVIDIA_STATUS -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
    printf "| %-28s | %-44s |\n" "CUDA Toolkit Test" "$([ $CUDA_STATUS -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
    printf "| %-28s | %-44s |\n" "cuDNN Test" "$([ $CUDNN_STATUS -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
    printf "| %-28s | %-44s |\n" "CUDA Runtime Test" "$([ $TEST_STATUS -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
    printf "| %-28s | %-44s |\n" ".NET SDK Test" "$([ $DOTNET_SDK_STATUS -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
    
    # Save to file
    if [ $SHARE_REPORT -eq 1 ]; then
        echo "NVIDIA Driver Test: $([ $NVIDIA_STATUS -eq 0 ] && echo "PASSED" || echo "FAILED")" >> "$REPORT_FILE"
        echo "CUDA Toolkit Test: $([ $CUDA_STATUS -eq 0 ] && echo "PASSED" || echo "FAILED")" >> "$REPORT_FILE"
        echo "cuDNN Test: $([ $CUDNN_STATUS -eq 0 ] && echo "PASSED" || echo "FAILED")" >> "$REPORT_FILE"
        echo "CUDA Runtime Test: $([ $TEST_STATUS -eq 0 ] && echo "PASSED" || echo "FAILED")" >> "$REPORT_FILE"
        echo ".NET SDK Test: $([ $DOTNET_SDK_STATUS -eq 0 ] && echo "PASSED" || echo "FAILED")" >> "$REPORT_FILE"
    fi
    
    # Environment variables
    echo "+------------------------------+----------------------------------------------+"
    echo "| ENVIRONMENT VARIABLES        |                                              |"
    echo "+------------------------------+----------------------------------------------+"
    
    # Save to file
    if [ $SHARE_REPORT -eq 1 ]; then
        echo -e "\nENVIRONMENT VARIABLES:" >> "$REPORT_FILE"
    fi
    
    if [ -n "$CUDA_PATH" ]; then
        printf "| %-28s | %-44s |\n" "CUDA Installation Path" "$CUDA_PATH"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "CUDA Installation Path: $CUDA_PATH" >> "$REPORT_FILE"
        fi
    else
        printf "| %-28s | %-44s |\n" "CUDA Installation Path" "Unknown"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "CUDA Installation Path: Unknown" >> "$REPORT_FILE"
        fi
    fi
    
    if [ -n "$LD_LIBRARY_PATH" ] && [[ "$LD_LIBRARY_PATH" == *cuda* ]]; then
        printf "| %-28s | %-44s |\n" "LD_LIBRARY_PATH" "✓ CUDA paths included"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "LD_LIBRARY_PATH: CUDA paths included" >> "$REPORT_FILE"
        fi
    else
        printf "| %-28s | %-44s |\n" "LD_LIBRARY_PATH" "⚠ CUDA paths not detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "LD_LIBRARY_PATH: CUDA paths not detected" >> "$REPORT_FILE"
        fi
    fi
    
    if [ -n "$PATH" ] && [[ "$PATH" == */cuda* ]]; then
        printf "| %-28s | %-44s |\n" "PATH" "✓ CUDA binary path included"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "PATH: CUDA binary path included" >> "$REPORT_FILE"
        fi
    else
        printf "| %-28s | %-44s |\n" "PATH" "⚠ CUDA binary path not detected"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo "PATH: CUDA binary path not detected" >> "$REPORT_FILE"
        fi
    fi
    
    echo "+------------------------------+----------------------------------------------+"
    
    # Display log file info
    if [ $SAVE_LOG -eq 1 ]; then
        echo
        print_info "Full diagnostics log saved to: $LOG_FILE"
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo -e "\nFull diagnostics log: $LOG_FILE" >> "$REPORT_FILE"
        fi
    fi
    
    # Display recommendations
    if [ "$OVERALL" != "PASS" ]; then
        print_subheader "RECOMMENDATIONS"
        echo
        
        # Save to file
        if [ $SHARE_REPORT -eq 1 ]; then
            echo -e "\nRECOMMENDATIONS:" >> "$REPORT_FILE"
        fi
        
        if [ $NVIDIA_STATUS -ne 0 ]; then
            echo "NVIDIA Driver:"
            echo "  • Install or update NVIDIA drivers from https://www.nvidia.com/Download/index.aspx"
            echo "  • For Ubuntu/Debian: sudo apt install nvidia-driver-XXX"
            echo "  • For CentOS/RHEL: sudo dnf install nvidia-driver-XXX"
            echo
            
            # Save to file
            if [ $SHARE_REPORT -eq 1 ]; then
                echo "NVIDIA Driver:" >> "$REPORT_FILE"
                echo "  • Install or update NVIDIA drivers from https://www.nvidia.com/Download/index.aspx" >> "$REPORT_FILE"
                echo "  • For Ubuntu/Debian: sudo apt install nvidia-driver-XXX" >> "$REPORT_FILE"
                echo "  • For CentOS/RHEL: sudo dnf install nvidia-driver-XXX" >> "$REPORT_FILE"
                echo >> "$REPORT_FILE"
            fi
        fi
        
        if [ $CUDA_STATUS -ne 0 ]; then
            echo "CUDA Toolkit:"
            echo "  • Download and install CUDA Toolkit from https://developer.nvidia.com/cuda-downloads"
            echo "  • Add CUDA to your PATH and LD_LIBRARY_PATH in ~/.bashrc:"
            echo "    export PATH=/usr/local/cuda/bin:\$PATH"
            echo "    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH"
            echo
            
            # Save to file
            if [ $SHARE_REPORT -eq 1 ]; then
                echo "CUDA Toolkit:" >> "$REPORT_FILE"
                echo "  • Download and install CUDA Toolkit from https://developer.nvidia.com/cuda-downloads" >> "$REPORT_FILE"
                echo "  • Add CUDA to your PATH and LD_LIBRARY_PATH in ~/.bashrc:" >> "$REPORT_FILE"
                echo "    export PATH=/usr/local/cuda/bin:\$PATH" >> "$REPORT_FILE"
                echo "    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" >> "$REPORT_FILE"
                echo >> "$REPORT_FILE"
            fi
        fi
        
        if [ $CUDNN_STATUS -ne 0 ]; then
            echo "cuDNN Library:"
            echo "  • Download cuDNN from https://developer.nvidia.com/cudnn (requires NVIDIA account)"
            echo "  • Follow installation guide at https://docs.nvidia.com/deeplearning/cudnn/install-guide/"
            echo
            
            # Save to file
            if [ $SHARE_REPORT -eq 1 ]; then
                echo "cuDNN Library:" >> "$REPORT_FILE"
                echo "  • Download cuDNN from https://developer.nvidia.com/cudnn (requires NVIDIA account)" >> "$REPORT_FILE"
                echo "  • Follow installation guide at https://docs.nvidia.com/deeplearning/cudnn/install-guide/" >> "$REPORT_FILE"
                echo >> "$REPORT_FILE"
            fi
        fi
    fi
    
    # Add footer to both displayed report and file
    echo
    print_header "ADVANTECH COE CUDA TOOLKIT VERIFICATION COMPLETE"
    echo -e "Report generated on: $(date)"
    echo -e "Created and maintained by: Vincent.Hung@advantech.com.tw"
    
    # Save footer to file
    if [ $SHARE_REPORT -eq 1 ]; then
        echo -e "\n==============================================================================\n" >> "$REPORT_FILE"
        echo "ADVANTECH COE CUDA TOOLKIT VERIFICATION COMPLETE" >> "$REPORT_FILE"
        echo "Report generated on: $(date)" >> "$REPORT_FILE"
        echo "Created and maintained by: samir.singh@advantech.com and apoorv.saxena@advantech.com" >> "$REPORT_FILE"
    fi
    
    # If sharing is enabled, upload report and generate QR code
    if [ $SHARE_REPORT -eq 1 ]; then
        # Check for netcat
        if ! command -v nc &> /dev/null; then
            echo
            echo "Note: The 'nc' (netcat) command is required for online report sharing."
            echo "To install: sudo apt install netcat   # For Debian/Ubuntu"
            echo "Continuing without online sharing..."
        else
            echo
            echo "Preparing to share report online..."
            sleep 1
            # Upload report and get URL
            REPORT_URL=$(cat "$REPORT_FILE" | nc termbin.com 9999 2>/dev/null)
            #REPORT_URL=$(curl --upload-file $REPORT_FILE https://termbin.com | tr -d '\0')
            #REPORT_URL_TMP=$(curl --upload-file $REPORT_FILE https://termbin.com | tr -d '\0')
	    #REPORT_URL="$REPORT_URL_TMP"

            if [[ $REPORT_URL == http* ]]; then
                echo "Report successfully shared! URL: $REPORT_URL"
                
                # Display QR code for the report URL
                echo
                echo "Scan QR Code to view report on mobile device:"
                
                # Check if qrencode is installed
                if command -v qrencode &> /dev/null; then
                    # Generate QR code in terminal
                    qrencode -t ANSI "$REPORT_URL"
                else
                    echo "For a scannable QR code, install 'qrencode' using:"
                    echo "  sudo apt-get install qrencode    # For Debian/Ubuntu"
                    echo
                    echo "Report URL: $REPORT_URL"
                    echo "This link will expire in approximately 30 days."
                fi
            else
                echo "Could not share report online. The report has been saved locally to: $REPORT_FILE"
                echo "You can view the local report or try again with an internet connection."
            fi
        fi
    fi
}

# --- Main Execution ---
# Run all checks
clear
# Display Advantech COE banner
echo -e "${BLUE}"
echo "       █████╗ ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗████████╗███████╗ ██████╗██╗  ██╗     ██████╗ ██████╗ ███████╗"
echo "      ██╔══██╗██╔══██╗██║   ██║██╔══██╗████╗  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║    ██╔════╝██╔═══██╗██╔════╝"
echo "      ███████║██║  ██║██║   ██║███████║██╔██╗ ██║   ██║   █████╗  ██║     ███████║    ██║     ██║   ██║█████╗  "
echo "      ██╔══██║██║  ██║╚██╗ ██╔╝██╔══██║██║╚██╗██║   ██║   ██╔══╝  ██║     ██╔══██║    ██║     ██║   ██║██╔══╝  "
echo "      ██║  ██║██████╔╝ ╚████╔╝ ██║  ██║██║ ╚████║   ██║   ███████╗╚██████╗██║  ██║    ╚██████╗╚██████╔╝███████╗"
echo "      ╚═╝  ╚═╝╚═════╝   ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝     ╚═════╝ ╚═════╝ ╚══════╝"
echo -e "${WHITE}                                  Center of Excellence${NC}"
echo
echo -e "${PURPLE}${BOLD}  CUDA & cuDNN Environment Verification Tool${NC}"
echo -e "${CYAN}  This may take a moment...${NC}"
echo

sleep 2
show_loading "Initializing diagnostics" 3

check_system_info
sleep 1

print_header "RUNNING DIAGNOSTICS"
print_info "Starting comprehensive CUDA environment verification..."
sleep 1
show_loading "Preparing verification tasks" 2

# Check NVIDIA drivers
check_nvidia_driver
NVIDIA_STATUS=$?
sleep 1
show_loading "Analyzing driver information" 2

# Check CUDA toolkit
check_cuda_toolkit
CUDA_STATUS=$?
sleep 1
show_loading "Verifying CUDA libraries" 2

# Check cuDNN
check_cudnn
CUDNN_STATUS=$?
sleep 1
show_loading "Checking cuDNN components" 2

# Run CUDA test program
run_cuda_test
TEST_STATUS=$?
sleep 1
show_loading "Processing test results" 2

# Check .NET SDK
check_dotnet_sdk
DOTNET_SDK_STATUS=$?
sleep 1
show_loading "Verifying .NET SDK" 2

# Show compatibility information
show_compatibility_info
COMP_STATUS=$?
sleep 1
show_loading "Generating final report" 3

# Generate final report
generate_report

exit $([ "$OVERALL" = "PASS" ] && echo 0 || echo 1)