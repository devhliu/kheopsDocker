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
  (cd $kheopspath && curl https://raw.githubusercontent.com/OsiriX-Foundation/kheopsDocker/install-secure/kheops/.env --output .env --silent)
  (cd $kheopspath && curl https://raw.githubusercontent.com/OsiriX-Foundation/kheopsDocker/install-secure/kheops/docker-compose.env --output docker-compose.env --silent)
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
echo $KEYCLOAK_CLIENT_SECRET > ${secretpath}kheops_keycloak_clientsecret

docker pull frapsoft/openssl
for secretfile in ${secretfiles[*]}
do
  secret=$(docker run -it frapsoft/openssl rand -base64 32)
  echo $secret > ${secretpath}tmp_${secretfile}
  sed -e "s/\r//g" ${secretpath}tmp_${secretfile} > $secretpath$secretfile
  rm ${secretpath}tmp_${secretfile}
done

docker rm $(docker ps -a -q)
docker rmi frapsoft/openssl

echo "What is the Keycloak realm ?"
read KEYCLOAK_REALM

echo "What is your host ?"
read HOST

sed -i "s|\%{kheops_realm}|$KEYCLOAK_REALM|g" ${kheopspath}/docker-compose.env
sed -i "s|\%{kheops_host}|$HOST|g" ${kheopspath}/docker-compose.env
sed -i "s|\%{kheops_host}|$HOST|g" ${kheopspath}/.env

echo "Add your public and private key in the directory kheops/secrets (fullchain1.pem / privkey1.pem)"
read -p "Press enter to start KHEOPS"

(cd $kheopspath && docker-compose down -v && docker-compose pull)

(cd $kheopspath && docker-compose up)
