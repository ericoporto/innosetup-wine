FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive

ARG WINE_VERSION=winehq-stable

RUN mkdir /src && mkdir /home/xclient

# we need wine for this all to work, so we'll use the PPA
RUN set -x \
    && dpkg --add-architecture i386 \
    && apt-get update -qy \
    && apt-get install git curl gpg-agent xvfb rename -y \
    && apt-get install -y --no-install-recommends xauth procps osslsigncode  \
    && apt-get install --no-install-recommends -qfy apt-transport-https software-properties-common wget \
    && wget -nv https://dl.winehq.org/wine-builds/winehq.key \
    && apt-key add winehq.key \
    && add-apt-repository 'https://dl.winehq.org/wine-builds/ubuntu/' \
    && apt-get update -qy \
    && apt-get install --no-install-recommends -qfy $WINE_VERSION winbind cabextract \
    && apt-get clean \
    && wget -nv https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x winetricks \
    && mv winetricks /usr/local/bin

# Just get the redistributable files for VS used by AGS
RUN mkdir Redist && \
  cd Redist && \
  curl -fLOJ https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x86.exe && \
  curl -fLOJ https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe

# Run virtual X buffer on this port
ENV DISPLAY :99

RUN echo "alias winegui='wine explorer /desktop=DockerDesktop,1024x768'" > ~/.bash_aliases

COPY opt /opt
RUN chmod +x /opt/bin/iscc \
    && chmod +x /opt/bin/waitonprocess \
    && chmod +x /opt/bin/wine-x11-run
ENV PATH $PATH:/opt/bin

RUN addgroup --system xusers \
    && adduser \
    --home /home/xclient \
    --disabled-password \
    --shell /bin/bash \
    --gecos "user for running an xclient application" \
    --ingroup xusers \
    --quiet \
    xclient
    
VOLUME /src/
RUN mkdir -p /wine/drive_c/tmp \
    && ln -s /src /wine/drive_c/src \
    && chown xclient:xusers -R /home/xclient

USER xclient
WORKDIR /home/xclient

# wine settings
ENV HOME /home/xclient
ENV WINEPREFIX /home/xclient/.wine
ENV WINEARCH win32
ENV WINEDEBUG fixme-all

RUN wine reg add 'HKEY_CURRENT_USER\Software\Wine' /v ShowDotFiles /d Y \
    && while [ ! -f /home/xclient/.wine/user.reg ]; do sleep 1; done

# Install Inno Setup binaries
RUN curl -SL "https://files.jrsoftware.org/is/6/innosetup-6.2.2.exe" -o is.exe \
    && wine-x11-run wine is.exe /SP- /VERYSILENT /ALLUSERS /SUPPRESSMSGBOXES /DOWNLOADISCRYPT=1 \
    && rm is.exe

WORKDIR /wine/drive_c/src/
