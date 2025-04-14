# Auto-Deploy SvelteKit ke Nginx VPS

Script otomatis untuk deploy aplikasi SvelteKit ke server Nginx dengan konfigurasi lengkap.

## Fitur
- Install dependensi otomatis (Git, Node.js, Nginx)
- Pilihan runtime (npm, pnpm, bun, deno)
- Konfigurasi Nginx + SSL dengan Certbot
- Pilihan process manager (PM2/Supervisor)
- Support private repository dengan SSH key

## Cara Penggunaan

1. Jalankan script di server Anda:
```bash
wget -qO deploy.sh https://raw.githubusercontent.com/MrPinguiiin/auto-deploy/main/deploy.sh && bash deploy.sh
```

2. Ikuti instruksi yang muncul:
   - Pilih runtime JavaScript
   - Masukkan URL repository Git
   - Masukkan nama folder project
   - Masukkan domain Anda (untuk konfigurasi Nginx)
   - Pilih process manager

3. Script akan otomatis:
   - Clone repository
   - Install dependencies
   - Build project
   - Konfigurasi Nginx + SSL
   - Setup process manager

## Requirements
- Ubuntu/Debian based system
- Akses root/sudo

## Catatan
- Untuk private repo, pastikan sudah menambahkan SSH key ke GitHub
- Pastikan domain sudah mengarah ke IP server Anda sebelum setup SSL
