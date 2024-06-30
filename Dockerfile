FROM mcr.microsoft.com/dotnet/sdk:9.0-preview

LABEL "com.github.actions.name"="sonarscan-dotnet"
LABEL "com.github.actions.description"="Sonarscanner for .NET 9 with pull request decoration support."
LABEL "com.github.actions.icon"="check-square"
LABEL "com.github.actions.color"="blue"

LABEL "org.opencontainers.image.source"="https://github.com/highbyte/sonarscan-dotnet"

LABEL "repository"="https://github.com/highbyte/sonarscan-dotnet"
LABEL "homepage"="https://github.com/highbyte"
LABEL "maintainer"="Highbyte"

# Version numbers of used software
ENV SONAR_SCANNER_DOTNET_TOOL_VERSION=6.2 \
    NODE_VERSION=20 \
    JRE_VERSION=17

# Add Microsoft Debian apt-get feed 
RUN wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb

# Fix JRE Install https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199
RUN mkdir -p /usr/share/man/man1

# Install NodeJS
RUN apt-get update -y \
    && apt-get install -y ca-certificates curl gnupg apt-transport-https \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update -y \
    && apt-get install -y nodejs openjdk-$JRE_VERSION-jre

# Install SonarScanner .NET global tool
RUN dotnet tool install dotnet-sonarscanner --tool-path . --version $SONAR_SCANNER_DOTNET_TOOL_VERSION

# Cleanup
RUN apt-get -q -y autoremove \
    && apt-get -q clean -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
