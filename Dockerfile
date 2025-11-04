FROM elixir:1.16-alpine

RUN apk add --no-cache build-base

WORKDIR /app

# Copier les fichiers Mix
COPY mix.exs mix.lock ./

# Installer et compiler les dépendances
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix deps.compile

# Copier le code source
COPY lib/ lib/
COPY priv/ priv/

# Compiler l'application
RUN mix compile

# Commande de démarrage - IMPORTANT: appeler explicitement votre fonction
CMD ["sh", "-c", "echo '🚀 Démarrage de HL7 POC...' && mix run --no-halt -e 'Hl7Poc.run()'"]
