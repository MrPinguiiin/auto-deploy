# Auto-Deploy SvelteKit ke Nginx VPS

Script otomatis untuk deploy aplikasi SvelteKit ke server Nginx dengan konfigurasi lengkap.

## Fitur Utama
- **Dependensi Otomatis**:
  - Install Git, Node.js, Nginx
  - Pilihan runtime (npm, pnpm, bun, deno)
  - Docker & docker-compose (jika diperlukan)

- **Deployment**:
  - Clone repository (support private/public)
  - Auto-generate SSH key untuk private repo
  - Build project dengan loading indicator

- **Database Setup**:
  - Pilihan database (PostgreSQL/MySQL/SQLite/Redis)
  - Auto-generate docker-compose.yml
  - Random secure credentials
  - Backup dan validasi .env

- **Server Config**:
  - Reverse Proxy Nginx
  - SSL Otomatis dengan Certbot
  - Pilihan process manager (PM2/Supervisor)

## Cara Penggunaan
```bash
wget -qO deploy.sh https://raw.githubusercontent.com/MrPinguiiin/auto-deploy/main/deploy.sh && bash deploy.sh
```

### Flow Deployment:
1. Pilih runtime JavaScript
2. Masukkan Git repository URL
3. Setup database (opsional)
4. Konfigurasi domain & SSL
5. Pilih process manager

## Contoh Penggunaan Database
```bash
# Saat diminta pilihan database:
1) PostgreSQL - Auto setup dengan Docker
2) MySQL - Auto setup dengan Docker
3) SQLite - File database lokal
4) Redis - Cache server
5) Gunakan docker-compose.yml sendiri
```

## Requirements
- Ubuntu/Debian based system
- Akses root/sudo
- Docker (untuk database tertentu)

## Catatan Penting
- Untuk private repo: Tambahkan SSH key ke GitHub
- Domain harus mengarah ke server sebelum setup SSL
- Backup otomatis (.env.backup_<timestamp>) dibuat sebelum perubahan
- Cancel update .env tidak akan menghentikan proses deploy
