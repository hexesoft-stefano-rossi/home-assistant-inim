# Usiamo Debian Slim: ha le librerie giuste per i file di Visual Studio
FROM debian:bookworm-slim

# Installiamo i componenti minimi richiesti da .NET
RUN apt-get update && apt-get install -y \
    libicu-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia i tuoi file
COPY Hexesoft-BTicino .

# Diamo i permessi di esecuzione direttamente al programma
RUN chmod +x /app/Hexesoft-BTicino

# Avviamo il programma nativamente 
CMD [ "/app/Hexesoft-BTicino" ]
