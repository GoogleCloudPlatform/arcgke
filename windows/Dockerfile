# Copyright 2024 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Windows support of ARC is documented here:
# https://github.com/actions/actions-runner-controller/blob/master/docs/configuring-windows-runners.md
# It requires building a custom image.
# This is a slightly modified version of that Dockerfile to address the following issues:
# - JITCONFIG support was added 2022-06-22, so bumping runner version to a more recent one (2.292.0 was released 2022-05-23)
# - choco wanted to restart the computer on Windows 2019, downgrading
FROM mcr.microsoft.com/windows/servercore:ltsc2019

WORKDIR /actions-runner

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';$ProgressPreference='silentlyContinue';"]

RUN Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.313.0/actions-runner-win-x64-2.313.0.zip -OutFile actions-runner-win-x64.zip

RUN if((Get-FileHash -Path actions-runner-win-x64.zip -Algorithm SHA256).Hash.ToUpper() -ne 'c4cb3e5d9f0ab42ddc224cfdf9fb705397a7b20fd321536da5500259225fdf8a'.ToUpper()){ throw 'Computed checksum did not match' }

RUN Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory('actions-runner-win-x64.zip', $PWD)

RUN Invoke-WebRequest -Uri 'https://aka.ms/install-powershell.ps1' -OutFile install-powershell.ps1; ./install-powershell.ps1 -AddToPath

# https://stackoverflow.com/questions/76470752/chocolatey-installation-in-docker-started-to-fail-restart-due-to-net-framework
ENV chocolateyVersion=1.4.0

RUN powershell Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

RUN powershell choco install git.install --params "'/GitAndUnixToolsOnPath'" -y

RUN powershell choco feature enable -n allowGlobalConfirmation

CMD [ "pwsh", "-c", "./config.cmd --name $env:RUNNER_NAME --url https://github.com/$env:RUNNER_REPO --token $env:RUNNER_TOKEN --labels $env:RUNNER_LABELS --unattended --replace --ephemeral; ./run.cmd"]
