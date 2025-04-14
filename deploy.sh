#!/bin/bash

# Auto-deploy script for SvelteKit to Nginx VPS by MrPinguiiin

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to install runtime
install_runtime() {
  case $1 in
    1) # npm
      echo -e "${GREEN}Installing npm...${NC}"
      apt install -y nodejs npm
      ;;
    2) # pnpm
      echo -e "${GREEN}Installing pnpm...${NC}"
      npm install -g pnpm
      ;;
    3) # bun
      echo -e "${GREEN}Installing bun...${NC}"
      curl -fsSL https://bun.sh/install | bash
      ;;
    4) # deno
      echo -e "${GREEN}Installing deno...${NC}"
      curl -fsSL https://deno.land/install.sh | sh
      ;;
  esac
}

spinner() {
  local cmd="$1"
  local msg="$2"
  local i=1
  local sp='/-\|'
  eval "$cmd" &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    echo -ne "\r${YELLOW}${msg} ${sp:i++%4:1}${NC}"
    sleep 0.1
  done
  wait $pid
}

# Function to setup process manager
setup_process_manager() {
  echo -e "${YELLOW}Pilih process manager:${NC}"
  echo "1) PM2 (recommended)"
  echo "2) Supervisor"
  read -p "Pilihan [1-2]: " pm_choice

  case $pm_choice in
    1) # PM2
      npm install -g pm2
      pm2 start /var/www/$folder_name/build/index.js
      pm2 save
      pm2 startup
      ;;
    2) # Supervisor
      apt install -y supervisor
      cat > /etc/supervisor/conf.d/$folder_name.conf <<EOL
[program:$folder_name]
command=/var/www/$folder_name/build/index.js
directory=/var/www/$folder_name
autostart=true
autorestart=true
user=root
EOL
      supervisorctl reread
      supervisorctl update
      supervisorctl restart $folder_name
      ;;
  esac
}

# Main script
echo -e "${YELLOW}Starting SvelteKit auto-deploy setup...${NC}"

# Step 1: Update and install git
echo -e "${YELLOW}Updating packages and installing git...${NC}"
apt update
apt install -y git

# Step 2: Choose JS runtime
echo -e "${YELLOW}Choose your JavaScript runtime:${NC}"
echo "1) npm (default)"
echo "2) pnpm"
echo "3) bun"
echo "4) deno"
read -p "Enter choice [1-4]: " runtime_choice

install_runtime $runtime_choice

# Step 3: Install Nginx
echo -e "${YELLOW}Installing Nginx...${NC}"
apt install -y nginx

# Step 4: Git clone
cd /var/www

echo -e "${YELLOW}Is your repository private? [y/N]${NC}"
read -p "Your choice: " is_private

if [[ "$is_private" =~ ^[Yy]$ ]]; then
  echo -e "${RED}WARNING: Private repository detected.${NC}"
  echo -e "${YELLOW}Generating SSH key...${NC}"
  ssh-keygen -t ed25519 -C "deploy-key" -f ~/.ssh/deploy_key -N ""
  
  echo -e "${YELLOW}Please add this public key to your GitHub deploy keys:${NC}"
  cat ~/.ssh/deploy_key.pub
  echo -e "\n${YELLOW}Press Enter to continue after adding the key...${NC}"
  read
  
  echo -e "${YELLOW}Cloning private repository...${NC}"
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/deploy_key
else
  echo -e "${GREEN}Cloning public repository...${NC}"
fi

read -p "Enter Git repository URL: " repo_url
read -p "Enter project folder name: " folder_name

git clone $repo_url $folder_name
cd $folder_name

# Step 5: Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
case $runtime_choice in
  1) npm install ;;
  2) pnpm install ;;
  3) bun install ;;
  4) deno cache deps.ts ;;
esac

# Step 6: Build with loading
build_project() {
  echo -e "${YELLOW}Starting build process...${NC}"
  case $runtime_choice in
    1) spinner "npm run build" "Building with npm" ;;
    2) spinner "pnpm run build" "Building with pnpm" ;;
    3) spinner "bun run build" "Building with bun" ;;
    4) spinner "deno run -A npm:prisma db push && deno run -A npm:prisma generate" "Building with deno" ;;
  esac
  echo -e "${GREEN}Build completed successfully!${NC}"
}

# Step 7: Setup Nginx reverse proxy
setup_nginx() {
  echo -e "${YELLOW}Configuring Nginx reverse proxy...${NC}"
  read -p "Enter your domain name (e.g. example.com): " domain_name

  cat > /etc/nginx/sites-available/$folder_name <<EOL
server {
    server_name $domain_name www.$domain_name;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

server {
    if (\$host = $domain_name) {
        return 301 https://\$host\$request_uri;
    }

    listen 80;
    server_name $domain_name www.$domain_name;
    return 404;
}
EOL

  ln -s /etc/nginx/sites-available/$folder_name /etc/nginx/sites-enabled/
  systemctl restart nginx

  echo -e "${GREEN}Nginx configured for domain: $domain_name${NC}"
}

# Step 8: Install Certbot for SSL
install_ssl() {
  echo -e "${YELLOW}Installing Certbot for SSL...${NC}"
  apt install -y certbot python3-certbot-nginx
  certbot --nginx -d $domain_name -d www.$domain_name
  systemctl restart nginx
  echo -e "${GREEN}SSL certificate installed successfully!${NC}"
}

# Execute steps
build_project
setup_nginx
install_ssl
echo -e "${YELLOW}Setup process manager...${NC}"
setup_process_manager

echo -e "${GREEN}Deployment completed!${NC}"
echo -e "${YELLOW}Your app is now available at: http://your-server-ip${NC}"
