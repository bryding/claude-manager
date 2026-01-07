#!/bin/bash
# Fast test runner - runs in under 20 seconds by skipping slow test suites
# Use --full to run all tests (takes 60+ seconds)

cd /Users/benryding/projects/claude-manager

run_tests() {
    local output
    output=$(xcodebuild test-without-building \
        -project ClaudeManager.xcodeproj \
        -scheme ClaudeManager \
        -destination 'platform=macOS,arch=arm64' \
        -only-testing:ClaudeManagerTests \
        "$@" \
        -parallel-testing-enabled YES \
        -enableCodeCoverage NO 2>&1)

    local exit_code=$?
    # Count only actual test results (format: "Test case 'X' passed/failed")
    local passed=$(echo "$output" | grep -c "' passed")
    local failed=$(echo "$output" | grep -c "' failed")

    if [ "$failed" -gt 0 ]; then
        echo "$output" | grep "' failed"
        echo ""
    fi

    echo "✓ $passed passed, ✗ $failed failed"

    if [ "$failed" -gt 0 ]; then
        exit 1
    fi
}

if [ "$1" = "--full" ]; then
    echo "Running ALL tests..."
    run_tests
else
    echo "Running fast tests (skipping ExecutionStateMachineTests, WorktreeServiceTests)..."
    run_tests \
        -skip-testing:ClaudeManagerTests/ExecutionStateMachineTests \
        -skip-testing:ClaudeManagerTests/WorktreeServiceTests
fi
