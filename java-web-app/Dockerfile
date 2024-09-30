ARG MAVEN_IMAGE=maven:3.8.8-eclipse-temurin-17
FROM ${MAVEN_IMAGE} as marven-build

ARG WORKDIR
ARG USER_UID
ARG USER_GID
ARG USER_NAME

ENV WORKDIR=${WORKDIR}
ENV USER_UID=${USER_UID}
ENV USER_GID=${USER_GID}
ENV USER_NAME=${USER_NAME}

USER root

# Instala as dependências necessárias
RUN apt-get update && apt-get install -y --fix-missing sudo \
    && apt-get -y autoremove && apt-get clean \
    && rm -rf /var/cache/apt/* && rm -rf /var/lib/apt/lists/*

# Cria o grupo e o usuário com base nos USER_UID e USER_GID fornecidos
RUN groupadd -g "${USER_GID}" $USER_NAME && \
    useradd -u "${USER_UID}" -g "${USER_GID}" -m --no-log-init -s /bin/bash $USER_NAME

# Adicionar o diretório /home/USER_NAME/.local/bin ao PATH
ENV PATH="$PATH:/home/${USER_NAME}/.local/bin"

# Adicionando usuário ao grupo root
RUN usermod -G root $USER_NAME

# [Opcional] Adiciona suporte para Sudo.
RUN echo $USER_NAME ALL=\(ALL\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME && \
    chmod 0440 /etc/sudoers.d/$USER_NAME && \
    echo "$USER_NAME:mudar@123" | chpasswd

# Se o $USER_NAME == "customuser", gera uma nova chave ssh.
RUN if [ "$USER_NAME" = "customuser" ]; then \
        ssh-keygen -t ed25519 -C "Usuário $USER_NAME" -f /home/$USER_NAME/.ssh/id_ed25519_$USER_NAME -N ""; \
    fi

# Diretório de trabalho no contêiner
WORKDIR $WORKDIR

# Copiando o arquivo de configuração do Maven para o contêiner
COPY pom.xml .

# Copiando o código-fonte para o contêiner
COPY src ${WORKDIR}/src

# Baixando dependências do Maven
RUN mvn dependency:resolve

#USER $USER_NAME

# Compilando o projeto e gerando o arquivo .war para o Tomcat
RUN mvn clean package

RUN chown -R ${USER_NAME}:${USER_NAME} ${WORKDIR}/target

# Ponto de entrada para rodar o Maven no contêiner
CMD ["mvn", "clean", "install"]
