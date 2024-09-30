#!/bin/bash

# Carregar as variáveis do arquivo .env
sed -i 's/\r$//' .env

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

# Carregar as variáveis do arquivo .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo_error "Arquivo .env não encontrado. Por favor, crie o arquivo com as variáveis necessárias."
    exit 1
fi

# Verifica se o diretório de destino existe, se não, cria o diretório
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
fi

SERVICE_NAME="${ARTIFACT_ID}-tomcat-1"

# Caminho completo onde o projeto será gerado
PROJECT_DIR="$TARGET_DIR/$ARTIFACT_ID"

# Verifica e remove ocorrências de "//" no PROJECT_DIR
PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's#//*#/#g')

# Verifica se já existe um diretório com o nome do projeto (ARTIFACT_ID)
if [ -d "$PROJECT_DIR" ]; then
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
##############################################################################
### Executa o comando Maven dentro de um contêiner Docker temporário
##############################################################################

#    -v "$(pwd)":/app \
#    --user $(id -u):$(id -g) \
#    -v "$TARGET_DIR/.m2:/root/.m2" \
docker run --rm \
    -v "$TARGET_DIR:/app" \
    -w /app \
    $MAVEN_IMAGE \
    mvn -X archetype:generate \
    -DgroupId=$GROUP_ID \
    -DartifactId=$ARTIFACT_ID \
    -DarchetypeArtifactId=$ARCHETYPE \
    -DarchetypeVersion=$ARCHETYPE_VERSION \
    -DinteractiveMode=false

# Verifica se o comando foi executado com sucesso
if [ $? -eq 0 ]; then
    sleep 1

    echo ">>> chown -R $(id -u):$(id -g)  $PROJECT_DIR"
    sudo chown -R $(id -u):$(id -g) "$PROJECT_DIR"

    sleep 0.5

#    sed -i '/<\/build>/i\
#        <plugins>\
#            <plugin>\
#                <groupId>org.apache.maven.plugins</groupId>\
#                <artifactId>maven-war-plugin</artifactId>\
#                <version>3.3.1</version>\
#            </plugin>\
#        </plugins>' "${PROJECT_DIR}/pom.xml"

    echo ">>> cp -r conf $PROJECT_DIR"
    cp -r conf "$PROJECT_DIR"

    echo ">>> cp -r dependency $PROJECT_DIR"
    cp -r dependency "$PROJECT_DIR"

    echo ">>> cp -r secrets $PROJECT_DIR"
    cp -r secrets "$PROJECT_DIR"

    echo ">>> cp src/main/webapp/WEB-INF/web.xml ${PROJECT_DIR}/src/main/webapp/WEB-INF/web.xml"
    cp "src/main/webapp/WEB-INF/web.xml" "${PROJECT_DIR}/src/main/webapp/WEB-INF/web.xml"

    echo ">>> cp -r webapps $PROJECT_DIR"
    cp -r webapps "$PROJECT_DIR"

    echo ">>> cp .dockerignore $PROJECT_DIR"
    cp .dockerignore "$PROJECT_DIR/"

    echo ">>> cp .env $PROJECT_DIR"
    cp .env "$PROJECT_DIR"

    echo ">>> cp run-catalina.sh $PROJECT_DIR"
    cp run-catalina.sh "$PROJECT_DIR"

    echo ">>> chmod +x ${PROJECT_DIR}/run-catalina.sh"
    chmod +x "${PROJECT_DIR}/run-catalina.sh"

    echo ">>> cp web-build.sh $PROJECT_DIR"
    cp web-build.sh "$PROJECT_DIR"

    echo ">>> chmod +x ${PROJECT_DIR}/web-build.sh"
    chmod +x "${PROJECT_DIR}/web-build.sh"

    echo ">>> cp docker-compose.yml $PROJECT_DIR"
    cp docker-compose.yml "$PROJECT_DIR"

    echo ">>> cp Dockerfile $PROJECT_DIR"
    cp Dockerfile "$PROJECT_DIR"

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






