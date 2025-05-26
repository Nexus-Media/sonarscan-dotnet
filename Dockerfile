FROM mcr.microsoft.com/dotnet/sdk:9.0.300

LABEL "com.github.actions.name"="sonarscan-dotnet"
LABEL "com.github.actions.description"="SonarScanner for .NET 9 with pull request decoration support."
LABEL "com.github.actions.icon"="check-square"
LABEL "com.github.actions.color"="blue"

LABEL "org.opencontainers.image.source"="https://github.com/highbyte/sonarscan-dotnet"

LABEL "repository"="https://github.com/highbyte/sonarscan-dotnet"
LABEL "homepage"="https://github.com/highbyte"
LABEL "maintainer"="Highbyte"

# Version numbers of used software
ENV SONAR_SCANNER_DOTNET_TOOL_VERSION=10.1.2 \
    NODE_VERSION=22 \
    JRE_VERSION=17

# Fix JRE Install https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199
RUN mkdir -p /usr/share/man/man1

# Update package list and install required packages
RUN apt-get update -y \
    && apt-get install --no-install-recommends -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        openjdk-$JRE_VERSION-jre \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install NodeJS
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update -y \
    && apt-get install nodejs -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install SonarScanner .NET global tool
RUN dotnet tool install dotnet-sonarscanner --tool-path . --version $SONAR_SCANNER_DOTNET_TOOL_VERSION

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
