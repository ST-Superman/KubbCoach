#!/bin/bash
# Test Diagnostics Script for InkastingStatisticsViewModelTests

echo "======================================"
echo "TEST DIAGNOSTICS"
echo "======================================"
echo ""

echo "1. Checking if test file exists..."
if [ -f "Kubb Coach/Kubb CoachTests/InkastingStatisticsViewModelTests.swift" ]; then
    echo "✅ Test file exists"
else
    echo "❌ Test file NOT found"
fi
echo ""

echo "2. Checking test target configuration..."
cd "Kubb Coach"
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" -showBuildSettings | grep -E "(TEST_HOST|PRODUCT_BUNDLE_IDENTIFIER)" | head -10
echo ""

echo "3. Running tests on simulator..."
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:Kubb_CoachTests 2>&1 | \
  grep -E "(Test Case.*InkastingStatistics|Testing failed|Testing passed|Test Suite|error:|failures)"
echo ""

echo "======================================"
echo "DIAGNOSTICS COMPLETE"
echo "======================================"
