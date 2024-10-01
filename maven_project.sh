#!/bin/bash

# Carregar as variáveis do arquivo .env
#sed -i 's/\r$//' .env

ARGS="${*}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR=$(pwd -P)
##############################################################################
### FUÇÕES PARA TRATAMENTO DE PERSONALIZAÇÃO DE CORES DOS TEXTOS NO TERMINAL
##############################################################################

# Definição de cores para a saída no terminal
GREEN_COLOR='\033[0;32m'   # Cor verde para sucesso
ORANGE_COLOR='\033[0;33m'  # Cor laranja para avisos
RED_COLOR='\033[0;31m'     # Cor vermelha para erros
BLUE_COLOR='\033[0;34m'    # Cor azul para informações
NO_COLOR='\033[0m'         # Cor neutra para resetar as cores no terminal

# Função para exibir avisos com a cor laranja
function echo_warning() {
  echo "${@:3}" -e "$ORANGE_COLOR WARN: $1$NO_COLOR"
}

# Função para exibir erros com a cor vermelha
function echo_error() {
  echo "${@:3}" -e "$RED_COLOR DANG: $1$NO_COLOR"
}

# Função para exibir informações com a cor azul
function echo_info() {
  echo "${@:3}" -e "$BLUE_COLOR INFO: $1$NO_COLOR"
}

# Função para exibir mensagens de sucesso com a cor verde
function echo_success() {
  echo "${@:3}" -e "$GREEN_COLOR SUCC: $1$NO_COLOR"
}

##############################################################################
### PREPARAÇÕES E VALIDAÇÕES
##############################################################################
function is_container_running() {
  local _service_name=$1
  # Verifica se o serviço está rodando e com status 'Up'
  if docker ps --filter "name=$_service_name" --filter "status=running" | grep -q "Up"; then
    return 0
  fi
  return 1
}

echo ">>> ${BASH_SOURCE[0]} $ARGS"

command=$1
if [ ! -z "$command" ] && [ "$command" = "mvn_clean_package" ]; then
  # Compila o projeto utilizando o serviço Maven
  echo "--- Compilando o projeto com Maven..."
  cd "$PROJECT_ROOT_DIR" || exit 1
  sleep 0.5
  docker-compose down
#  docker-compose run --rm maven bash -c "mvn clean package"
  docker-compose up -d


  # Verifica o resultado da compilação
  if [ $? -eq 0 ]; then
    echo_success "Compilação bem-sucedida!
    Projeto está disponível em: \"http://localhost:8080/${ARTIFACT_ID}\""
  else
    echo_error "Falha na compilação."
    exit 1
  fi

  exit 99
fi

arg_count=$#
if [ "$arg_count" -lt 2 ]; then
  echo_error "Nenhum argumento passado."
  echo_warning "Este script esperar receber dois argumentos, sendo:
  - 1o argumento: nome do diretório onde será criado o projeto;
  - 2o argumento: nome do projeto (ARTIFACT_ID).
  Exemplo: /home/user/wordspace web-app"
  exit 1
fi

TARGET_DIR=$1
ARTIFACT_ID=$2

if [ ! -d "$TARGET_DIR" ]; then
  echo_error "O diretório $TARGET_DIR não existe."
  exit 1
fi

#LC_CTYPE garantir que apenas letras e números ASCII sejam aceitos
LC_CTYPE=C
# Verifica se o ARTIFACT_ID contém caracteres especiais (permitindo apenas letras, números e hífens)
if [[ "$ARTIFACT_ID" =~ [^a-zA-Z0-9_-] ]]; then
  echo_error "ARTIFACT_ID contém caracteres especiais não permitidos."
  exit 1
fi

PROJECT_DIR="${TARGET_DIR}/${ARTIFACT_ID}"
# Verifica e remove ocorrências de "//" no PROJECT_DIR
PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's#//*#/#g')

# Exibe os valores fornecidos
echo "PROJECT_DIR: $PROJECT_DIR"
echo "ARTIFACT_ID: $ARTIFACT_ID"

MAVEN_IMAGE=maven:3.8.8-eclipse-temurin-17
WORKDIR=/app
USER_NAME=$(id -un)
USER_UID=$(id -u)
USER_GID=$(id -g)
GROUP_ID=com.example
ARCHETYPE=maven-archetype-webapp
ARCHETYPE_VERSION=1.4

SERVICE_NAME="${ARTIFACT_ID}-tomcat-1"

# Verifica se já existe um diretório com o nome do projeto (ARTIFACT_ID)
if [ -d "$PROJECT_DIR/src" ]; then
    echo_info "O diretório $PROJECT_DIR já existe. "
    echo_info "Deseja substituir?"
    read -p "Pressione 'S' para confirmar ou [ENTER] para ignorar: " resposta
    resposta=$(echo "$resposta" | tr '[:lower:]' '[:upper:]')  # Converter para maiúsculas
    if [ "$resposta" = "S" ]; then

      if is_container_running "$SERVICE_NAME"; then
        echo_warning "Container $SERVICE_NAME está em execução!"
        echo ">>> docker stop $SERVICE_NAME"
        docker stop "$SERVICE_NAME"

        echo ">>> docker rm $SERVICE_NAME"
        docker rm "$SERVICE_NAME"
      fi
      echo ">>> sudo rm -rf $PROJECT_DIR"
      sudo rm -rf "$PROJECT_DIR"
    else
      exit 1
    fi
fi

# Verifica se o diretório de destino existe, se não, cria o diretório
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p "$PROJECT_DIR"
fi

##############################################################################
### Executa o comando Maven dentro de um contêiner Docker temporário
##############################################################################
docker run --rm \
    -v "${TARGET_DIR}:/app" \
    -w /app \
    $MAVEN_IMAGE \
    mvn -X archetype:generate \
    -DgroupId=${GROUP_ID} \
    -DartifactId=${ARTIFACT_ID} \
    -DarchetypeArtifactId=${ARCHETYPE} \
    -DarchetypeVersion=${ARCHETYPE_VERSION} \
    -DinteractiveMode=false

if [ $? -eq 0 ]; then
    sleep 1

# Criar  arquivo env sample e inserir as variáveis na ordem inversa
cat <<EOF > "${PROJECT_DIR}/.env.sample"
REVISADO=0
MAVEN_IMAGE=${MAVEN_IMAGE}
WORKDIR=${WORKDIR}
USER_NAME=$(id -un)
USER_UID=$(id -u)
USER_GID=$(id -g)

TARGET_DIR=${TARGET_DIR}
GROUP_ID=${GROUP_ID}
ARCHETYPE=${ARCHETYPE}
ARCHETYPE_VERSION=${ARCHETYPE_VERSION}
ARTIFACT_ID=${ARTIFACT_ID}

COMPOSES_FILES="
all:docker-compose.yml
"

SERVICES_COMMANDS="
all:deploy;undeploy;redeploy;status;restart;logs;up;down;
maven:mvn-clean-package
"

SERVICES_DEPENDENCIES="
tomcat:maven
"

ARG_SERVICE_PARSE="
maven-tomcat:tomcat
"

EOF

    echo ">>> chown -R ${USER_UID}:${USER_GID}  $PROJECT_DIR"
    sudo chown -R ${USER_UID}:${USER_GID}  "$PROJECT_DIR"

    sleep 0.5

#    sed -i '/<\/build>/i\
#        <plugins>\
#            <plugin>\
#                <groupId>org.apache.maven.plugins</groupId>\
#                <artifactId>maven-war-plugin</artifactId>\
#                <version>3.3.1</version>\
#            </plugin>\
#        </plugins>' "${PROJECT_DIR}/pom.xml"

    echo ">>> cp ${PROJECT_DIR}/.env.sample ${PROJECT_DIR}/.env"
    cp "${PROJECT_DIR}/.env.sample" "${PROJECT_DIR}/.env"

    echo ">>> cp -r ${SCRIPT_DIR}/conf $PROJECT_DIR"
    cp -r "${SCRIPT_DIR}/conf" "$PROJECT_DIR"

#    echo ">>> cp -r ${SCRIPT_DIR}/dependency $PROJECT_DIR"
#    cp -r "${SCRIPT_DIR}/dependency" "$PROJECT_DIR"

    echo ">>> cp -r ${SCRIPT_DIR}/secrets $PROJECT_DIR"
    cp -r "${SCRIPT_DIR}/secrets" "$PROJECT_DIR"

    echo ">>> cp ${PROJECT_DIR}/src/main/webapp/WEB-INF/web.xml ${PROJECT_DIR}/src/main/webapp/WEB-INF/web.xml"
    cp "${PROJECT_DIR}/src/main/webapp/WEB-INF/web.xml" "${PROJECT_DIR}/src/main/webapp/WEB-INF/web.xml"

    echo ">>> cp -r ${SCRIPT_DIR}/webapps $PROJECT_DIR"
    cp -r "${SCRIPT_DIR}/webapps" "$PROJECT_DIR"

    echo ">>> cp ${SCRIPT_DIR}/.dockerignore $PROJECT_DIR"
    cp "${SCRIPT_DIR}/.dockerignore" "$PROJECT_DIR/"

    echo ">>> cp ${SCRIPT_DIR}/run-catalina.sh $PROJECT_DIR"
    cp "${SCRIPT_DIR}/run-catalina.sh" "$PROJECT_DIR"

    echo ">>> chmod +x ${PROJECT_DIR}/run-catalina.sh"
    chmod +x "${PROJECT_DIR}/run-catalina.sh"

    echo ">>> cp ${SCRIPT_DIR}/web-build.sh $PROJECT_DIR"
    cp "${SCRIPT_DIR}/web-build.sh" "$PROJECT_DIR"

    echo ">>> chmod +x ${PROJECT_DIR}/web-build.sh"
    chmod +x "${PROJECT_DIR}/web-build.sh"

    echo ">>> cp ${SCRIPT_DIR}/docker-compose.yml $PROJECT_DIR"
    cp "${SCRIPT_DIR}/docker-compose.yml" "$PROJECT_DIR"

    echo ">>> cp ${SCRIPT_DIR}/Dockerfile $PROJECT_DIR"
    cp "${SCRIPT_DIR}/Dockerfile" "$PROJECT_DIR"

    echo ">>> cd $PROJECT_DIR"
    cd "$PROJECT_DIR" || exit

    echo ">>> docker-compose up --build -d"
    docker-compose up --build -d

    echo_success "Projeto Maven gerado com sucesso em $PROJECT_DIR"

    # Loop para verificar até que o contêiner esteja em execução
    while ! is_container_running "$SERVICE_NAME"; do
      echo_warning "Aguardando o serviço $SERVICE_NAME iniciar..."
      sleep 5
    done
    echo_info "Projeto está disponível em: \"http://localhost:8080/${ARTIFACT_ID}\""

else
    echo_error "Ocorreu um erro ao gerar o projeto Maven."
    exit 1
fi






