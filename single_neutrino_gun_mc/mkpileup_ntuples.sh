#!/bin/bash
#
# Generates and ntuplizes zero-bias events (electron neutrino gun sample) for
# different pileups and 25ns or 50ns bunch spacing.
#
# Tested with CMSSW_7_3_1_patch2.
#
# One-time initialization of the HcalTupleMaker package:
#   cd $CMSSW_BASE/src
#   mkdir HCALPFG
#   cd HCALPFG
#   git clone https://github.com/HCALPFG/HcalTupleMaker
#   scram b
#   # copy and modify analysis_HF_MC_fromRAW_cfg.py

# stop on first error
set -e

# main configuration parameters
pileups="100 90 80 70 60 50 45 40 35 30 25 21 17 13 11 9 7 5 4 3 2 1 0" # reverse order balances parallel execution
nevents=500    # number of events to generate per pileup value
bunchspace=50  # 25ns or 50ns

mkdir -p output
cd output

# generate/simulate/reconstruct events
for pu in $pileups; do
    # do not execute more than 8 jobs in parallel
    while [ "`jobs -p | wc -l`" -ge "8" ]; do
        sleep 1
    done

    fname="gen_sim_raw_${bunchspace}ns_pu`printf %03d ${pu}`"

    # customize simulation setup
    cat ../gen_sim_raw_zerobias.py | \
        sed s/NEVENTS/${nevents}/g | \
        sed s/PILEUPVAL/${pu}/g    | \
        sed s/BUNCHSPACE/${bunchspace}/g | \
        sed s/OUTPUTFILE/file:${fname}.root/g  >${fname}.py

    cmsRun ${fname}.py >${fname}.log 2>&1 &
done

wait

# make ntuples
for pu in $pileups; do
    # do not execute more than 8 jobs in parallel
    while [ "`jobs -p | wc -l`" -ge "8" ]; do
        sleep 1
    done

    sfx="${bunchspace}ns_pu`printf %03d ${pu}`"

    cat ../analysis_HF_MC_fromRAW_cfg.py | \
        sed s/BUNCHSPACE/${bunchspace}/g | \
        sed s/MYINPUT/file:gen_sim_raw_${sfx}.root/g | \
        sed s/MYOUTPUT/file:ntuple_${sfx}.root/g >ntuple_${sfx}.py

    cmsRun ntuple_${sfx}.py >ntuple_${sfx}.log 2>&1 &
done

wait

echo "Finished."
