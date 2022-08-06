#!/bin/sh
SCHEME="IndexedDataStore"
RESULT_BUNDLE="CodeCoverage.xcresult"
RESULT_JSON="CodeCoverage.json"
MIN_CODE_COVERAGE=50.0 # should really be higher =)
# Pre-clean
if [ -d $RESULT_BUNDLE ]; then
    rm -rf $RESULT_BUNDLE
fi
if [ -f $RESULT_JSON ]; then
    rm $RESULT_JSON
fi
# Build
set -o pipefail && env NSUnbufferedIO=YES xcodebuild build-for-testing -scheme $SCHEME -destination "platform=iOS Simulator,OS=latest,name=iPhone 12" -enableCodeCoverage YES | xcpretty
# Test
set -o pipefail && env NSUnbufferedIO=YES xcodebuild test-without-building -scheme $SCHEME -destination "platform=iOS Simulator,OS=latest,name=iPhone 12" -enableCodeCoverage YES -resultBundlePath $RESULT_BUNDLE | xcpretty

set -o pipefail && env NSUnbufferedIO=YES xcrun xccov view –report –json $RESULT_BUNDLE > $RESULT_JSON
CODE_COVERAGE=$(cat $RESULT_JSON | jq '.targets[] | select( .name == "IndexedDataStore" and .executableLines > 0 ) | .lineCoverage')
CODE_COVERAGE=$(echo $CODE_COVERAGE*100.0 | bc)

COVERAGE_PASSES=$(echo "$CODE_COVERAGE > $MIN_CODE_COVERAGE" | bc)
if [ $COVERAGE_PASSES -ne 1 ]; then
    printf "\033[0;31mCode coverage %.1f%% is less than required %.1f%%\033[0m\n" $CODE_COVERAGE $MIN_CODE_COVERAGE
    exit -1
else
    printf "\033[0;32mCode coverage is %.1f%%\033[0m\n" $CODE_COVERAGE
fi
