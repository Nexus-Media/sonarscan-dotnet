#!/bin/bash
set -o pipefail
# We'll handle errors manually instead of using set -e
set -u

# Check required parameters has a value
if [ -z "$INPUT_SONARPROJECTKEY" ]; then
    echo "Input parameter sonarProjectKey is required"
    exit 1
fi
if [ -z "$INPUT_SONARPROJECTNAME" ]; then
    echo "Input parameter sonarProjectName is required"
    exit 1
fi
if [ -z "$SONAR_TOKEN" ]; then
    echo "Environment parameter SONAR_TOKEN is required"
    exit 1
fi

# List Environment variables that's set by Github Action input parameters (defined by user)
echo "Github Action input parameters"
echo "INPUT_SONARPROJECTKEY: $INPUT_SONARPROJECTKEY"
echo "INPUT_SONARPROJECTNAME: $INPUT_SONARPROJECTNAME"
echo "INPUT_SONARORGANIZATION: $INPUT_SONARORGANIZATION"
echo "INPUT_DOTNETPREBUILDCMD: $INPUT_DOTNETPREBUILDCMD"
echo "INPUT_DOTNETBUILDARGUMENTS: $INPUT_DOTNETBUILDARGUMENTS"
echo "INPUT_DOTNETTESTARGUMENTS: $INPUT_DOTNETTESTARGUMENTS"
echo "INPUT_DOTNETDISABLETESTS: $INPUT_DOTNETDISABLETESTS"
echo "INPUT_SONARBEGINARGUMENTS: $INPUT_SONARBEGINARGUMENTS"
echo "INPUT_SONARHOSTNAME: $INPUT_SONARHOSTNAME"
echo "testtest"

# Environment variables that need to be mapped in Github Action 
#     env:
#       SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
#       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
#
# SONAR_TOKEN=[your_token_from_sonarqube]
# GITHUB_TOKEN=[your_token_from_github]

# Environment variables automatically set by Github Actions automatically passed on to the docker container
#
# Example pull request
# GITHUB_REPOSITORY=theowner/therepo
# GITHUB_EVENT_NAME=pull_request
# GITHUB_REF=refs/pull/1/merge
# GITHUB_HEAD_REF=somenewcodewithouttests
# GITHUB_BASE_REF=master
#
# Example normal push
# GITHUB_REPOSITORY=theowner/therepo
# GITHUB_EVENT_NAME="push"
# GITHUB_REF=refs/heads/master
# GITHUB_HEAD_REF=""
# GITHUB_BASE_REF=""

# ---------------------------------------------
# DEBUG: How to run container manually
# ---------------------------------------------
# export SONAR_TOKEN="your_token_from_sonarqube"

# Simulate Github Action input variables  
# export INPUT_SONARPROJECTKEY="your_projectkey"
# export INPUT_SONARPROJECTNAME="your_projectname"
# export INPUT_SONARORGANIZATION="your_organization"
# export INPUT_DOTNETBUILDARGUMENTS=""
# export INPUT_DOTNETTESTARGUMENTS=""
# export INPUT_DOTNETDISABLETESTS=""
# export INPUT_SONARBEGINARGUMENTS=""
# export INPUT_SONARHOSTNAME="https://sonarcloud.io"

# Simulate Github Action built-in environment variables
# export GITHUB_REPOSITORY=theowner/therepo
# export GITHUB_EVENT_NAME="push"
# export GITHUB_REF=refs/heads/master
# export GITHUB_HEAD_REF=""
# export GITHUB_BASE_REF=""
#
# Build local Docker image
# docker build -t sonarscan-dotnet .
# Execute Docker container
# docker run --name sonarscan-dotnet --workdir /github/workspace --rm -e INPUT_SONARPROJECTKEY -e INPUT_SONARPROJECTNAME -e INPUT_SONARORGANIZATION -e INPUT_DOTNETBUILDARGUMENTS -e INPUT_DOTNETTESTARGUMENTS -e INPUT_DOTNETDISABLETESTS -e INPUT_SONARBEGINARGUMENTS -e INPUT_SONARHOSTNAME -e SONAR_TOKEN -e GITHUB_EVENT_NAME -e GITHUB_REPOSITORY -e GITHUB_REF -e GITHUB_HEAD_REF -e GITHUB_BASE_REF -v "/var/run/docker.sock":"/var/run/docker.sock" -v $(pwd):"/github/workspace" sonarscan-dotnet

#-----------------------------------
# Build Sonarscanner begin command
#-----------------------------------

sonar_begin_cmd="/dotnet-sonarscanner begin /k:\"${INPUT_SONARPROJECTKEY}\" /n:\"${INPUT_SONARPROJECTNAME}\" /d:sonar.token=\"${SONAR_TOKEN}\" /d:sonar.host.url=\"${INPUT_SONARHOSTNAME}\""
if [ -n "$INPUT_SONARORGANIZATION" ]; then
    sonar_begin_cmd="$sonar_begin_cmd /o:\"${INPUT_SONARORGANIZATION}\""
fi
if [ -n "$INPUT_SONARBEGINARGUMENTS" ]; then
    sonar_begin_cmd="$sonar_begin_cmd $INPUT_SONARBEGINARGUMENTS"
fi
# Check Github environment variable GITHUB_EVENT_NAME to determine if this is a pull request or not. 
if [[ $GITHUB_EVENT_NAME == 'pull_request' ]]; then
    # Sonarqube wants these variables if build is started for a pull request
    # Sonarcloud parameters: https://sonarcloud.io/documentation/analysis/pull-request/
    # sonar.pullrequest.key	                Unique identifier of your PR. Must correspond to the key of the PR in GitHub or TFS. E.G.: 5
    # sonar.pullrequest.branch	            The name of your PR Ex: feature/my-new-feature
    # sonar.pullrequest.base	            The long-lived branch into which the PR will be merged. Default: master E.G.: master
    # sonar.pullrequest.github.repository	SLUG of the GitHub Repo (owner/repo)

    # Extract Pull Request numer from the GITHUB_REF variable
    PR_NUMBER=$(echo $GITHUB_REF | awk 'BEGIN { FS = "/" } ; { print $3 }')

    # Add pull request specific parameters in sonar scanner
    sonar_begin_cmd="$sonar_begin_cmd /d:sonar.pullrequest.key=$PR_NUMBER /d:sonar.pullrequest.branch=$GITHUB_HEAD_REF /d:sonar.pullrequest.base=$GITHUB_BASE_REF /d:sonar.pullrequest.github.repository=$GITHUB_REPOSITORY /d:sonar.pullrequest.provider=github"

fi

#Skip JRE provisioning in SonarScanner for MSBuild v7.0+. Instead use the JRE provided by the Docker image (which must be in the PATH).
# sonar_begin_cmd="$sonar_begin_cmd /d:sonar.scanner.skipJreProvisioning=true"

#-----------------------------------
# Build Sonarscanner end command
#-----------------------------------
sonar_end_cmd="/dotnet-sonarscanner end /d:sonar.token=\"${SONAR_TOKEN}\""

#-----------------------------------
# Build pre build command
#-----------------------------------
dotnet_prebuild_cmd="echo NO_PREBUILD_CMD"
if [ -n "$INPUT_DOTNETPREBUILDCMD" ]; then
    dotnet_prebuild_cmd="$INPUT_DOTNETPREBUILDCMD"
fi

#-----------------------------------
# Build dotnet build command
#-----------------------------------
dotnet_build_cmd="dotnet build"
if [ -n "$INPUT_DOTNETBUILDARGUMENTS" ]; then
    dotnet_build_cmd="$dotnet_build_cmd $INPUT_DOTNETBUILDARGUMENTS"
fi

#-----------------------------------
# Build dotnet test command
#-----------------------------------
dotnet_test_cmd="dotnet test"
if [ -n "$INPUT_DOTNETTESTARGUMENTS" ]; then
    dotnet_test_cmd="$dotnet_test_cmd $INPUT_DOTNETTESTARGUMENTS"
fi

#-----------------------------------
# Execute shell commands
#-----------------------------------
echo "Shell commands"

#Create a temporary file to store the analysis output
analysis_output_file="/tmp/sonar_analysis_output.txt"
touch $analysis_output_file

# Function to run command, capture output, and handle errors
run_command() {
    local cmd_name="$1"
    local cmd="$2"
    
    echo "$cmd_name: $cmd"
    sh -c "$cmd" 2>&1 | tee -a "$analysis_output_file"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -ne 0 ]; then
        # Extract relevant snippets for GitHub Actions output
        extract_error_snippets
        echo "Command '$cmd_name' failed with exit code $exit_code"
        exit $exit_code
    fi
}

# Function to extract error snippets and set as output
extract_error_snippets() {
    # Look for compiler errors and failed tests
    compiler_errors=$(grep -E "error [A-Z]+[0-9]+" "$analysis_output_file" -A 5 | grep -v "warning" || true)
    test_failures=$(grep -E "\[FAIL\]" "$analysis_output_file" -A 12 || true)

    if [ ! -z "$compiler_errors" ] || [ ! -z "$test_failures" ]; then
        # Create a temporary file for the output
        temp_output=$(mktemp)
        
        if [ ! -z "$compiler_errors" ]; then
            echo "Compiler Errors:" >> "$temp_output"
            echo "$compiler_errors" >> "$temp_output"
            echo "" >> "$temp_output"
        fi
        if [ ! -z "$test_failures" ]; then
            echo "Test Failures:" >> "$temp_output"
            echo "$test_failures" >> "$temp_output"
        fi
        
        # Use a delimiter-based approach for GitHub Actions output
        delimiter="EOF_$(date +%s)"
        {
            echo "analysis_snippet<<$delimiter"
            cat "$temp_output"
            echo "$delimiter"
        } >> $GITHUB_OUTPUT
        
        rm -f "$temp_output"
    else
        echo "analysis_snippet=No errors or test failures found" >> $GITHUB_OUTPUT
    fi
}

#Run Sonarscanner .NET Core "begin" command
run_command "sonar_begin_cmd" "$sonar_begin_cmd"

#Run dotnet pre build command
run_command "dotnet_prebuild_cmd" "$dotnet_prebuild_cmd"

#Run dotnet build command
run_command "dotnet_build_cmd" "$dotnet_build_cmd"

#Run dotnet test command (unless user choose not to)
if ! [[ "${INPUT_DOTNETDISABLETESTS,,}" == "true" || "${INPUT_DOTNETDISABLETESTS}" == "1" ]]; then
    run_command "dotnet_test_cmd" "$dotnet_test_cmd"
fi

#Run Sonarscanner .NET Core "end" command
run_command "sonar_end_cmd" "$sonar_end_cmd"

# Final output extract in case all commands succeeded
extract_error_snippets