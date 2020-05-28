FROM docker:19.03-dind

RUN apk update && apk --no-cache add openssh-server \
  libc6-compat \
  conntrack-tools \
  sudo \
  linux-pam \
  openssh-server-pam \
  bash \
  busybox-extras \
  && mkdir /var/run/sshd \
  && echo 'root:screencast' | chpasswd \
  && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && echo 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' >> /etc/pam.d/sshd

RUN adduser -h /home/vagrant -s /bin/bash vagrant -D \
  && echo "vagrant:vagrant" | chpasswd \
  && echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config \
  && sed -i 's/AllowUsers git/AllowUsers git vagrant/g' /etc/ssh/sshd_config \
  && /usr/bin/ssh-keygen -A

ADD https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub \
    /home/vagrant/.ssh/authorized_keys
ADD entrypoint.sh /entrypoint.sh
ADD sysctl.conf /etc/

RUN chown -R vagrant:vagrant /home/vagrant/.ssh \
  && chmod 0600 /home/vagrant/.ssh/authorized_keys \
  && chmod 0700 /home/vagrant/.ssh \
  && chmod 0755 /entrypoint.sh \
  && echo nf_conntrack >> /etc/modules

ADD 01_vagrant /etc/sudoers.d/

EXPOSE 22 443
ENTRYPOINT /entrypoint.sh
