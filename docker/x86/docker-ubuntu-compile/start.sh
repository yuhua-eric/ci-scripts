#!/bin/bash
# ADD new user
# explicitly set user/group IDs
USER_NAME=${USER_NAME:-ts}
GROUP_NAME=${GROUP_NAME:-ts}
GROUP_GID=${GROUP_GID:-1000}
USER_UID=${USER_UID:-1000}
USER_PWD=${USER_PWD:-123456}

groupadd -r ${USER_NAME} --gid=${GROUP_GID} && useradd -r -g ${GROUP_NAME} --uid=${USER_UID} -m -s /bin/bash -d /home/ts ${USER_NAME}
chown -R ${USER_NAME}:${GROUP_NAME} /home/ts
echo "${USER_NAME}:${USER_PWD}" | chpasswd
cp /tmp/jenkins-cli.jar /home/ts/
cp /tmp/.msmtprc /home/ts/
cp /tmp/.muttrc /home/ts/
cp /tmp/.bashrc /home/ts/

/usr/sbin/sshd -D
