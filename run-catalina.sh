#!/bin/bash -x

#cp -r "${WORKDIR}/secrets" "/usr/local/tomcat/secrets"

if [ ! -f "${MANAGER_PASSWORD_FILE}" ]; then
    echo "The password file (MANAGER_PASSWORD_FILE) is missing: ${MANAGER_PASSWORD_FILE}" && exit 1
fi

if [ ! -f "${DB_PASSWORD_FILE}" ]; then
    echo "The password file (DB_PASSWORD_FILE) is missing: ${DB_PASSWORD_FILE}" && exit 1
fi

# Generate properties to be added to conf/catalina.properties

tee -a conf/catalina.properties >/dev/null <<EOD
# auto-generated from ${0} at $(date)
manager.password=$(cat ${MANAGER_PASSWORD_FILE})
db.resource-name=${DB_RESOURCE_NAME}
db.url=${DB_URL}
db.username=${DB_USERNAME}
db.password=$(cat ${DB_PASSWORD_FILE})
db.driver-class-name=${DB_DRIVER_CLASS_NAME}
EOD

# Espera até que o arquivo WAR esteja disponível
while [ ! -f "${WORKDIR}/target/${ARTIFACT_ID}.war" ]; do
  echo "Aguardando o arquivo ${ARTIFACT_ID}.war ser gerado..."
  sleep 2
done

cp "${WORKDIR}/target/${ARTIFACT_ID}.war" "/usr/local/tomcat/webapps/${ARTIFACT_ID}.war"

cp -r /usr/local/tomcat/webapps.dist/* /usr/local/tomcat/webapps/

#cp -r ${WORKDIR}/conf/* "/usr/local/tomcat/conf"
#cp "${WORKDIR}/webapps/manager/" "/usr/local/tomcat/webapps/manager/META-INF/context.xml"

sleep 2
# Run
exec catalina.sh run