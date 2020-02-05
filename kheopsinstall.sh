#!/bin/bash

if [ ! -x "$(command -v docker)" ];
then
  echo "You must install docker"
  echo "https://docs.docker.com/install/"
  exit 1
fi

if [ ! -x "$(command -v docker-compose)" ];
then
  echo "You must install docker-compose"
  echo "https://docs.docker.com/compose/install/"
  exit 1
fi

secretpath="kheops/secrets/"
kheopspath="kheops/"

echo "Download project docker"
if [[ ! -d "$kheopspath" ]]
then
  mkdir $kheopspath
fi

if [[ ! -f "${kheopspath}.env" ]]
then
  (cd $kheopspath && curl https://raw.githubusercontent.com/OsiriX-Foundation/kheopsDocker/install-secure/kheops/.env --output .env --silent)
fi

if [[ ! -f "${kheopspath}docker-compose.env" ]]
then
  (cd $kheopspath && curl https://raw.githubusercontent.com/OsiriX-Foundation/kheopsDocker/install-secure/kheops/docker-compose.env --output docker-compose.env --silent)
fi

if [[ ! -f "${kheopspath}docker-compose.yml" ]]
then
  (cd $kheopspath && curl https://raw.githubusercontent.com/OsiriX-Foundation/kheopsDocker/install-secure/kheops/docker-compose.yml --output docker-compose.yml --silent)
fi

echo "Generate secrets"
if [[ ! -d "$secretpath" ]]
then
  mkdir $secretpath
fi

secretfiles=("kheops_auth_hmasecret" "kheops_auth_hmasecret_post" \
  "kheops_client_dicomwebproxysecret" "kheops_client_zippersecret" \
  "kheops_metric_ressource_password" "kheops_superuser_hmasecret" \
  "kheops_pacsdb_pass" "kheops_authdb_pass")

echo "Enter the Keycloak client secret:"
read KEYCLOAK_CLIENT_SECRET
printf "%s\n" $(printf "%s" $KEYCLOAK_CLIENT_SECRET | tr -dc '[:print:]') > ${secretpath}kheops_keycloak_clientsecret

docker pull frapsoft/openssl
for secretfile in ${secretfiles[*]}
do
  printf "%s\n" $(docker run -it frapsoft/openssl rand -base64 32 | tr -dc '[:print:]') > $secretpath$secretfile
done

docker rm $(docker ps -a -q)
docker rmi frapsoft/openssl

echo "What is the Keycloak host ? (ex: https://keycloak.kheops.online)"
read KEYCLOAK_HOSTNAME

echo "What is the Keycloak realm ?"
read KEYCLOAK_REALM

echo "What is your hostname ? (ex: demo.kheops.online)"
read HOST

sed -i "s|\%{keycloak_hostname}|$KEYCLOAK_HOSTNAME|g" ${kheopspath}/docker-compose.env
sed -i "s|\%{kheops_realm}|$KEYCLOAK_REALM|g" ${kheopspath}/docker-compose.env
sed -i "s|\%{kheops_host}|$HOST|g" ${kheopspath}/docker-compose.env
sed -i "s|\%{kheops_host}|$HOST|g" ${kheopspath}/.env

echo "Add your public and private key in the directory kheops/secrets (fullchain1.pem / privkey1.pem)"
read -p "Press enter to start KHEOPS"

(cd $kheopspath && docker-compose down -v && docker-compose pull)

(cd $kheopspath && docker-compose up)
