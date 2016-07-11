#!/bin/bash

LOCAL_DNS="$(hostname).$CS_CLUSTER_ID.containership"
LOCAL_IP=$(dig @localhost $LOCAL_DNS +short)

FOLLOWERS_DNS="followers.$CS_CLUSTER_ID.containership"
FOLLOWER_IPS=($(dig @localhost $FOLLOWERS_DNS +short))

PEER_PROBE_SUCCESS="peer probe: success."
PEER_PROBE_FAILURE_NOT_STARTED="peer probe: failed: Probe returned with transport endpoint is not connected"
PEER_PROBE_FAILURE_EXISTING_CLUSTER="peer probe: failed: .* is either already part of another cluster or having volumes configured"

# Wait for glusterd to start
function waitForGlusterd () {
    until pids=$(pidof glusterd); do
        echo "Waiting for the gluster daemon to initialize..."
        sleep 2
    done

    return 0
}

function probePeers () {
    local peers=($@)
    local ret_val=0

    for ip in ${peers[@]}; do
        if ! gluster peer probe $ip; then
            return 1
        fi
    done

    return 0
}

waitForGlusterd

probePeers ${FOLLOWER_IPS[@]}
peer_succeeded=$?

# If all other peers were not succesfully connected to, then wait
if [[ ! $peer_succeeded -eq 0 ]]; then
    until gluster volume status | grep $GLUSTER_VOLUME; do
        # wait until peers have been established by someone inside the cluster
        echo "Waiting to be connected by other peers in the cluster"
        sleep 5
    done
fi

if ! gluster volume status | grep $GLUSTER_VOLUME >/dev/null; then
    # we are the first node to connect to all followers, create all bricks so we do
    # need to reformat up front
    bootstrap_bricks=""

    for ip in ${FOLLOWER_IPS[@]}; do
        bootstrap_bricks="$ip:$GLUSTER_BRICK_PATH/brick1 $bootstrap_bricks"
    done

    gluster volume create $GLUSTER_VOLUME $bootstrap_bricks
    gluster volume start $GLUSTER_VOLUME
else
    # all bricks are added by controlling follower at startup. If a new node comes online,
    # then we need to add brick to the cluster and then rebalance the files
    if ! gluster volume info | grep "$LOCAL_IP:GLUSTER_BRICK_PATH/brick1" > /dev/null; then
        gluster volume add-brick $GLUSTER_VOLUME $LOCAL_IP:$GLUSTER_BRICK_PATH/brick1
    fi
fi

# Mount the glusterfs volume that has been created
echo "=> Mounting GlusterFS volume $LOCAL_IP:/$GLUSTER_VOLUME at $GLUSTER_VOLUME_PATH"
mount -t glusterfs $LOCAL_IP:/$GLUSTER_VOLUME $GLUSTER_VOLUME_PATH

# Continually try to connect new peers every 15 seconds since we already belong to cluster
while true; do
    # Update follower ips
    echo "Probing for new peers..."
    FOLLOWER_IPS=$(dig @localhost $FOLLOWERS_DNS +short)
    probePeers ${FOLLOWER_IPS[@]}
    sleep 15
done
