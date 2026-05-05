#!/usr/bin/env bash
set -e

# Auto-detect Slurm version from .env file
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

SLURM_VERSION=$(grep "^SLURM_VERSION=" .env | cut -d'=' -f2)
VERSION_DIR=$(echo "$SLURM_VERSION" | cut -d. -f1-2)

restart=false

for var in "$@"
do
    case "$var" in
        slurm.conf)
            SOURCE_FILE="config/${VERSION_DIR}/slurm.conf"
            ;;
        topology.conf)
            SOURCE_FILE="config/${VERSION_DIR}/topology.conf"
            ;;
        slurmdbd.conf)
            SOURCE_FILE="config/common/slurmdbd.conf"
            ;;
        cgroup.conf)
            SOURCE_FILE="config/common/cgroup.conf"
            ;;
        *)
            echo "Warning: Unknown config file '$var', skipping"
            continue
            ;;
    esac

    # Check if source file exists
    if [ ! -f "$SOURCE_FILE" ]; then
        echo "Error: Source file '$SOURCE_FILE' not found"
        exit 1
    fi

    echo "Copying $SOURCE_FILE to containers..."
    
    for container in slurmctld slurmdbd slurmrestd c0 c1 c2 c3 c4 c5 c6; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            docker cp "$SOURCE_FILE" "$container:/etc/slurm/$var"
            docker exec -u root "$container" chown slurm:slurm "/etc/slurm/$var"
        else
            echo "Skipping $container (not running)"
        fi
    done
    restart=true
done

if [ "$restart" = true ]; then
    echo "Restarting slurmctld and slurmrestd..."
    docker compose restart slurmctld slurmrestd
fi