FROM library/ubuntu:14.04

MAINTAINER ContainerShip Developers <developers@containership.io>

ENV GLUSTER_VERSION=3.7
ENV GLUSTER_HOME=/opt/gluster
ENV GLUSTER_VOLUME containership
ENV GLUSTER_BRICK_PATH /mnt/containership/gluster/bricks
ENV GLUSTER_VOLUME_PATH /mnt/containership/gluster/volumes/$GLUSTER_VOLUME

RUN apt-get update && apt-get install -y python-software-properties software-properties-common
RUN add-apt-repository -y ppa:gluster/glusterfs-$GLUSTER_VERSION && apt-get update
RUN apt-get install -y dnsutils glusterfs-server glusterfs-client supervisor

# VOLUME $GLUSTER_BRICK_PATH
# VOLUME $GLUSTER_VOLUME_PATH

WORKDIR $GLUSTER_HOME
ADD supervisord.conf $GLUSTER_HOME
ADD configure_gluster.sh $GLUSTER_HOME

CMD /usr/bin/supervisord -c $GLUSTER_HOME/supervisord.conf
