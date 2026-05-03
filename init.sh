cat <<EOF | oc apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: camoufox-vm
  namespace: dev0p1-dev
spec:
  runStrategy: Always
  template:
    spec:
      domain:
        cpu:
          cores: 2
        devices:
          disks:
            - disk:
                bus: virtio
              name: rootdisk
            - disk:
                bus: virtio
              name: data-pvc
            - disk:
                bus: virtio
              name: cloudinitdisk
        memory:
          guest: 4Gi
      volumes:
        - containerDisk:
            image: 'quay.io/containerdisks/ubuntu:22.04'
          name: rootdisk
        - name: data-pvc
          persistentVolumeClaim:
            claimName: camoufox-pvc 
        - name: cloudinitdisk
          cloudInitNoCloud:
            userData: |
              #cloud-config
              user: ubuntu
              password: 'ubuntu123'
              chpasswd: { expire: False }
              ssh_pwauth: true
              fs_setup:
                - device: /dev/vdb
                  filesystem: 'ext4'
                  label: data_pvc
              mounts:
                - [ /dev/vdb, /mnt/pvc, "ext4", "defaults", "0", "2" ]
              runcmd:
                - export PATH=\$PATH:/usr/sbin:/usr/bin:/sbin:/bin
                - mkdir -p /dev/net
                - "[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200"
                - chmod 666 /dev/net/tun
                - mkdir -p /mnt/pvc/docker /mnt/pvc/containerd /mnt/pvc/apt_cache
                - systemctl stop docker containerd || true
                - "[ -L /var/lib/docker ] || (rm -rf /var/lib/docker && ln -s /mnt/pvc/docker /var/lib/docker)"
                - "[ -L /var/lib/containerd ] || (rm -rf /var/lib/containerd && ln -s /mnt/pvc/containerd /var/lib/containerd)"
                - "[ -L /var/cache/apt ] || (rm -rf /var/cache/apt && ln -s /mnt/pvc/apt_cache /var/cache/apt)"
                - |
                  echo '{
                    "data-root": "/mnt/pvc/docker",
                    "exec-opts": ["native.cgroupdriver=cgroupfs"]
                  }' > /etc/docker/daemon.json
                - ip link set dev enp1s0 mtu 1350
                - apt-get update
                - apt-get install -y docker.io curl openvpn git
                - systemctl daemon-reload
                - systemctl enable --now docker
                - cd /mnt/pvc
                - "[ -d dock_hop ] || git clone https://github.com/hasnaouiyacine59-wq/dock_hop.git"
                - cd dock_hop
                - |
                  if [[ \"\$(docker images -q dock_hop 2> /dev/null)\" == \"\" ]]; then
                    docker build -t dock_hop .
                  fi
                - docker rm -f nordvpn-1 || true
                - |
                  docker run -d \\
                    --name nordvpn-1 \\
                    --cap-add=NET_ADMIN \\
                    --cap-add=NET_RAW \\
                    --cap-add=SYS_ADMIN \\
                    --security-opt seccomp=unconfined \\
                    --device /dev/net/tun \\
                    -e NORDVPN_TOKEN="your_token" \\
                    -p 6081:6080 \\
                    dock_hop
EOF
