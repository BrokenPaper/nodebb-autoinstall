#!/bin/bash

red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

cmd="yum"

ask_user() {
  while true; do

    echo -e "$3"
    read -r -p "请输入 $1" USER_INPUT
    echo "$1" | tr "/" "\n" | grep -Eiq "^${USER_INPUT}$" && eval "$2=\"$USER_INPUT\"" && break
  done
}

if [[ $(command -v apt-get) || $(command -v yum) ]] && [[ $(command -v systemctl) ]]; then

  if [[ $(command -v apt-get) ]]; then

    cmd="apt-get"

  fi

else

  echo -e " 
	哈哈……这个 ${red}辣鸡脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}
	备注: 仅支持 Ubuntu 16+ / Debian 8+ / CentOS 7+ 系统
	" && exit 1

fi
install() {

  # 低级的检测方法
  if [[ -f /home/nodebb ]]; then
    echo
    echo " ...你已经安装过NodeBB 啦...无需重新安装"
    echo
    echo -e " $yellow输入 ${cyan}v2ray${none} $yellow即可管理 V2Ray${none}"
    echo
    exit 1

  fi

  [[ $(id -u) != 0 ]] && cmd="sudo "+$cmd
  sed -i 's/SELINUX=[eE]nforcing/disabled/g' /etc/sysconfig/selinux
  $cmd update -y

  if [ $cmd == 'yum' ]; then
    $cmd -y install epel-release
    $cmd -y groupinstall "Development Tools"
    $cmd -y install git ImageMagick ImageMagick-devel
  fi
  curl -sL https://rpm.nodesource.com/setup_12.x | bash -
  changeNodeRepo
  # 这真的有必要吗
  $cmd update -y
  $cmd install -y nodejs

  if [[ ! $(command -v node) || ! $(command -v npm) ]]; then
    echo "检测到Nodejs或者npm安装失败了"
    return
  fi

  install_mongodb

}

changeNodeRepo() {

  ask_user "y/n" "nodeRepo" "是否要修改Nodejs的镜像源(国内服务器推荐)"
  [ "$YES_OR_NO" = "y" ] && {

    if [ $cmd == 'yum' ]; then

      sed -i 's/rpm\.nodesource\.com/mirrors\.ustc\.edu\.cn/g' /etc/yum.repos.d/nodesource-el7.repo
    elif [ $cmd == 'apt-get' ]; then

      sed -i 's/rpm\.nodesource\.com/mirrors\.ustc\.edu\.cn/g' /etc/apt/sources.list.d/nodesource.list
    fi
  }

}

install_mongodb() {
  # 这个源也太慢了把兄弟
  echo "[mongodb-org-4.2] 
name = MongoDB Repository 
baseurl = https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.2/x86_64/ 
gpgcheck = 1 
enabled = 1 
gpgkey = https://www.mongodb.org/static/pgp/server-4.2.asc" >/etc/yum.repos.d/mongodb-org-4.2.repo

  $cmd update
  $cmd -y install mongodb-org
  if [[ $(command -v mongo) ]]; then
    echo "检测到Mongodb安装失败了"
    return
  fi
  echo 'never' | sudo tee -a /sys/kernel/mm/transparent_hugepage/enabled >/dev/null
  echo 'never' | sudo tee -a /sys/kernel/mm/transparent_hugepage/defrag >/dev/null

  sudo systemctl start mongod
  configure_mongodb

}

configure_mongodb() {

$cmd install expect -y
  read -r -p "$(echo -e "请输入 [${magenta}Mongodb的数据库名(nodebb)$none]:")" db
  if [ -z "${db}" ]; then
    db="nodebb"
  fi
  read -r -p "$(echo -e "请输入 [${magenta}Mongodb的用户名(nodebb)$none]:")" dbname
  if [ -z "${dbname}" ]; then
    dbname="nodebb"
  fi
  read -r -p "$(echo -e "请输入 [${magenta}Mongodb的密码(自己想)$none]:")" dbpass
  spawn mongo
  expect ">"
  send "use $db"
  expect ">"
  send "db.createUser( { user: $name, pwd: $pass, roles: [ \"readWrite\" ] } )"
  expect ">"
  send "db.grantRolesToUser($name,[{ role: \"clusterMonitor\", db: \"admin\" }]);"
  send "exit\r"
  expect eof

}

install_nodebb() {

  cd /home || exit
  git clone -b v1.13.x https://github.com/NodeBB/NodeBB.git nodebb
}

error() {

  echo -e "\n$red 输入错误！$none\n"

}

while :; do
  echo
  echo "........... NodeBB 一键安装脚本 & 管理脚本 meitianxue.net 每天学 制作 .........."
  echo
  echo "这个脚本结合了各位大佬的思路"
  echo "脚本发布地址: https://meitianxue.net"
  echo "有问题请在脚本发布页面留言,我会解决的"
  echo "暂时只支持(测试过)Centos7系统"
  echo
  echo "参考 https://www.yuque.com/a632079/nodebb/installation-os-centos"
  echo "特别感谢 gaein 233boy"
  echo
  echo " 1. 安装"
  echo
  echo " 2. 卸载(暂不支持)"
  echo
  read -p "$(echo -e "请选择 [${magenta}1-2$none]:")" choose
  case $choose in
  1)
    install
    break
    ;;
  2)
    break
    ;;
  *)
    error
    ;;
  esac
done