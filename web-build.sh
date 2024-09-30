#!/bin/bash

# Compila o projeto utilizando o serviço Maven
echo "Compilando o projeto com Maven..."
docker-compose run --rm maven bash -c "mvn clean package"

# Verifica o resultado da compilação
if [ $? -eq 0 ]; then
  echo "Compilação bem-sucedida!"
else
  echo "Falha na compilação."
  exit 1
fi
