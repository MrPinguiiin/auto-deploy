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
      echo -e "${GREEN}Installing dependencies for bun...${NC}"
      apt install -y unzip
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

# Function to setup database
setup_database() {
  echo -e "${YELLOW}Apakah ingin setup database? [y/N]${NC}"
  read -p "Pilihan: " setup_db
  
  if [[ "$setup_db" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Pilih database:${NC}"
    echo "1) PostgreSQL"
    echo "2) MySQL"
    echo "3) SQLite"
    echo "4) Redis"
    echo "5) Gunakan file docker-compose.yml sendiri"
    read -p "Pilihan [1-5]: " db_choice

    # Generate random credentials
    db_name="db_${folder_name}"
    db_user="user_$(openssl rand -hex 3)"
    db_pass="$(openssl rand -base64 12)"

    case $db_choice in
      1|2|4) # PostgreSQL/MySQL/Redis
        apt install -y docker.io docker-compose
        
        cat > docker-compose.yml <<EOL
version: '3.8'
services:
  ${db_name}:
EOL
        
        if [ $db_choice -eq 1 ]; then
          cat >> docker-compose.yml <<EOL
    image: postgres:latest
    environment:
      POSTGRES_DB: ${db_name}
      POSTGRES_USER: ${db_user}
      POSTGRES_PASSWORD: ${db_pass}
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
EOL
        elif [ $db_choice -eq 2 ]; then
          cat >> docker-compose.yml <<EOL
    image: mysql:latest
    environment:
      MYSQL_DATABASE: ${db_name}
      MYSQL_USER: ${db_user}
      MYSQL_PASSWORD: ${db_pass}
      MYSQL_ROOT_PASSWORD: ${db_pass}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
EOL
        else
          cat >> docker-compose.yml <<EOL
    image: redis:latest
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
EOL
        fi
        
        cat >> docker-compose.yml <<EOL
volumes:
  pg_data:
  mysql_data:
  redis_data:
EOL
        
        docker-compose up -d
        ;;
      
      3) # SQLite
        touch "${folder_name}.db"
        ;;
      
      5) # Custom compose file
        if [ -f "docker-compose.yml" ]; then
          docker-compose up -d
        else
          echo -e "${RED}File docker-compose.yml tidak ditemukan!${NC}"
        fi
        ;;
    esac
    
    # Auto setup .env dengan validasi dan backup
    echo -e "${YELLOW}Mengupdate file .env...${NC}"
    
    # Validasi .env.example
    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
      if grep -q "DATABASE_URL" .env.example; then
        echo -e "${GREEN}File .env.example valid, melakukan copy...${NC}"
        cp .env.example .env
      else
        echo -e "${RED}Warning: .env.example tidak mengandung DATABASE_URL!${NC}"
        read -p "Lanjutkan tanpa copy .env.example? [y/N] " continue_choice
        if [[ "$continue_choice" =~ ^[Yy]$ ]]; then
          touch .env
        else
          return 1
        fi
      fi
    fi
    
    if [ -f ".env" ]; then
      # Backup .env lama
      backup_time=$(date +"%Y%m%d_%H%M%S")
      cp .env ".env.backup_$backup_time"
      echo -e "${YELLOW}Backup .env dibuat: .env.backup_$backup_time${NC}"
      
      # Konfirmasi sebelum update
      echo -e "${YELLOW}File .env akan diupdate dengan konfigurasi database baru.${NC}"
      read -p "Lanjutkan? [Y/n] " confirm
      if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Update .env dibatalkan${NC}"
        return 0
      fi
      
      # Hapus konfigurasi database lama
      sed -i '/^POSTGRES_/d;/^MYSQL_/d;/^DATABASE_URL/d;/^REDIS_/d' .env
      
      # Tambahkan konfigurasi baru
      case $db_choice in
        1) # PostgreSQL
          echo "DATABASE_URL=postgresql://${db_user}:${db_pass}@localhost:5432/${db_name}?schema=public" >> .env
          ;;
        2) # MySQL
          echo "DATABASE_URL=mysql://${db_user}:${db_pass}@localhost:3306/${db_name}" >> .env
          ;;
        3) # SQLite
          echo "DATABASE_URL=file:./${folder_name}.db" >> .env
          ;;
        4) # Redis
          echo "REDIS_HOST=localhost" >> .env
          echo "REDIS_PORT=6379" >> .env
          ;;
      esac
      
      echo -e "${GREEN}File .env berhasil diupdate!${NC}"
    else
      echo -e "${RED}Error: File .env tidak ditemukan!${NC}"
    fi

    # Show credentials
    echo -e "${GREEN}Database setup selesai!${NC}"
    echo -e "${YELLOW}Detail koneksi:${NC}"
    case $db_choice in
      1) # PostgreSQL
        echo "Type: PostgreSQL"
        echo "Host: localhost"
        echo "Port: 5432"
        echo "Database: ${db_name}"
        echo "Username: ${db_user}"
        echo "Password: ${db_pass}"
        ;;
      2) # MySQL
        echo "Type: MySQL"
        echo "Host: localhost"
        echo "Port: 3306"
        echo "Database: ${db_name}"
        echo "Username: ${db_user}"
        echo "Password: ${db_pass}"
        ;;
      3) # SQLite
        echo "Type: SQLite"
        echo "File: $(pwd)/${folder_name}.db"
        ;;
      4) # Redis
        echo "Type: Redis"
        echo "Host: localhost"
        echo "Port: 6379"
        ;;
    esac
    
    echo -e "${YELLOW}Simpan informasi ini di .env project Anda!${NC}"
  fi
}

# Main script
echo -e "${YELLOW}Starting SvelteKit auto-deploy setup...${NC}"

# Inisialisasi status tahapan
declare -A completed_steps

# Fungsi untuk mengecek dan menandai tahapan
check_step() {
  local step_name=$1
  local step_desc=$2
  
  if [[ -z "${completed_steps[$step_name]}" ]]; then
    echo -e "${YELLOW}${step_desc}...${NC}"
    return 0
  else
    echo -e "${GREEN}[SKIPPED] ${step_desc} (sudah dilakukan sebelumnya)${NC}"
    return 1
  fi
}

# Fungsi untuk menandai tahapan selesai
mark_completed() {
  local step_name=$1
  completed_steps[$step_name]=1
}

# Step 1: Update and install git
if check_step "step1" "Updating packages and installing git"; then
  apt update
  apt install -y git
  mark_completed "step1"
fi

# Step 2: Choose JS runtime
if check_step "step2" "Choosing JavaScript runtime"; then
  echo -e "${YELLOW}Choose your JavaScript runtime:${NC}"
  echo "1) npm (default)"
  echo "2) pnpm"
  echo "3) bun"
  echo "4) deno"
  read -p "Enter choice [1-4]: " runtime_choice

  install_runtime $runtime_choice
  mark_completed "step2"
fi

# Step 3: Install Nginx
if check_step "step3" "Installing Nginx"; then
  apt install -y nginx
  mark_completed "step3"
fi

# Step 4: Git clone
if check_step "step4" "Cloning repository"; then
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
  mark_completed "step4"
fi

# Step 5: Install dependencies
if check_step "step5" "Installing dependencies"; then
  case $runtime_choice in
    1) npm install ;;
    2) pnpm install ;;
    3) bun install ;;
    4) deno cache deps.ts ;;
  esac
  mark_completed "step5"
fi

# Step 6: Build project
build_project() {
  echo -e "${YELLOW}Starting build process...${NC}"
  
  # Perintah build sesuai runtime
  case $runtime_choice in
    1) build_cmd="npm run build" ;;
    2) build_cmd="pnpm run build" ;;
    3) build_cmd="bun --bun run build" ;;
    4) build_cmd="deno run -A npm:prisma generate && deno run -A npm:prisma db push" ;;
  esac
  
  spinner "$build_cmd" "Building with ${build_cmd%% *}"
  
  # Pengecekan hasil build
  if [ -d "build" ] || [ -d ".svelte-kit" ] || [ -d "dist" ]; then
    echo -e "${GREEN}Build berhasil!${NC}"
    echo -e "${YELLOW}Hasil build ditemukan di:"
    [ -d "build" ] && echo "- build/"
    [ -d ".svelte-kit" ] && echo "- .svelte-kit/"
    [ -d "dist" ] && echo "- dist/"
    echo -e "${NC}"
  else
    echo -e "${RED}Warning: Tidak ditemukan folder hasil build!${NC}"
    echo -e "${YELLOW}Periksa:${NC}"
    echo "1. Apakah project sudah dikonfigurasi dengan benar"
    echo "2. Ada error selama proses build"
  fi
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
