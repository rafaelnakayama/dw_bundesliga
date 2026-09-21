FROM python:3.13.13

WORKDIR /app

# Sem isso todo print some do 'docker compose logs' ate o processo terminar,
# porque o Python bufferiza stdout quando ele nao e um terminal.
ENV PYTHONUNBUFFERED=1

# Driver ODBC da Microsoft, antes do 'uv sync' porque o pyodbc se liga ao
# unixODBC tanto na instalacao quanto em execucao. Duas armadilhas:
#   1. A chave e a microsoft-2025.asc, nao a microsoft.asc dos tutoriais. O
#      repositorio trixie usa outra chave e o sqv do Debian 13 rejeita a antiga
#      com "E: The repository is not signed".
#   2. O 'debian/13' na URL acompanha a base do FROM e muda junto com ela.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
 && curl -sSL https://packages.microsoft.com/keys/microsoft-2025.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
 && curl -sSL https://packages.microsoft.com/config/debian/13/prod.list \
      -o /etc/apt/sources.list.d/mssql-release.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev \
 && rm -rf /var/lib/apt/lists/*

# Versao fixa pelo mesmo motivo do uv.lock: o build de amanha resolve igual.
COPY --from=ghcr.io/astral-sh/uv:0.11.26 /uv /usr/local/bin/uv

# O ambiente fica em /app/.venv, e os volumes do compose montam subpastas de
# /app, nunca /app, entao ele sobrevive. O PATH da o 'python' do CMD.
ENV PATH="/app/.venv/bin:$PATH"

# Manifestos sozinhos primeiro: enquanto eles nao mudarem, o 'uv sync' sai do
# cache mesmo que o codigo mude. --locked falha se o lock estiver
# desatualizado, em vez de instalar algo diferente do que roda no host. Sem
# --group, o jupyter do dashboard fica de fora.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked

# Preserva a pasta em vez de achatar: o script cai em
# /app/ingestion/fetch_matches.py, entao o Path(__file__).parent.parent dele
# resolve para /app e o data_path para /app/datasets, espelhando o host.
COPY ingestion/ ./ingestion/

# o deploy_schema() aplica estes .sql na subida, entao eles sao runtime
COPY scripts/ ./scripts/

CMD ["python", "ingestion/fetch_matches.py"]
