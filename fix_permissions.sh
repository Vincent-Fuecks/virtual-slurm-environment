#!/bin/bash
set -e

echo "--> 1. Checking Slurm Controller status..."
if ! docker compose ps slurmctld | grep -q "healthy"; then
    echo "Error: slurmctld is not healthy. Please wait for it to start."
    exit 1
fi

echo "--> 2. Elevating user 'root' to Administrator..."
# By default, users have AdminLevel=None. /config requires AdminLevel=Administrator or Operator.
docker compose exec slurmctld sacctmgr -i modify user root set AdminLevel=Administrator

echo "--> 3. Verifying AdminLevel..."
docker compose exec slurmctld sacctmgr show user root format=User,AdminLevel

echo "--> 4. Checking file permissions for slurmrestd..."
# slurmrestd runs as user 'slurmrest' (uid 991). 
# It needs to read topology.conf. If permissions are 600 owned by slurm:slurm, it will fail.
# We check if the file is world-readable (644) inside the container.

PERMS=$(docker compose exec slurmrestd stat -c "%a" /etc/slurm/topology.conf 2>/dev/null || echo "Missing")

if [ "$PERMS" = "Missing" ]; then
    echo "WARNING: /etc/slurm/topology.conf not found inside slurmrestd container!"
elif [ "$PERMS" -lt 644 ]; then
    echo "WARNING: /etc/slurm/topology.conf has permissions $PERMS."
    echo "         The 'slurmrest' user might not be able to read it."
    echo "         Fixing ownership/permissions..."
    docker compose exec -u root slurmrestd chmod 644 /etc/slurm/topology.conf || echo "Could not chmod (likely Read-Only volume). Please chmod 644 config/24.11/topology.conf on your host."
else
    echo "Permissions check passed: topology.conf is readable ($PERMS)."
fi

echo "--> 5. Checking if Topology is loaded in Controller..."
docker compose logs slurmctld | grep -i "topology/tree" | tail -n 1

echo "----------------------------------------------------"
echo "Fix complete. Please regenerate your JWT token and try the /config endpoint again."
echo "----------------------------------------------------"