#!/usr/bin/with-contenv bash
# shellcheck shell=bash
#####################################
# All rights reserved.              #
# started from Zero                 #
# Docker owned dockserver           #
# Docker Maintainer dockserver      #
#####################################
#####################################
# THIS DOCKER IS UNDER LICENSE      #
# NO CUSTOMIZING IS ALLOWED         #
# NO REBRANDING IS ALLOWED          #
# NO CODE MIRRORING IS ALLOWED      #
#####################################

function preinstall() {
# shellcheck disable=SC2046
      printf "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀 DockServer PRE-Install Runs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
      basefolder="/opt/appdata"
      proxydel
      packageupdate="update upgrade dist-upgrade autoremove autoclean"
      for i in ${packageupdate}; do $(which apt) $i -yqq ; done

      package_basic=(software-properties-common rsync language-pack-en-base pciutils lshw nano rsync fuse curl wget tar pigz pv iptables ipset fail2ban jq unzip)
      apt install ${package_basic[@]} --reinstall -yqq
      fastapp
      folder="/mnt"
      for fo in ${folder}; do
         $(which mkdir) -p $fo/{unionfs,downloads,incomplete,torrent,nzb} \
         $fo/{incomplete,downloads}/{nzb,torrent}/{complete,temp,movies,tv,tv4k,movies4k,movieshdr,tvhdr,remux} \
         $fo/downloads/torrent/{temp,complete}/{movies,tv,tv4k,movies4k,movieshdr,tvhdr,remux} \
         $fo/{torrent,nzb}/watch
         $(which find) $fo -exec $(which chmod) a=rx,u+w {} \;
         $(which find) $fo -exec $(which chown) -hR 1000:1000 {} \;
      done

      appfolder="/opt/appdata"
      for app in ${appfolder}; do
        $(which mkdir) -p $app/{compose,system}
        $(which find) $app -exec $(command -v chmod) a=rx,u+w {} \;
        $(which find) $app -exec $(command -v chown) -hR 1000:1000 {} \;
      done
 
     if test -f /etc/sysctl.d/99-sysctl.conf; then
         config="/etc/sysctl.d/99-sysctl.conf"
         ipv6=$(cat $config | grep -qE 'ipv6' && echo true || false)
           if [ $ipv6 != 'true' ] || [ $ipv6 == 'true' ]; then
              grep -qE 'net.ipv6.conf.all.disable_ipv6 = 1' $config || \
              echo 'net.ipv6.conf.all.disable_ipv6 = 1' >>$config
              grep -qE 'net.ipv6.conf.default.disable_ipv6 = 1' $config || \
              echo 'net.ipv6.conf.default.disable_ipv6 = 1' >>$config
              grep -qE 'net.ipv6.conf.lo.disable_ipv6 = 1' $config || \
              echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >>$config
              grep -qE 'net.core.default_qdisc=fq' $config || \
              echo 'net.core.default_qdisc=fq' >>$config
              grep -qE 'net.ipv4.tcp_congestion_control=bbr' $config || \
              echo 'net.ipv4.tcp_congestion_control=bbr' >>$config
              sysctl -p -q
           fi
      fi
      ## USE OFFICIAL DOCKER INSTALL PART
      if [[ ! $(which docker) ]]; then wget -qO- https://get.docker.com/ | sh >/dev/null 2>&1 ; fi
         daemonjson
         $(which usermod) -aG docker $(whoami)
         $(which systemctl) reload-or-restart docker.service 1>/dev/null 2>&1
         $(which systemctl) enable docker.service >/dev/null 2>&1
         $(which curl) --silent -fsSL https://raw.githubusercontent.com/MatchbookLab/local-persist/master/scripts/install.sh | bash 1>/dev/null 2>&1
         $(which docker) volume create -d local-persist -o mountpoint=/mnt --name=unionfs
         $(which docker) network create --driver=bridge proxy 1>/dev/null 2>&1

      updatecompose && gpupart

      disable=(apt-daily.service apt-daily.timer apt-daily-upgrade.timer apt-daily-upgrade.service)
      $(which systemctl) disable ${disable[@]} >/dev/null 2>&1

      if [[ ! $(which ansible) ]]; then
         if [[ -r /etc/os-release ]]; then lsb_dist="$(. /etc/os-release && echo "$ID")"; fi
         package_list="ansible dialog python3-lxml"
         package_listdebian="apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367"
         package_listubuntu="apt-add-repository --yes --update ppa:ansible/ansible"
         if [[ $lsb_dist == 'ubuntu' ]] || [[ $lsb_dist == 'rasbian' ]]; then ${package_listubuntu} 1>/dev/null 2>&1; else ${package_listdebian} 1>/dev/null 2>&1; fi
         for i in ${package_list}; do
            $(which apt) install $i --reinstall -yqq 1>/dev/null 2>&1
         done
         if [[ $lsb_dist == 'ubuntu' ]]; then add-apt-repository --yes --remove ppa:ansible/ansible; fi
      fi

      if [[ ! -d "/etc/ansible/inventories" ]]; then $(which mkdir) -p $invet ; fi
      cat > /etc/ansible/inventories/local << EOF; $(echo)
## CUSTOM local inventories
[local]
127.0.0.1 ansible_connection=local
EOF
      if test -f /etc/ansible/ansible.cfg; then
        $(which mv) /etc/ansible/ansible.cfg /etc/ansible/ansible.cfg.bak
      fi
cat > /etc/ansible/ansible.cfg << EOF; $(echo)
## CUSTOM Ansible.cfg
[defaults]
deprecation_warnings = False
command_warnings = False
force_color = True
inventory = /etc/ansible/inventories/local
retry_files_enabled = False
EOF

      if [[ "$(systemd-detect-virt)" == "lxc" ]]; then lxc ; fi

      while true; do
         f2ban=$($(command -v systemctl) is-active fail2ban | grep -qE 'active' && echo true || echo false)
         if [[ $f2ban != 'true' ]]; then echo "Waiting for fail2ban to start" && sleep 1 && continue; else break; fi
      done

      ORGFILE="/etc/fail2ban/jail.conf"
      LOCALMOD="/etc/fail2ban/jail.local"
cat > /etc/fail2ban/filter.d/log4j-jndi.conf << EOF; $(echo)
# jay@gooby.org
# https://jay.gooby.org/2021/12/13/a-fail2ban-filter-for-the-log4j-cve-2021-44228
# https://gist.github.com/jaygooby/3502143639e09bb694e9c0f3c6203949
# Thanks to https://gist.github.com/kocour for a better regex
[log4j-jndi]
maxretry = 1
enabled = true
port = 80,443
logpath = /opt/appdata/traefik/traefik.log
EOF

cat > /etc/fail2ban/filter.d/authelia.conf << EOF; $(echo)
[authelia]
enabled = true
port = http,https,9091
filter = authelia
logpath = /opt/appdata/authelia/authelia.log
maxretry = 2
bantime = 90d
findtime = 7d
chain = DOCKER-USER
EOF
grep -qE '#log4j
[Definition]
failregex   = (?i)^<HOST> .* ".*\$.*(7B|\{).*(lower:)?.*j.*n.*d.*i.*:.*".*?$' /etc/fail2ban/jail.local || \
 echo '#log4j
[Definition]
failregex   = (?i)^<HOST> .* ".*\$.*(7B|\{).*(lower:)?.*j.*n.*d.*i.*:.*".*?$' > /etc/fail2ban/jail.local
         sed -i "s#rotate 4#rotate 1#g" /etc/logrotate.conf
         sed -i "s#weekly#daily#g" /etc/logrotate.conf

      f2ban=$($(command -v systemctl) is-active fail2ban | grep -qE 'active' && echo true || echo false)
      if [[ $f2ban != "false" ]]; then
         $(which systemctl) reload-or-restart fail2ban.service 1>/dev/null 2>&1
         $(which systemctl) enable fail2ban.service 1>/dev/null 2>&1
      fi

      ## raiselimits
      sed -i '/hard nofile/ d' /etc/security/limits.conf
      sed -i '/soft nofile/ d' /etc/security/limits.conf
      sed -i '$ i\* hard nofile 32768\n* soft nofile 16384' /etc/security/limits.conf
      printf "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀 DockServer PRE-Install is done
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
clear
}

function daemonjson() {

echo '{
    "storage-driver": "overlay2",
    "userland-proxy": false,
    "dns": ["8.8.8.8", "1.1.1.1"],
    "ipv6": false,
    "log-driver": "json-file",
    "live-restore": true,
    "log-opts": {"max-size": "8m", "max-file": "2"}
}' >/etc/docker/daemon.json

}

function badips() {
   #bad ips mod
   ipset -q flush ips
   ipset -q create ips hash:net
   for ip in $(curl --compressed https://raw.githubusercontent.com/scriptzteam/IP-BlockList-v4/master/ips.txt 2>/dev/null | grep -v "#" | grep -v -E "\s[1-2]$" | cut -f 1); do ipset add ips $ip; done
   $(which iptables) -I INPUT -m set --match-set ips src -j DROP
   update-locale LANG=LANG=LC_ALL=en_US.UTF-8 LANGUAGE 1>/dev/null 2>&1
   localectl set-locale LANG=LC_ALL=en_US.UTF-8 1>/dev/null 2>&1
}

function proxydel() {
   delproxy="apache2 nginx"
   for i in ${delproxy}; do
      $(which systemctl) stop $i 1>/dev/null 2>&1
      $(which systemctl) disable $i 1>/dev/null 2>&1
      $(which apt) remove $i -yqq 1>/dev/null 2>&1
      $(which apt) purge $i -yqq 1>/dev/null 2>&1
      break
   done
}

function lxc() {
    lxcstart
    $(which chmod) a=rx,u+w /home/.lxcstart.sh
    $(which  bash) /home/.lxcstart.sh
    lxcansible
    $(which ansible-playbook) /home/.lxcplaybook.yml 1>/dev/null 2>&1
cat > /etc/cron.d/lxcstart << EOF; $(echo)
SHELL=/bin/bash
@reboot root /bin/bash /home/.lxcstart.sh 1>/dev/null 2>&1
EOF
    $(command -v chmod) a=rx,u+w /etc/cron.d/lxcstart
    lxcending && clear
}

function lxcending() {
  printf "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ❌ INFO
    Please be sure that you have add the following features
    keyctl, nesting and fuse under LXC Options > Features,
    this is only available when Unprivileged container=Yes
    The mount-docker takes round about 2 minutes to start
    after the installation, please be patient
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
  read -erp "Confirm Info | Type confirm & PRESS [ENTER]" input </dev/tty
}

function lxcansible() {
cat > /home/.lxcplaybook.yml << EOF; $(echo)
---
- hosts: localhost
  gather_facts: false
  name: LXC Playbook
  tasks:
    - cron:
        name: LXC Bypass the mount :shared
        special_time: 'reboot'
        user: root
        job: '/bin/bash /home/.lxcstart.sh 1>/dev/null 2>&1'
        state: present
      become_user: root
      ignore_errors: yes
EOF
}

function lxcstart() {
cat > /home/.lxcstart.sh << EOF; $(echo)
#!/bin/bash
#
# Title:      LXC Bypass the mount :shared
# OS Branch:  ubuntu,debian,rasbian
# Author(s):  mrdoob
# Coauthor:   DrAgOn141
# GNU:        General Public License v3.0
################################################################################
## make / possible to add /mnt:shared
mount --make-shared /
EOF
}

function gpupart() {
GVID=$(id $(whoami) | grep -qE 'video' && echo true || echo false)
GCHK=$(grep -qE video /etc/group && echo true || echo false)
DEVT=$(ls /dev/dri 1>/dev/null 2>&1 && echo true || echo false)
IGPU=$(ls /etc/modprobe.d/ | grep -qE 'hetzner*' && echo true || echo false)
NGPU=$(lspci | grep -i --color 'vga\|display\|3d\|2d' | grep -E 'NVIDIA' 1>/dev/null 2>&1 && echo true || echo false)
OSVE=$(./etc/os-release | echo $ID)
DIST=$(./etc/os-release | echo $ID$VERSION_ID)
VERS=$(./etc/os-release | echo $UBUNTU_CODENAME)

if [[ $IGPU == "true" && $NGPU == "false" ]]; then
   igpuhetzner
elif [[ $NGPU == "true" && $IGPU == "true" ]]; then
     nvidiagpu
elif [[ $NGPU == "true" && $IGPU == "false" ]]; then
     nvidiagpu
else 
    echo ""
fi

}

function endcommand() {
    if [[ $DEVT != "false" ]]; then
        $(which chmod) -R 750 /dev/dri
    else
        echo ""
        printf "\033[0;31m You need to restart the server to get access to /dev/dri
after restarting execute the install again\033[0m\n"
        echo ""
        read -p "Type confirm to reboot: " input
        if [[ "$input" = "confirm" ]]; then reboot -n; else endcommand; fi
    fi
}

function subos() {
    NSO=$(curl -s -L https://nvidia.github.io/nvidia-docker/$DIST/nvidia-docker.list)
    NSOE=$(echo ${NSO} | grep -E 'Unsupported')
    if [[ $NSOE != "" ]]; then
        printf "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      NVIDIA ❌ ERROR
      NVIDIA don't support your running Distribution
      Installed Distribution = ${DIST}
      Please visit the link below to see all supported Distributionen
      NVIDIA ❌ ERROR
      ${NSO}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
        read -erp "Confirm Info | Type confirm & PRESS [ENTER]" input </dev/tty
        if [[ "$input" = "confirm" ]]; then clear; else subos; fi
    fi
}

function igpuhetzner() {
    HMOD=$(ls /etc/modprobe.d/ | grep -qE 'hetzner' && echo true || echo false)
    ITEL=$(cat /etc/modprobe.d/blacklist-hetzner.conf | grep -qE '#blacklist i915' && echo true || echo false)
    IMOL1=$(cat /etc/default/grub | grep -qE '#GRUB_CMDLINE_LINUX_DEFAULT' && echo true || echo false)
    IMOL2=$(cat /etc/default/grub.d/hetzner.cfg | grep -qE '#GRUB_CMDLINE_LINUX_DEFAULT' && echo true || echo false)
    INTE=$(ls /usr/bin/intel_gpu_* 1>/dev/null 2>&1 && echo true || echo false)
    VIFO=$(which vainfo 1>/dev/null 2>&1 && echo true || echo false)

    if [[ $HMOD == "false" ]]; then exit; fi
    if [[ $ITEL == "false" ]]; then sed -i "s/blacklist i915/#blacklist i915/g" /etc/modprobe.d/blacklist-hetzner.conf; fi
    if [[ $IMOL1 == "false" ]]; then sed -i "s/GRUB_CMDLINE_LINUX_DEFAUL/#GRUB_CMDLINE_LINUX_DEFAUL/g" /etc/default/grub; fi
    if [[ $IMOL2 == "false" ]]; then sed -i "s/GRUB_CMDLINE_LINUX_DEFAUL/#GRUB_CMDLINE_LINUX_DEFAUL/g" /etc/default/grub.d/hetzner.cfg; fi
    if [[ $OSVE == "ubuntu" && $VERS == "focal" ]]; then
        if [[ $IMOL1 == "true" && $IMOL2 == "true" && $ITEL == "true" ]]; then sudo update-grub; fi
    else
        if [[ $IMOL1 == "true" && $IMOL2 == "true" && $ITEL == "true" ]]; then sudo grub-mkconfig -o /boot/grub/grub.cfg; fi
    fi
    if [[ $GCHK == "false" ]]; then groupadd -f video; fi
    if [[ $GVID == "false" ]]; then usermod -aG video $(whoami); fi
    endcommand
    if [[ $VIFO == "false" ]]; then $(command -v apt) install vainfo -yqq; fi
    if [[ $INTE == "false" && $IGPU == "true" ]]; then $(command -v apt) update -yqq && $(command -v apt) install intel-gpu-tools -yqq; fi
    if [[ $IMOL1 == "true" && $IMOL2 == "true" && $ITEL == "true" && $GVID == "true" && $DEVT == "true" ]]; then echo "Intel IGPU is working"; else echo "Intel IGPU is not working"; fi
}


function  nvidiagpu() {

echo "hold and keep command need rework"

}

## bin part 
function run() {
if [ ! $(which docker) ] && [ ! $(which docker-compose) ] && [ ! $(docker --version) ]; then
   preinstall
fi

if [[ -d ${dockserver} ]];then
   envmigra && fastapt && cleanup && clear && appstartup
else
   usage
fi
}

####
function update() {
dockserver=/opt/dockserver
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    🚀    DockServer [ UPDATE CONTAINER ] STARTED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
     basefolder="/opt/appdata"
     compose="compose/docker-compose.yml"
     $(which rsync) ${dockserver}/dockserver/docker.yml $basefolder/$compose -aqhv
     if [[ -f $basefolder/$compose ]];then
        $(which cd) $basefolder/compose/ && \
          $(which docker-compose) config 1>/dev/null 2>&1 && \
            $(which docker-compose) down 1>/dev/null 2>&1 && \
            $(which docker-compose) up -d --force-recreate 1>/dev/null 2>&1
     fi
     $(which chown) -cR 1000:1000 ${dockserver} 1>/dev/null 2>&1
     envmigra && fastapt && cleanup && clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    🚀    DockServer [ UPDATE CONTAINER ] DONE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
}
####
function fastapp() {
APP=${APP}
for i in ${APP[@]} ; do
    $(which find) /opt/dockserver/apps/ -mindepth 1 -type f -name "${i}*" -exec dirname {} \; | while read rename; do
      section="${rename#*/opt/dockserver/apps/}"                                  
      typed=$i
      if test -f /opt/dockserver/apps/$section/$i.yml; then
         source /opt/dockserver/function/function.sh
         typed=${typed}
         section=${section}
         runinstall
      fi
    done
done
}

####
function usage() {
clear
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀    DockServer [ USAGE COMMANDS ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Commands :

   dockserver -i / --install     =   open the dockserver setup
   dockserver -h / --help        =   help/usage
   dockserver -u / --update      =   deployed the update container

   dockserver -p / --preinstall  =   run preinstall parts for dockserver

   dockserver -a / --app <{NAMEOFAPP}>  =   fast app installation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀    DockServer [ USAGE COMMANDS ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
clear

}

function envmigra() {
basefolder="/opt/appdata"
dockserver="/opt/dockserver"
envmigrate="$dockserver/apps/.subactions/envmigrate.sh"
if [[ -f "$basefolder/compose/.env" ]];then
   $(which bash) $envmigrate
fi 
}

function fastapt() {
if ! type aria2c >/dev/null 2>&1; then
   $(which apt) update -yqq && \
   $(which apt) install --force-yes -y -qq aria2
fi
if [[ ! -f /etc/apt-fast.conf ]]; then
   $(which bash) -c "$(curl -sL https://raw.githubusercontent.com/ilikenwf/apt-fast/master/quick-install.sh)"
   echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections
   echo debconf apt-fast/dlflag boolean true | debconf-set-selections
   echo debconf apt-fast/aptmanager string apt | debconf-set-selections
fi
}

function cleanup() {
   $(which find) /var/log -type f -regex ".*\.gz$" -delete
   $(which find) /var/log -type f -regex ".*\.[0-9]$" -delete
}

## DS SETTINGS 

function appstartup() {
     dockertraefik=$(docker ps -aq --format '{{.Names}}' | sed '/^$/d' | grep -E 'traefik')
     ntdocker=$(docker network ls | grep -E 'proxy')
  if [[ $ntdocker == "" && $dockertraefik == "" ]]; then
     unset ntdocker && unset dockertraefik
     preinstall
  else
     unset ntdocker && unset dockertraefik
     clear && headinterface
  fi
}

function updatebin() {
file=/opt/dockserver/.installer/dockserver
store=/bin/dockserver
store2=/usr/bin/dockserver
if [[ -f "/bin/dockserver" ]];then
   $(which rm) $store && \
   $(which rsync) $file $store -aqhv
   $(which rsync) $file $store2 -aqhv
   $(which chown) -R 1000:1000 $store $store2
   $(which chmod) -R 755 $store $store2
fi
}

function headinterface() {

printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀 DockServer
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    [ 1 ] DockServer - Traefik + Authelia
    [ 2 ] DockServer - Applications

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↘️  Type Number and Press [ENTER]: " headsection </dev/tty
  case $headsection in
    1|traefik) clear && traefik ;;
    2|apps|app) clear && headapps ;;
    Z|z|exit|EXIT|Exit|close) updatebin && exit ;;
    *) clear && headapps ;;
  esac
}

function headapps() {
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  DockServer Applications Section Menu
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    [ 1 ] Install  Apps
    [ 2 ] Remove   Apps
    [ 3 ] Backup   Apps
    [ 4 ] Restore  Apps

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↘️  Type Number and Press [ENTER]: " headsection </dev/tty
  case $headsection in
    1|install|insta) clear && interface ;;
    2|remove|delete) clear && removeapp ;;
    3|backup|back) clear && backupstorage ;;
    4|restore|rest) clear && restorestorage ;;
    Z|z|exit|EXIT|Exit|close) headinterface ;;
    *) headapps ;;
  esac
}

function appinterface() {
buildshow=$(ls -1p /opt/dockserver/apps/ | grep '/$' | $(command -v sed) 's/\/$//')
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Applications Category Menu
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$buildshow

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↘️  Type Section Name and Press [ENTER]: " section </dev/tty
  case $section in
     Z|z|exit|EXIT|Exit|close) headapps ;;
     *) checksection=$(ls -1p /opt/dockserver/apps/ | grep '/$' | $(command -v sed) 's/\/$//' | grep -x $section) && \
     if [[ $checksection == $section ]];then clear && install ; else appinterface; fi ;;
  esac
}

function install() {
restorebackup=null
section=${section}
buildshow=$(ls -1p /opt/dockserver/apps/${section}/ | sed -e 's/.yml//g' )
printf "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Applications to install under ${section} category
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$buildshow

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
  read -erp "↪️ Type App-Name to install and Press [ENTER]: " typed </dev/tty
  case $typed in
    Z|z|exit|EXIT|Exit|close) headapps ;;
    *) buildapp=$(ls -1p /opt/dockserver/apps/${section}/ | $(command -v sed) -e 's/.yml//g' | grep -x $typed) && \
       if [[ $buildapp == $typed ]];then clear && runinstall && install; else install; fi ;;
  esac

}

### backup docker ###
function backupstorage() {
storagefolder=$(ls -1p /mnt/unionfs/appbackups/ | grep '/$' | $(command -v sed) 's/\/$//')
if [[ $storagefolder == "" ]];then 
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Backup folder
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 You need to set a backup folder
 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↪️ Type Name to set the Backup-Folder and Press [ENTER]: " storage </dev/tty
  case $storage in
     Z|z|exit|EXIT|Exit|close) headapps ;;
     *) if [[ $storage != "" ]];then $(command -v mkdir) -p /mnt/unionfs/appbackups/${storage};fi && \
           teststorage=$(ls -1p /mnt/unionfs/appbackups/ | grep '/$' | $(command -v sed) 's/\/$//' | grep -x $storage) && \
        if [[ $teststorage == $storage ]];then backupdocker;fi ;;
  esac
else
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Backup folder
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$storagefolder

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↪️ Type Name to set the Backup-Folder and Press [ENTER]: " storage </dev/tty
  case $storage in
    Z|z|exit|EXIT|Exit|close) headapps ;;
    *) if [[ $storage != "" ]];then $(command -v mkdir) -p /mnt/unionfs/appbackups/${storage};fi && \
          teststorage=$(ls -1p /mnt/unionfs/appbackups/ | grep '/$' | $(command -v sed) 's/\/$//' | grep -x $storage) && \
       elif [[ $teststorage == $storage ]];then
          backupstorage
       else
         $(command -v mkdir) -p /mnt/unionfs/appbackups/${storage} && newbackupfolder && backupdocker
       fi ;;
  esac
fi

}

function newbackupfolder() {
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  New Backup folder set to $storage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"
sleep 3

}

function backupdocker() {
storage=${storage}
rundockers=$(docker ps -aq --format '{{.Names}}' | sed '/^$/d' | grep -v 'trae' | grep -v 'auth' | grep -v 'cf-companion' | grep -v 'mongo' | grep -v 'dockupdater' | grep -v 'sudobox')
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Backup running Dockers
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$rundockers

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   [ all = Backup all running Container ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↪️ Type App-Name to Backup and Press [ENTER]: " typed </dev/tty
  case $typed in
     all|All|ALL) clear && backupall ;;
     Z|z|exit|EXIT|Exit|close) clear && headapps ;;
     *) builddockers=$(docker ps -aq --format '{{.Names}}' | sed '/^$/d' | grep -x ${typed}) && \
        if [[ $builddockers == $typed ]]; then clear && runbackup ; else backupdocker; fi ;; 
  esac
}

function backupall() {
OPTIONSTAR="--warning=no-file-changed \
  --ignore-failed-read \
  --absolute-names \
  --exclude-from=/opt/dockserver/apps/.backup/backup_excludes \
  --warning=no-file-removed \
  --use-compress-program=pigz"
STORAGE=${storage}
FOLDER="/opt/appdata"
DESTINATION="/mnt/downloads/appbackups"
dockers=$(docker ps -aq --format '{{.Names}}' | sed '/^$/d' | grep -v 'trae' | grep -v 'auth' | grep -v 'cf-companion' | grep -v 'mongo' | grep -v 'dockupdater' | grep -v 'sudobox')
for i in ${dockers};do
   ARCHIVE=$i
   ARCHIVETAR=${ARCHIVE}.tar.gz
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Backup is running for $i
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   if [[ ! -d ${DESTINATION} ]];then
      $(which mkdir) -p ${DESTINATION}
   fi
   if [[ ! -d ${DESTINATION}/${STORAGE} ]];then
      $(which mkdir) -p ${DESTINATION}/${STORAGE}
   fi
   forcepush=(tar pigz pv)
   $(which apt) install ${forcepush[@]} -yqq 1>/dev/null 2>&1
   appfolder=/opt/dockserver/apps/
   IGNORE="! -path '**.subactions/**'"
   mapfile -t files < <(eval find ${appfolder} -type f -name $typed.yml ${IGNORE})
   for i in "${files[@]}";do
       section=$(dirname "${i}" | sed "s#${appfolder}##g" | sed 's/\/$//')
   done
   if [[ ${section} == "mediaserver" || ${section} == "mediamanager" ]];then
      $(which docker) stop ${typed} 1>/dev/null 2>&1 && echo "We stopped now $typed"
printf "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Please Wait it cant take some minutes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
      $(which tar) ${OPTIONSTAR} -C ${FOLDER}/${ARCHIVE} -pcf ${DESTINATION}/${STORAGE}/${ARCHIVETAR} ./
      $(which docker) start ${typed} 1>/dev/null 2>&1  && echo "We started now $typed"
   else
      $(which tar) ${OPTIONSTAR} -C ${FOLDER}/${ARCHIVE} -pcf ${DESTINATION}/${STORAGE}/${ARCHIVETAR} ./
   fi
   $(which chown) -hR 1000:1000 ${DESTINATION}/${STORAGE}/${ARCHIVETAR}
done
clear && backupdocker
}

function runbackup() {
OPTIONSTAR="--warning=no-file-changed \
  --ignore-failed-read \
  --absolute-names \
  --exclude-from=/opt/dockserver/apps/.backup/backup_excludes \
  --warning=no-file-removed \
  --use-compress-program=pigz"
typed=${typed}
STORAGE=${storage}
FOLDER="/opt/appdata"
DESTINATION="/mnt/downloads/appbackups"
if [[ -d ${FOLDER}/${typed} ]];then
   ARCHIVE=${typed}
   ARCHIVETAR=${ARCHIVE}.tar.gz
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Backup is running for ${typed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   if [[ ! -d ${DESTINATION} ]];then
      $(which mkdir) -p ${DESTINATION}
   fi
   if [[ ! -d ${DESTINATION}/${STORAGE} ]];then
      $(which mkdir) -p ${DESTINATION}/${STORAGE}
   fi
   forcepush=(tar pigz pv)
   $(which apt) install ${forcepush[@]} -yqq 1>/dev/null 2>&1
   appfolder=/opt/dockserver/apps/
   IGNORE="! -path '**.subactions/**'"
   mapfile -t files < <(eval find ${appfolder} -type f -name $typed.yml ${IGNORE})
   for i in "${files[@]}";do
       section=$(dirname "${i}" | sed "s#${appfolder}##g" | sed 's/\/$//')
   done
   if [[ ${section} == "mediaserver" || ${section} == "mediamanager" ]];then
      $(which docker) stop ${typed} 1>/dev/null 2>&1 && echo "We stopped now $typed"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Please Wait it can take some minutes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      $(which tar) ${OPTIONSTAR} -C ${FOLDER}/${ARCHIVE} -pcf ${DESTINATION}/${STORAGE}/${ARCHIVETAR} ./
      $(which docker) start ${typed} 1>/dev/null 2>&1  && echo "We started now $typed"
   else
      $(which tar) ${OPTIONSTAR} -C ${FOLDER}/${ARCHIVE} -pcf ${DESTINATION}/${STORAGE}/${ARCHIVETAR} ./
   fi
   $(which chown) -hR 1000:1000 ${DESTINATION}/${STORAGE}/${ARCHIVETAR}
   clear && backupdocker
else
   clear && backupdocker
fi
}

function restorestorage() {
storage=$(ls -1p /mnt/unionfs/appbackups/ | grep '/$' | $(command -v sed) 's/\/$//' | grep -v 'sudobox')
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Restore folder
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$storage

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  read -erp "↪️ Type Name to set the Backup-Folder and Press [ENTER]: " storage </dev/tty
  case $typed in
     Z|z|exit|EXIT|Exit|close) clear && headapps ;;
     *) teststorage=$(ls -1p /mnt/unionfs/appbackups/ | grep '/$' | $(command -v sed) 's/\/$//' | grep -x $storage) && \
        if [[ $teststorage == $storage ]];then clear && restorestorage; else backupstorage; fi ;;
  esac
}

function restoredocker() {
storage=${storage}
runrestore=$(ls -1p /mnt/unionfs/appbackups/${storage} | $(command -v sed) -e 's/.tar.gz//g' | grep -v 'trae' | grep -v 'auth' | grep -v 'sudobox')
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Restore Dockers
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$runrestore

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -erp "↪️ Type App-Name to Restore and Press [ENTER]: " typed </dev/tty
  case $typed in
     all|All|ALL) clear && restoreall ;;
     *) builddockers=$(ls -1p /mnt/unionfs/appbackups/${storage} | $(command -v sed) -e 's/.tar.gz//g' | grep -x $typed) && \
        if [[ $builddockers == $typed ]]; then clear && runrestore ; else restoredocker; fi ;;
  esac
}

function restoreall() {
STORAGE=${storage}
FOLDER="/opt/appdata"
DESTINATION="/mnt/unionfs/appbackups"
apps=$(ls -1p /mnt/unionfs/appbackups/${storage} | $(command -v sed) -e 's/.tar.gz//g' | grep -v 'trae' | grep -v 'auth' | grep -v 'sudobox')
forcepush=(tar pigz pv)
$(which apt) install ${forcepush[@]} -yqq 1>/dev/null 2>&1

for app in ${apps};do
   basefolder="/opt/appdata"
   if [[ ! -d $basefolder/$app ]];then
   ARCHIVE=$app
   ARCHIVETAR=${ARCHIVE}.tar.gz
      echo "Create folder for $i is running"  
      folder=$basefolder/$app
      for appset in ${folder};do
          $(which mkdir) -p $appset
          $(which find) $appset -exec $(command -v chmod) a=rx,u+w {} \;
          $(which find) $appset -exec $(command -v chown) -hR 1000:1000 {} \;
      done
   fi
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Restore is running for $i
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   $(which unpigz) -dcqp 8 ${DESTINATION}/${STORAGE}/${ARCHIVETAR} | $(command -v pv) -pterb | $(command -v tar) pxf - -C ${FOLDER}/${ARCHIVE} --strip-components=1
done
clear && headapps
}

function runrestore() {
typed=${typed}
STORAGE=${storage}
FOLDER="/opt/appdata"
ARCHIVE=${typed}
ARCHIVETAR=${ARCHIVE}.tar.gz
restorebackup=restoredocker
DESTINATION="/mnt/unionfs/appbackups"
basefolder="/opt/appdata"
compose="compose/docker-compose.yml"
forcepush=(tar pigz pv)
$(which apt) install ${forcepush[@]} -yqq 1>/dev/null 2>&1

   folder=$basefolder/${typed}
   for i in ${folder};do
       $(which mkdir) -p $i
       $(which find) $i -exec $(command -v chmod) a=rx,u+w {} \;
       $(which find) $i -exec $(command -v chown) -hR 1000:1000 {} \;
   done

builddockers=$(ls -1p /mnt/unionfs/appbackups/${storage} | $(command -v sed) -e 's/.tar.gz//g' | grep -x $typed)
if [[ $builddockers == $typed ]];then
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  Restore is running for ${typed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   $(which unpigz) -dcqp 8 ${DESTINATION}/${STORAGE}/${ARCHIVETAR} | $(command -v pv) -pterb | $(command -v tar) pxf - -C ${FOLDER}/${ARCHIVE} --strip-components=1
   appfolder=/opt/dockserver/apps/
   IGNORE="! -path '**.subactions/**'"
   mapfile -t files < <(eval find ${appfolder} -type f -name $typed.yml ${IGNORE})
   for i in "${files[@]}";do
       section=$(dirname "${i}" | sed "s#${appfolder}##g" | sed 's/\/$//')
   done
   section=${section}
   typed=${typed}
   restorebackup=${restorebackup}
   runinstall && clear
else
   clear && restoredocker
fi
}

function runinstall() {
  restorebackup=${restorebackup:-null}
  section=${section}
  typed=${typed}
  updatecompose
  compose="compose/docker-compose.yml"
  composeoverwrite="compose/docker-compose.override.yml"
  storage="/mnt/downloads"
  appfolder="/opt/dockserver/apps"
  basefolder="/opt/appdata"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Please Wait, We are installing ${typed} for you
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  $(which mkdir) -p $basefolder/compose/
  $(which find) $basefolder/compose/ -type f -name "docker*" -exec rm -f {} \;
  $(which rsync) $appfolder/${section}/${typed}.yml $basefolder/$compose -aqhv
  if [[ ${section} == "mediaserver" || ${section} == "encoder" ]]; then
     if [[ -x "/dev/dri" ]]; then
        if test -f /etc/modprobe.d/blacklist-hetzner.conf; then
           $(which rsync) $appfolder/${section}/.gpu/INTEL.yml $basefolder/$composeoverwrite -aqhv
        else
           $(which rsync) $appfolder/${section}/.gpu/NVIDIA.yml $basefolder/$composeoverwrite -aqhv
        fi
     fi
     if [[ -f $basefolder/$composeoverwrite ]];then
        if [[ $(uname) == "Darwin" ]];then
           $(which sed) -i '' "s/<APP>/${typed}/g" $basefolder/$composeoverwrite
        else
           $(which sed) -i "s/<APP>/${typed}/g" $basefolder/$composeoverwrite
        fi
     fi
  fi
  if [[ -f $appfolder/${section}/.overwrite/${typed}.overwrite.yml ]];then
     $(command -v rsync) $appfolder/${section}/.overwrite/${typed}.overwrite.yml $basefolder/$composeoverwrite -aqhv
  fi
  if [[ ! -d $basefolder/${typed} ]];then
     folder=$basefolder/${typed}
     for fol in ${folder};do
         $(which mkdir) -p $fol
         $(which find) $fol -exec $(which chmod) a=rx,u+w {} \;
         $(which find) $fol -exec $(which chown) -hR 1000:1000 {} \;
     done
  fi
  container=$($(which docker) ps -aq --format '{{.Names}}' | grep -x ${typed})
  if [[ $container == ${typed} ]];then
     docker="stop rm"
     for con in ${docker};do
         $(which docker) $con ${typed} 1>/dev/null 2>&1
     done
     $(which docker) image prune -af 1>/dev/null 2>&1
  else
     $(which docker) image prune -af 1>/dev/null 2>&1
  fi
  if [[ ${typed} == "vnstat" ]];then vnstatcheck;fi
  if [[ ${typed} == "autoscan" ]];then autoscancheck;fi
  if [[ ${typed} == "plex" ]];then plexclaim && plex443;fi
  if [[ ${typed} == "jdownloader2" ]];then
     folder=$storage/${typed}
     for jdl in ${folder};do
         $(which mkdir) -p $jdl
         $(which find) $jdl -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $jdl -exec $(command -v chown) -hR 1000:1000 {} \;
     done
  fi
  if [[ ${typed} == "rutorrent" ]];then
     folder=$storage/torrent
     for rto in ${folder};do
         $(which mkdir) -p $rto/{temp,complete}/{movies,tv,tv4k,movies4k,movieshdr,tvhdr,remux}
         $(which find) $rto -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $rto -exec $(command -v chown) -hR 1000:1000 {} \;
     done
  fi
  if [[ ${typed} == "lidarr" ]];then
     folder=$storage/amd
     for lid in ${folder};do
         $(which mkdir) -p $lid
         $(which find) $lid -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $lid -exec $(command -v chown) -hR 1000:1000 {} \;
     done
  fi
  if [[ && ${typed} == "readarr" ]];then
     folder=$storage/books
     for rea in ${folder};do
         $(which mkdir) -p $rea
         $(which find) $rea -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $rea -exec $(command -v chown) -hR 1000:1000 {} \;
     done
  fi
  if [[ ${typed} == "mount" ]];then
     $(which docker) stop mount &>/dev/null && $(command -v docker) rm mount &>/dev/null
     $(which fusermount) -uzq /mnt/remotes /mnt/rclone_cache /mnt/unionfs
  fi
  if [[ ${typed} == "youtubedl-material" ]];then
     folder="appdata audio video subscriptions"
     for ytf in ${folder};do
         $(which mkdir) -p $basefolder/${typed}/$ytf
         $(which find) $basefolder/${typed}/$ytf -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $basefolder/${typed}/$ytf -exec $(command -v chown) -hR 1000:1000 {} \;
     done
     folder=$storage/youtubedl
     for ytdl in ${folder};do
         $(which mkdir) -p $ytdl
         $(which find) $ytdl -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $ytdl -exec $(command -v chown) -hR 1000:1000 {} \;
     done
  fi
  if [[ ${typed} == "handbrake" ]];then
     folder=$storage/${typed}
     for hbrake in ${folder};do
         $(which mkdir) -p $hbrake/{watch,storage,output}
         $(which find) $hbrake -exec $(command -v chmod) a=rx,u+w {} \;
         $(which find) $hbrake -exec $(command -v chown) -hR 1000:1000 {} \;
     done
  fi
  if [[ ${typed} == "bitwarden" ]];then
     if [[ -f $appfolder/.subactions/${typed}.sh ]];then $(which bash) $appfolder/.subactions/${typed}.sh;fi
  fi
  if [[ ${typed} == "dashy" ]];then
     if [[ -f $appfolder/.subactions/${typed}.sh ]];then $(which bash) $appfolder/.subactions/${typed}.sh;fi
  fi
  if [[ ${typed} == "invitarr" ]];then
      $(which nano) $basefolder/$compose      
      $(which rsync) $appfolder/.subactions/${typed}.js $basefolder/${typed}/config.ini -aqhv
      $(which nano) $basefolder/${typed}/config.ini
  fi
  if [[ ${typed} == "plex-utills" ]];then
     if [[ -f $appfolder/.subactions/${typed}.sh ]];then $(command -v bash) $appfolder/.subactions/${typed}.sh;fi
  fi
  if [[ ${typed} == "petio" ]];then $(command -v mkdir) -p $basefolder/${typed}/{db,config,logs} && $(which chown) -hR 1000:1000 $basefolder/${typed}/{db,config,logs} 1>/dev/null 2>&1;fi
  if [[ ${typed} == "tdarr" ]];then $(command -v mkdir) -p $basefolder/${typed}/{server,configs,logs,encoders} && $(which chown) -hR 1000:1000 $basefolder/${typed}/{server,configs,logs} 1>/dev/null 2>&1;fi
  if [[ -f $basefolder/$compose ]];then
     $(which cd) $basefolder/compose/
     $(which docker-compose) config 1>/dev/null 2>&1
     errorcode=$?
     if [[ $errorcode -ne 0 ]];then
     erroline=$($(which docker-compose) config)
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ❌ ERROR
    Compose check of ${typed} has failed
    Return code is ${errorcode}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 5
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ❌ OUTPUT OF COMPOSER ERROR
    ${erroline}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -erp "Confirm Info | PRESS [ENTER]" typed </dev/tty
  clear && interface
     else
        $(which docker-compose) up -d --force-recreate 1>/dev/null 2>&1
     fi
  fi
  if [[ ${section} == "mediaserver" || ${section} == "request" ]];then subtasks;fi
  if [[ ${typed} == "xteve" || ${typed} == "heimdall" || ${typed} == "librespeed" || ${typed} == "tautulli" || ${typed} == "nextcloud" ]];then subtasks;fi
  if [[ ${section} == "downloadclients" ]];then subtasks;fi
  if [[ ${typed} == "overseerr" ]];then overserrf2ban;fi
     setpermission
     $($(which docker) ps -aq --format '{{.Names}}{{.State}}' | grep -qE ${typed}running 1>/dev/null 2>&1)
     errorcode=$?
  if [[ $errorcode -eq 0 ]];then
     TRAEFIK=$(cat $basefolder/$compose | grep "traefik.enable" | wc -l)
  if [[ ${TRAEFIK} == "0" ]];then
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ${typed} has successfully deployed and is now working     
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  source $basefolder/compose/.env
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ${typed} has successfully deployed = > https://${typed}.${DOMAIN}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  sleep 10
  clear
  fi
  fi
  if [[ ${restorebackup} == "restoredocker" ]];then clear && restorestorage;fi
  clear
}

function setpermission() {
approot=$($(which ls) -l $basefolder/${typed} | awk '{if($3=="root") print $0}' | wc -l)
if [[ $approot -gt 0 ]];then
IFS=$'\n'
mapfile -t setownapp < <(eval $(command -v ls) -l $basefolder/${typed}/ | awk '{if($3=="root") print $0}' | awk '{print $9}')
  for appset in ${setownapp[@]};do
      if [[ $(whoami) == "root" ]];then $(which chown) -hR 1000:1000 $basefolder/${typed}/$appset;fi
      if [[ $(whoami) != "root" ]];then $(which chown) -hR $(whoami):$(whoami) $basefolder/${typed}/$appset;fi
  done
fi
dlroot=$($(which ls) -l $storage/ | awk '{if($3=="root") print $0}' | wc -l)
if [[ $dlroot -gt 0 ]];then
IFS=$'\n'
mapfile -t setowndl < <(eval $(command -v ls) -l $storage/ | awk '{if($3=="root") print $0}' | awk '{print $9}')
  for dlset in ${setowndl[@]};do
      if [[ $(whoami) == "root" ]];then $(command -v chown) -hR 1000:1000 $storage/$dlset;fi
      if [[ $(whoami) != "root" ]];then $(command -v chown) -hR $(whoami):$(whoami) $storage/$dlset;fi
  done
fi
}

function overserrf2ban() {
OV2BAN="/etc/fail2ban/filter.d/overseerr.local"
if [[ ! -f $OV2BAN ]];then
   cat > $OV2BAN << EOF; $(echo)
## overseerr fail2ban filter ##
[Definition]
failregex = .*\[info\]\[Auth\]\: Failed sign-in attempt.*"ip":"<HOST>"
EOF
fi

f2ban=$($(command -v systemctl) is-active fail2ban | grep -qE 'active' && echo true || echo false)
if [[ $f2ban != "false" ]];then $(which systemctl) reload-or-restart fail2ban.service 1>/dev/null 2>&1;fi
}

function vnstatcheck() {
if [[ ! -x $(command -v vnstat) ]];then $(which apt) install vnstat -yqq;fi
}

function autoscancheck() {
$(docker ps -aq --format={{.Names}} | grep -E 'arr|ple|emb|jelly' 1>/dev/null 2>&1)
code=$?
if [[ $code -eq 0 ]];then
   $(command -v rsync) $appfolder/.subactions/${typed}.config.yml $basefolder/${typed}/config.yml -aqhv
   $(command -v bash) $appfolder/.subactions/${typed}.sh
fi
}

function plexclaim() {
compose="compose/docker-compose.yml"
basefolder="/opt/appdata"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  PLEX CLAIM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Please claim your Plex server
    https://www.plex.tv/claim/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -erp "Enter your PLEX CLAIM CODE : " PLEXCLAIM </dev/tty
  if [[ $PLEXCLAIM != "" ]];then
     if [[ $(uname) == "Darwin" ]];then
        $(which sed) -i '' "s/PLEX_CLAIM_ID/$PLEXCLAIM/g" $basefolder/$compose
     else
        $(which sed) -i "s/PLEX_CLAIM_ID/$PLEXCLAIM/g" $basefolder/$compose
     fi
  else
     echo "Plex Claim cannot be empty"
     plexclaim
  fi
}

function plex443() {
basefolder="/opt/appdata"
source $basefolder/compose/.env
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀  PLEX 443 Options
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    You need to add a Cloudflare Page Rule
    https://dash.cloudflare.com/
    > Domain
      > Rules
        > add new rule
          > Domain : plex.${DOMAIN}/*
          > cache-level: bypass
        > save
    __________________

    > in plex settings
      > settings
        > remote access
          > remote access = enabled
          > manual port 32400
          > save
        > network
          > Strict TLS configuration [ X ]
          > allowed networks = 172.18.0.0
          > save 
      > have fun !
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -erp "Confirm Info | PRESS [ENTER]" typed </dev/tty

}

function subtasks() {
typed=${typed}
section=${section}
basefolder="/opt/appdata"
appfolder="/opt/dockserver/apps"
source $basefolder/compose/.env
authcheck=$($(command -v docker) ps -aq --format '{{.Names}}' | grep -x 'authelia' 1>/dev/null 2>&1 && echo true || echo false)
conf=$basefolder/authelia/configuration.yml
confnew=$basefolder/authelia/.new-configuration.yml.new
confbackup=$basefolder/authelia/.backup-configuration.yml.backup
authadd=$(cat $conf | grep -E ${typed})
  if [[ ! -x $(command -v ansible) || ! -x $(command -v ansible-playbook) ]];then $(command -v apt) install ansible -yqq;fi
  if [[ -f $appfolder/.subactions/${typed}.yml ]];then $(command -v ansible-playbook) $appfolder/.subactions/${typed}.yml;fi
     $(grep "model name" /proc/cpuinfo | cut -d ' ' -f3- | head -n1 |grep -qE 'i7|i9' 1>/dev/null 2>&1)
     setcode=$?
     if [[ $setcode -eq 0 ]];then
        if [[ -f $appfolder/.subactions/${typed}.sh ]];then $(which bash) $appfolder/.subactions/${typed}.sh;fi
     fi
  if [[ $authadd == "" ]];then
     if [[ ${section} == "mediaserver" || ${section} == "request" ]];then
     { head -n 55 $conf;
     echo "\
    - domain: ${typed}.${DOMAIN}
      policy: bypass"; tail -n +56 $conf; } > $confnew
        if [[ -f $conf ]];then $(which rsync) $conf $confbackup -aqhv;fi
        if [[ -f $conf ]];then $(which rsync) $confnew $conf -aqhv;fi
        if [[ $authcheck == "true" ]];then $(which docker) restart authelia 1>/dev/null 2>&1;fi
        if [[ -f $conf ]];then $(command -v rm) -rf $confnew;fi
     fi
     if [[ ${typed} == "xteve" || ${typed} == "heimdall" || ${typed} == "librespeed" || ${typed} == "tautulli" || ${typed} == "nextcloud" ]];then
     { head -n 55 $conf;
     echo "\
    - domain: ${typed}.${DOMAIN}
      policy: bypass"; tail -n +56 $conf; } > $confnew
        if [[ -f $conf ]];then $(which rsync) $conf $confbackup -aqhv;fi
        if [[ -f $conf ]];then $(which rsync) $confnew $conf -aqhv;fi
        if [[ $authcheck == "true" ]];then $(which docker) restart authelia 1>/dev/null 2>&1;fi
        if [[ -f $conf ]];then $(which rm) -rf $confnew;fi
     fi
  fi
  if [[ ${section} == "mediaserver" || ${section} == "request" || ${section} == "downloadclients" ]];then $(which docker) restart ${typed} 1>/dev/null 2>&1;fi
  if [[ ${section} == "request" ]];then $(which chown) -R 1000:1000 $basefolder/${typed} 1>/dev/null 2>&1;fi
}

function removeapp() {
list=$($(which docker) ps -aq --format '{{.Names}}' | grep -vE 'auth|trae|cf-companion')
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀   App Removal Menu
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$list

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    [ EXIT or Z ] - Exit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -erp "↪️ Type App-Name to remove and Press [ENTER]: " typed </dev/tty
  case $typed in
     Z|z|exit|EXIT|Exit|close) clear && headapps ;;
     *) checktyped=$($(which docker) ps -aq --format={{.Names}} | grep -x $typed)
        if [[ $checktyped == $typed ]];then clear && deleteapp; else removeapp; fi ;;
  esac
}

function deleteapp() {
  typed=${typed}
  basefolder="/opt/appdata"
  storage="/mnt/downloads"
  source $basefolder/compose/.env
  conf=$basefolder/authelia/configuration.yml
  checktyped=$($(command -v docker) ps -aq --format={{.Names}} | grep -x $typed)
  auth=$(cat -An $conf | grep -x ${typed}.${DOMAIN} | awk '{print $1}')
  if [[ $checktyped == $typed ]];then
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ${typed} removal started    
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
     app=${typed}
     for i in ${app};do
         $(which docker) stop $i 1>/dev/null 2>&1
         $(which docker) rm $i 1>/dev/null 2>&1
         $(which docker) image prune -af 1>/dev/null 2>&1
     done
     if [[ -d $basefolder/${typed} ]];then 
        folder=$basefolder/${typed}
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   App ${typed} folder removal started
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for i in ${folder};do
            $(which rm) -rf $i 1>/dev/null 2>&1
        done
     fi
     if [[ -d $storage/${typed} ]];then 
        folder=$storage/${typed}
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Storage ${typed} folder removal started
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for i in ${folder};do
            $(which rm) -rf $i 1>/dev/null 2>&1
        done
     fi
     if [[ $auth == ${typed} ]];then
        if [[ ! -x $(command -v bc) ]];then $(command -v apt) install bc -yqq 1>/dev/null 2>&1;fi
           source $basefolder/compose/.env
           authrmapp=$(cat -An $conf | grep -x ${typed}.${DOMAIN})
           authrmapp2=$(echo "$(${authrmapp} + 1)" | bc)
        if [[ $authrmapp != "" ]];then sed -i '${authrmapp};${authrmapp2}d' $conf;fi
           $($(which docker) ps -aq --format '{{.Names}}' | grep -x authelia 1>/dev/null 2>&1)
           newcode=$?
        if [[ $newcode -eq 0 ]];then $(which docker) restart authelia;fi
     fi
     source $basefolder/compose/.env 
     if [ ${DOMAIN1_ZONE_ID} != "" ] && [ ${DOMAIN} != "" ] && [ ${CLOUDFLARE_EMAIL} != "" ] ; then
        $(which apt) install curl -yqq
        dnsrecordid=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones/$DOMAIN1_ZONE_ID/dns_records?name=${typed}.${DOMAIN}" -H "X-Auth-Email: $CLOUDFLARE_EMAIL" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
        if [[ $dnsrecordid != "" ]] ; then
           result=$(curl -sX DELETE "https://api.cloudflare.com/client/v4/zones/$DOMAIN1_ZONE_ID/dns_records/$dnsrecordid" -H "X-Auth-Email: $CLOUDFLARE_EMAIL" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" -H "Content-Type: application/json")
           if [[ $result != "" ]]; then
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ${typed} CNAME record removed from Cloudflare 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"          
           fi
        fi
    fi
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ${typed} removal finished
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sleep 2 && removeapp
  else
     removeapp
  fi
}

function updatecompose() {
    $(which curl) -L --fail https://raw.githubusercontent.com/linuxserver/docker-docker-compose/master/run.sh -o /usr/local/bin/docker-compose
    $(which ln) -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    $(which chmod) +x /usr/local/bin/docker-compose /usr/bin/docker-compose
}
# ENDSTAGE
