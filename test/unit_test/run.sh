#!/usr/bin/env bash

# -e: exit if one command fails
# -u: treat unset variable as an error
# -f: disable filename expansion upon seeing *, ?, ...
# -o pipefail: causes a pipeline to fail if any command fails
# set -euf -o pipefail

echo "Start Chacha20 test flow"

svutRun -test ./chacha_quarter_round_testbench.sv -f files.f -I ../../rtl | tee chacha.log
ret=$?

if [[ $ret != 0 ]]; then
    echo "Execution of quarter round testsuite failed"
    exit 1
fi

svutRun -test ./chacha_block_function_testbench.sv -f files.f -I ../../rtl | tee -a chacha.log
ret=$?

if [[ $ret != 0 ]]; then
    echo "Execution of block function testsuite failed"
    exit 1
fi
ec=$(grep -c "ERROR:" chacha.log)

if [[ $ec != 0 ]]; then
    echo "Execution suffered $ec issues"
    exit 1
else
    echo "Execution of core testsuite successfully finished"
fi

echo "Chacha20 test flow successfully terminated ^^"
