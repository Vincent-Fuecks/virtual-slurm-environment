for service in slurmctld slurmrestd c0 c1 c2 c3 c4 c5 c6; do
    echo "Adding user to $service..."
    sudo docker compose exec $service useradd -u 1100 -m -s /bin/bash vrmUser
done