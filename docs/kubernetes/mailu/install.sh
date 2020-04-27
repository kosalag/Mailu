#!/bin/bash
# ------------------------------------------------------------------
# [Kosalag] Mailu installer
#          This script deploys mailu server into a k8s cluster
# ------------------------------------------------------------------

VERSION=0.1.0
SUBJECT="Deployment Script for Mailu"

USAGE () {
    echo  " Options:

  -d, Domain Name
  -a, Admin User Name
  -h, 
  
  Display this help and exit"
}
USAGE=

# --- Options processing -------------------------------------------
if [ $# == 0 ] ; then
    echo $USAGE
    exit 1;
fi

while getopts ":d:a:vh" optname
  do
    case "$optname" in
      "v")
        echo "Version $VERSION"
        exit 0;
        ;;
      "d")
        HOST_NAME=$OPTARG
        ;;
      "a")
        ADMIN_USER=$OPTARG
        ;;
      "h")
        USAGE
        exit 0;
        ;;
      "?")
        echo "Unknown option $OPTARG"
        exit 0;
        ;;
      ":")
        echo "No argument value for option $OPTARG"
        exit 0;
        ;;
      *)
        echo "Unknown error while processing options"
        exit 0;
        ;;
    esac
  done

shift $(($OPTIND - 1))

param1=$1
param2=$2

# --- Locks -------------------------------------------------------
LOCK_FILE=/tmp/$SUBJECT.lock
if [ -f "$LOCK_FILE" ]; then
   echo "Script is already running"
   exit
fi

trap "rm -f $LOCK_FILE" EXIT
touch $LOCK_FILE

# --- Body --------------------------------------------------------

echo -n "Admin User Password: "
read -s ADMIN_PWD

DOMAIN=${HOST_NAME#*.*} #Get Domain from the given hostname

echo $HOST_NAME
echo $DOMAIN
echo $ADMIN_USER

echo "******** Writing Config Changes ********"

# Write configurations to configmap.yaml
sed -i "s/mail.example.com/$HOST_NAME/g" configmap.yaml
sed -i "s/example.com/$DOMAIN/g" configmap.yaml

sed -i "s/INITIAL/#INITIAL/g" configmap.yaml # Comment out if already set
cat <<EOT >> configmap.yaml
    INITIAL_ADMIN_ACCOUNT: "${ADMIN_USER}"
    INITIAL_ADMIN_HOST_NAME: "${HOST_NAME}"
    INITIAL_ADMIN_PW: "${ADMIN_PWD}"

EOT

echo "******** Writing Config Changes Success ********"


kubectl create -f rbac.yaml
kubectl create -f configmap.yaml
kubectl create -f pvc.yaml && sleep 10
kubectl create -f redis.yaml && sleep 30
kubectl create -f front.yaml && sleep 30
kubectl create -f webmail.yaml && sleep 30
kubectl create -f imap.yaml && sleep 30
kubectl create -f security.yaml && sleep 30
kubectl create -f smtp.yaml && sleep 30
kubectl create -f fetchmail.yaml && sleep 30
kubectl create -f admin.yaml && sleep 30
kubectl create -f webdav.yaml && sleep 30
kubectl create -f ingress.yaml && sleep 30


# Get IMAP Pod Name
IMAP_POD=$(kubectl get po -l app=mailu-imap -o custom-columns=NAME:.metadata.name --no-headers -n mailu-mailserver)
echo "IMAP POD NAME - " $IMAP_POD
kubectl cp dovecot.conf $IMAP_POD:/overrides/dovecot.conf -n mailu-mailserver
kubectl delete po $IMAP_POD -n mailu-mailserver && sleep 30
kubectl get po -n mailu-mailserver


echo ""
echo ""
echo "Setup finished. When all the pods are running, visit https://$HOST_NAME/admin"
echo "Happy Mailing..."

# -----------------------------------------------------------------