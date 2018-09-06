# Alpine Linux
#
FROM yfrepo/apline-openjdk8

#
ARG HADOOP_VERSION=2.9.1

# Repository links
ARG REPOSITORY=http://archive.apache.org/dist
ARG HADOOP_DOWNLOAD_LINK=$REPOSITORY/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz

#
ARG HADOOP_DIR=/hadoop

#------------------------
# initial steps
RUN apk update \
    && apk add --no-cache curl openrc openssh rsync bash
	
#-------------------------
# ssh configuration
RUN set -x \
    && rc-update add sshd \
    && rc-status \
	&& touch /run/openrc/softlevel \
	&& ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa \
    && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys \
    && chmod 0600 ~/.ssh/authorized_keys \
    && echo 'StrictHostKeyChecking no' >> /etc/ssh/ssh_config
	
#------------------------
# hadoop steps
ENV HADOOP_HOME $HADOOP_DIR
ENV PATH $PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

RUN set -x \
    && mkdir $HADOOP_DIR \
    && curl "$HADOOP_DOWNLOAD_LINK" | tar -xz -C $HADOOP_DIR --strip-components 1
	
RUN { \
        echo '#!/bin/sh'; \
        echo 'set -e'; \
        echo; \
        echo 'export HADOOP_HOME=/hadoop'; \
		echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin'; \
    } > /etc/profile.d/hadoop.sh \
    && chmod +x /etc/profile.d/hadoop.sh

COPY conf/hadoop-env.sh   $HADOOP_HOME/etc/hadoop/hadoop-env.sh
COPY conf/core-site.xml   $HADOOP_HOME/etc/hadoop/core-site.xml
COPY conf/hdfs-site.xml   $HADOOP_HOME/etc/hadoop/hdfs-site.xml	
COPY conf/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml
COPY conf/yarn-site.xml   $HADOOP_HOME/etc/hadoop/yarn-site.xml
	
#-----------------------
# remove redundant resources
RUN apk del curl && \
    rm -rf /var/cache/apk/*
	
#----------------------
EXPOSE 2181 8020 8088 50070
	
ENTRYPOINT echo "setting hadoop environment" \
           # && sed -i "s/{{JAVA_HOME}}//usr/lib/jvm/default-jvm/g" $HADOOP_HOME/etc/hadoop/hadoop-env.sh \
           && sed -i "s/{{HOST}}/`hostname`/g" $HADOOP_HOME/etc/hadoop/core-site.xml \
           echo "starting services" \
           && /etc/init.d/sshd start \
           && hdfs namenode -format \
           && start-dfs.sh \
           && start-yarn.sh \
           && tail -f /dev/null