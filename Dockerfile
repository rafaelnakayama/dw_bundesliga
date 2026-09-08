FROM python:3.13.13

WORKDIR /app

# Sem isso o Python bufferiza stdout quando ele nao e um terminal, e todo
# print some do 'docker compose logs' ate o processo terminar.
ENV PYTHONUNBUFFERED=1

# Driver ODBC da Microsoft. Vem antes do pip install porque o pyodbc se liga
# ao unixODBC tanto na instalacao quanto em execucao.
#
# Duas armadilhas registradas aqui:
#   1. A chave e a microsoft-2025.asc, nao a microsoft.asc que a maioria dos
#      tutoriais manda usar. O repositorio trixie e assinado por outra chave,
#      e o verificador novo do Debian 13 (sqv) rejeita a antiga com
#      "E: The repository is not signed".
#   2. O 'debian/13' na URL acompanha a imagem base do FROM. Se um dia trocar
#      a base por uma baseada em Debian 14, esta linha tem que mudar junto.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
 && curl -sSL https://packages.microsoft.com/keys/microsoft-2025.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
 && curl -sSL https://packages.microsoft.com/config/debian/13/prod.list \
      -o /etc/apt/sources.list.d/mssql-release.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev \
 && rm -rf /var/lib/apt/lists/*

# requirements.txt sozinho primeiro: enquanto ele nao mudar, o pip install
# sai do cache mesmo que o codigo mude. Invertendo a ordem, toda edicao no
# script reinstalaria tudo.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Preserva a pasta em vez de achatar. O script cai em
# /app/ingestion/fetch_matches.py, entao o Path(__file__).parent.parent dele
# resolve para /app, e o data_path para /app/datasets, espelhando o host.
COPY ingestion/ ./ingestion/

# o deploy_schema() aplica estes .sql na subida, entao eles sao runtime
COPY scripts/ ./scripts/

CMD ["python", "ingestion/fetch_matches.py"]