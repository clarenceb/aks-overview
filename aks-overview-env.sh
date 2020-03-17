#!/bin/bash

# Create a random seed for naming purposes

if [[ ! -f "./aks-random-seed.txt" ]]; then
    echo "Creating random seed..."
    echo "$(( ( RANDOM % 65535 ) + 32768 ))" > ./aks-random-seed.txt
fi

SEED="$(cat ./aks-random-seed.txt)"

echo "Your random seed is ${SEED}"

export cluster_name="aks-overview-${SEED}"
export location="australiaeast"
